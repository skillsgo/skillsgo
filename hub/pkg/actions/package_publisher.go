/*
 * [INPUT]: Depends on request-scoped structured logging, an explicitly leased Repository Backfill session, source-language analysis, the ordered immutable publication commit boundary, and an optional best-effort current-publication observer.
 * [OUTPUT]: Materializes single or chunked historical Package content transitions with precise stage failures, computes version-independent Package content sums plus source digests and languages once, prepares byte-stable Package Version Info plus content-addressed Skill objects, and notifies metadata enrichment after current visibility commits.
 * [POS]: Serves as the observable cold-publication and bounded Backfill-session coordinator between Git Repository discovery, artifact storage, and Package Info visibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/translation"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	"golang.org/x/sync/singleflight"
)

var errEquivalentPackageContent = fmt.Errorf("Package Version has equivalent published content")

type repositoryMaterializer interface {
	Materialize(ctx context.Context, packagePath, query string) (string, error)
}

type historicalRepositoryMaterializer interface {
	MaterializeHistoricalBatch(ctx context.Context, source skill.RepositoryBackfillSession, queries []string) map[string]error
}

type modulePublisher struct {
	fetcher                 skill.RepositoryFetcher
	publication             *modulePublicationCommit
	afterCurrentPublication func(context.Context, string)
	work                    singleflight.Group
	commit                  singleflight.Group
	upstream                chan struct{}
	mu                      sync.Mutex
	negative                map[string]negativePublication
	now                     func() time.Time
	negativeTTL             time.Duration
	languageAnalyzer        *translation.LanguageAnalyzer
}

type negativePublication struct {
	expires time.Time
	err     error
}

type packagePublisherOption func(*modulePublisher)

func withRepositoryMaterializerCapacity(capacity int) packagePublisherOption {
	return func(publisher *modulePublisher) {
		publisher.upstream = make(chan struct{}, capacity)
	}
}

func withCurrentPublicationObserver(observer func(context.Context, string)) packagePublisherOption {
	return func(publisher *modulePublisher) {
		publisher.afterCurrentPublication = observer
	}
}

func withArtifactRepositoryRoot(root string) packagePublisherOption {
	return func(publisher *modulePublisher) {
		publisher.publication.root = root
	}
}

func newPackagePublisher(fetcher skill.RepositoryFetcher, backend storage.Backend, metadata *catalog.Catalog, options ...packagePublisherOption) *modulePublisher {
	artifactRoot := filepath.Join(os.TempDir(), "skillsgo-git-artifacts")
	publisher := &modulePublisher{fetcher: fetcher, publication: newPackagePublicationCommit(backend, metadata, artifactRoot), upstream: make(chan struct{}, 8), negative: make(map[string]negativePublication), now: time.Now, negativeTTL: 10 * time.Second, languageAnalyzer: translation.NewLanguageAnalyzer()}
	for _, option := range options {
		option(publisher)
	}
	return publisher
}

func (p *modulePublisher) Materialize(ctx context.Context, packagePath, query string) (string, error) {
	return p.materializePublication(ctx, packagePath, query, catalog.CurrentPublication)
}

const historicalPublicationChunkSize = 5

// MaterializeHistoricalBatch owns one source lease and one Artifact hydration
// while preserving a separate result and Catalog transaction for each query.
func (p *modulePublisher) MaterializeHistoricalBatch(ctx context.Context, source skill.RepositoryBackfillSession, queries []string) map[string]error {
	results := make(map[string]error, len(queries))
	if len(queries) == 0 {
		return results
	}
	packagePath := source.PackagePath()
	workCtx, cancel := context.WithTimeout(ctx, packageBackfillTimeout)
	defer cancel()
	select {
	case p.upstream <- struct{}{}:
		defer func() { <-p.upstream }()
	default:
		err := withPublicationFailure(publicationFailureCapacity, huberrors.E("modulePublisher.MaterializeHistoricalBatch", "upstream Repository resolution is at capacity", huberrors.KindRateLimit))
		for _, query := range queries {
			results[query] = err
		}
		return results
	}
	err := p.publication.WithSession(workCtx, packagePath, func(session *modulePublicationSession) error {
		staged := 0
		flush := func() {
			for _, outcome := range session.Flush() {
				if outcome.err == nil && outcome.equivalent {
					results[outcome.key] = errEquivalentPackageContent
				} else {
					results[outcome.key] = outcome.err
				}
			}
			staged = 0
		}
		visitErr := source.VisitSnapshots(workCtx, queries, func(query string, snapshot *skill.RepositorySnapshot, discoveryErr error) error {
			if discoveryErr != nil {
				results[query] = discoveryErr
				return nil
			}
			input, prepareErr := p.prepareSnapshot(packagePath, query, snapshot, catalog.HistoricalPublication)
			if prepareErr != nil {
				results[query] = prepareErr
				return nil
			}
			input.key = query
			if stageErr := session.Stage(input); stageErr != nil {
				results[query] = stageErr
				return nil
			}
			staged++
			if staged == historicalPublicationChunkSize {
				flush()
			}
			return nil
		})
		flush()
		return visitErr
	})
	if err != nil {
		for _, query := range queries {
			if _, recorded := results[query]; !recorded {
				results[query] = err
			}
		}
	}
	return results
}

func (p *modulePublisher) VerifyHistorical(ctx context.Context, packagePath, query, expectedCommitSHA string) error {
	snapshot, err := p.fetcher.DiscoverRepository(ctx, packagePath, query)
	if err != nil {
		return err
	}
	defer closeRepositorySnapshot(snapshot)
	if snapshot.PackagePath != packagePath || snapshot.Version != query || snapshot.CommitSHA == "" {
		return fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", packagePath, query)
	}
	if snapshot.CommitSHA != expectedCommitSHA {
		return fmt.Errorf("immutable Package Version conflict for %s@%s", packagePath, query)
	}
	return nil
}

func (p *modulePublisher) materializePublication(ctx context.Context, packagePath, query string, visibility catalog.PublicationVisibility) (string, error) {
	started := time.Now()
	key := "publish:" + string(visibility) + ":" + packagePath + "@" + query
	entry := log.EntryFromContext(ctx).WithFields(map[string]any{
		"component":     "package_publisher",
		"package_path":  packagePath,
		"requested_ref": query,
	})
	entry.Debugf("repository publication requested")
	p.mu.Lock()
	negative, cached := p.negative[key]
	if cached && p.now().Before(negative.expires) {
		p.mu.Unlock()
		entry.WithFields(map[string]any{
			"cache":       "negative",
			"duration_ms": time.Since(started).Milliseconds(),
		}).Debugf("repository publication cache hit")
		return "", negative.err
	}
	if cached {
		delete(p.negative, key)
	}
	p.mu.Unlock()
	result := p.work.DoChan(key, func() (any, error) {
		entry.Debugf("repository publication started")
		workCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Minute)
		defer cancel()
		select {
		case p.upstream <- struct{}{}:
			defer func() { <-p.upstream }()
		default:
			entry.Warnf("repository publication upstream capacity exhausted")
			return "", huberrors.E("modulePublisher.Materialize", "upstream Repository resolution is at capacity", huberrors.KindRateLimit)
		}
		version, materializeErr := p.materialize(workCtx, packagePath, query, visibility)
		if materializeErr != nil && huberrors.IsNotFoundErr(materializeErr) {
			p.mu.Lock()
			p.negative[key] = negativePublication{expires: p.now().Add(p.negativeTTL), err: materializeErr}
			p.mu.Unlock()
		}
		return version, materializeErr
	})
	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case resolved := <-result:
		if resolved.Err != nil {
			failed := entry.WithFields(map[string]any{
				"duration_ms":         time.Since(started).Milliseconds(),
				"singleflight_shared": resolved.Shared,
			})
			switch {
			case huberrors.IsNotFoundErr(resolved.Err):
				failed.Infof("repository publication not found")
			case huberrors.Kind(resolved.Err) == huberrors.KindRateLimit:
				failed.Warnf("repository publication rate limited")
			default:
				failed.SystemErr(resolved.Err)
			}
			return "", resolved.Err
		}
		version := resolved.Val.(string)
		entry.WithFields(map[string]any{
			"duration_ms":         time.Since(started).Milliseconds(),
			"singleflight_shared": resolved.Shared,
			"version":             version,
		}).Infof("repository publication completed")
		return version, nil
	}
}

func (p *modulePublisher) materialize(ctx context.Context, packagePath, query string, visibility catalog.PublicationVisibility) (string, error) {
	started := time.Now()
	snapshot, err := p.fetcher.DiscoverRepository(ctx, packagePath, query)
	if err != nil {
		return "", err
	}
	if snapshot.PackagePath != packagePath || snapshot.Version == "" || snapshot.CommitSHA == "" || len(snapshot.Members) == 0 {
		closeRepositorySnapshot(snapshot)
		return "", fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", packagePath, query)
	}
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"commit_sha":   snapshot.CommitSHA,
		"duration_ms":  time.Since(started).Milliseconds(),
		"member_count": len(snapshot.Members),
		"package_path": packagePath,
		"version":      snapshot.Version,
	}).Debugf("repository snapshot discovered")
	invoked := false
	result, err, _ := p.commit.Do("commit:"+string(visibility)+":"+packagePath+"@"+snapshot.Version, func() (any, error) {
		invoked = true
		return p.publishSnapshot(ctx, packagePath, query, snapshot, visibility)
	})
	if !invoked {
		closeRepositorySnapshot(snapshot)
	}
	if err != nil {
		return "", err
	}
	return result.(string), nil
}

func (p *modulePublisher) publishSnapshot(ctx context.Context, packagePath, query string, snapshot *skill.RepositorySnapshot, visibility catalog.PublicationVisibility) (string, error) {
	input, err := p.prepareSnapshot(packagePath, query, snapshot, visibility)
	if err != nil {
		return "", err
	}
	created, resolvedVersion, err := p.publication.Publish(ctx, packagePath, input.version, input.entries, input.members, input.skillContents, visibility)
	if err != nil {
		return "", err
	}
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"member_count":       len(snapshot.Members),
		"new_artifact_count": map[bool]int{true: 1, false: 0}[created],
		"package_path":       packagePath,
		"version":            snapshot.Version,
	}).Debugf("repository publication committed")
	if visibility == catalog.CurrentPublication && p.afterCurrentPublication != nil {
		p.afterCurrentPublication(ctx, packagePath)
	}
	return resolvedVersion, nil
}

func (p *modulePublisher) prepareSnapshot(packagePath, query string, snapshot *skill.RepositorySnapshot, visibility catalog.PublicationVisibility) (modulePublicationInput, error) {
	if len(snapshot.Entries) == 0 || snapshot.Sum == "" || snapshot.Ref == "" || snapshot.TreeSHA == "" {
		return modulePublicationInput{}, withPublicationFailure(publicationFailureSnapshotIncomplete, fmt.Errorf("Repository source returned an incomplete Artifact for %s@%s", packagePath, query))
	}
	sum, sumErr := protocolartifact.PackageEntriesSum(snapshot.Entries, packagePath, snapshot.Version)
	if sumErr != nil {
		return modulePublicationInput{}, withPublicationFailure(artifactValidationPublicationCode(sumErr), sumErr)
	}
	if sum != snapshot.Sum {
		return modulePublicationInput{}, withPublicationFailure(publicationFailureArtifactSumMismatch, fmt.Errorf("Package Artifact Sum mismatch for %s@%s", packagePath, snapshot.Version))
	}

	published := make([]catalog.Skill, 0, len(snapshot.Members))
	skillContents := make([]moduleSkillContent, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		if member.Path == "" || member.TreeSHA == "" || member.Manifest.Name == "" || member.Manifest.Description == "" || len(member.Content) == 0 {
			return modulePublicationInput{}, withPublicationFailure(publicationFailureInvalidMember, fmt.Errorf("Repository source returned an invalid member for %s@%s", packagePath, query))
		}
		sourceLanguage := ""
		_, body, splitErr := protocolmanifest.Split(member.Content)
		if splitErr != nil {
			return modulePublicationInput{}, withPublicationFailure(publicationFailureInvalidSkillDocument, fmt.Errorf("split validated Skill document for %s@%s: %w", packagePath, query, splitErr))
		}
		analysis := p.languageAnalyzer.AnalyzeMarkdown(body)
		sourceLanguage = analysis.PrimaryLanguage
		published = append(published, catalog.Skill{
			PackagePath: packagePath, Path: member.Path, Name: member.Manifest.Name, Description: member.Manifest.Description,
			DescriptionDigest: catalog.DescriptionDigest(member.Manifest.Description), DocumentDigest: catalog.ContentDigest(member.Content), SourceLanguage: sourceLanguage,
		})
		skillContents = append(skillContents, moduleSkillContent{digest: catalog.ContentDigest(member.Content), content: member.Content})
	}
	version := catalog.PackageVersion{
		Version: snapshot.Version, Ref: snapshot.Ref, CommitSHA: snapshot.CommitSHA, TreeSHA: snapshot.TreeSHA,
		ContentSum: "", Sum: snapshot.Sum, CommitTime: snapshot.CommitTime,
	}
	contentSum, contentSumErr := protocolartifact.PackageContentSum(snapshot.Entries)
	if contentSumErr != nil {
		return modulePublicationInput{}, withPublicationFailure(artifactValidationPublicationCode(contentSumErr), contentSumErr)
	}
	version.ContentSum = contentSum
	return modulePublicationInput{version: version, entries: snapshot.Entries, members: published, skillContents: skillContents, visibility: visibility}, nil
}

func closeRepositorySnapshot(snapshot *skill.RepositorySnapshot) {
	// Repository snapshots own in-memory validated entries and need no cleanup.
}
