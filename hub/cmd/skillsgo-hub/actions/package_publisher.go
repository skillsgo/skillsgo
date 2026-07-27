/*
 * [INPUT]: Depends on request-scoped structured logging, one resolved Repository snapshot, and the ordered immutable publication commit boundary.
 * [OUTPUT]: Materializes every accepted Package Skill, computes source digests, prepares byte-stable Package Version Info plus content-addressed Skill objects, and emits a bounded publication lifecycle.
 * [POS]: Serves as the observable cold-publication coordinator between Git Repository discovery, artifact storage, and Package Info visibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"golang.org/x/sync/singleflight"
)

type repositoryMaterializer interface {
	Materialize(ctx context.Context, packagePath, query string) (string, error)
}

type historicalRepositoryMaterializer interface {
	MaterializeHistorical(ctx context.Context, packagePath, query string) (string, error)
}

type modulePublisher struct {
	fetcher     skill.RepositoryFetcher
	publication *modulePublicationCommit
	work        singleflight.Group
	commit      singleflight.Group
	upstream    chan struct{}
	mu          sync.Mutex
	negative    map[string]negativePublication
	now         func() time.Time
	negativeTTL time.Duration
}

type negativePublication struct {
	expires time.Time
	err     error
}

func newPackagePublisher(fetcher skill.RepositoryFetcher, backend storage.Backend, metadata *catalog.Catalog) *modulePublisher {
	return &modulePublisher{fetcher: fetcher, publication: newPackagePublicationCommit(backend, metadata), upstream: make(chan struct{}, 8), negative: make(map[string]negativePublication), now: time.Now, negativeTTL: 10 * time.Second}
}

func (p *modulePublisher) Materialize(ctx context.Context, packagePath, query string) (string, error) {
	return p.materializePublication(ctx, packagePath, query, catalog.CurrentPublication)
}

func (p *modulePublisher) MaterializeHistorical(ctx context.Context, packagePath, query string) (string, error) {
	return p.materializePublication(ctx, packagePath, query, catalog.HistoricalPublication)
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
	if snapshot.Archive == nil || snapshot.ArchiveSize <= 0 || snapshot.Sum == "" || snapshot.Ref == "" || snapshot.TreeSHA == "" {
		return "", fmt.Errorf("Repository source returned an incomplete Artifact for %s@%s", packagePath, query)
	}
	archive, err := io.ReadAll(io.LimitReader(snapshot.Archive, protocolartifact.MaxArchiveBytes+1))
	if err != nil {
		return "", fmt.Errorf("read Package Artifact: %w", err)
	}
	if int64(len(archive)) != snapshot.ArchiveSize || len(archive) > protocolartifact.MaxArchiveBytes {
		return "", fmt.Errorf("Package Artifact size mismatch for %s@%s", packagePath, snapshot.Version)
	}
	if sum, sumErr := protocolartifact.PackageSum(archive, packagePath, snapshot.Version); sumErr != nil || sum != snapshot.Sum {
		return "", fmt.Errorf("Package Artifact Sum mismatch for %s@%s", packagePath, snapshot.Version)
	}

	published := make([]catalog.Skill, 0, len(snapshot.Members))
	skillContents := make([]moduleSkillContent, 0, len(snapshot.Members))
	release := protocolapi.PackageInfo{
		SchemaVersion: protocolapi.SchemaVersion,
		Kind:          protocolapi.KindPackage,
		PackagePath:   packagePath,
		Version:       snapshot.Version,
		Time:          snapshot.CommitTime,
		Sum:           snapshot.Sum,
		ArchiveSize:   snapshot.ArchiveSize,
		Skills:        make([]protocolapi.PackageSkill, 0, len(snapshot.Members)),
	}
	for _, member := range snapshot.Members {
		if member.Path == "" || member.TreeSHA == "" || member.Manifest.Name == "" || member.Manifest.Description == "" || len(member.Content) == 0 {
			return "", fmt.Errorf("Repository source returned an invalid member for %s@%s", packagePath, query)
		}
		release.Skills = append(release.Skills, protocolapi.PackageSkill{Name: member.Manifest.Name, Path: member.Path})
		published = append(published, catalog.Skill{
			PackagePath: packagePath, Path: member.Path, Name: member.Manifest.Name, Description: member.Manifest.Description,
			DescriptionDigest: catalog.DescriptionDigest(member.Manifest.Description), DocumentDigest: catalog.ContentDigest(member.Content),
		})
		skillContents = append(skillContents, moduleSkillContent{digest: catalog.ContentDigest(member.Content), content: member.Content})
	}
	releaseInfo, err := json.Marshal(release)
	if err != nil {
		return "", fmt.Errorf("encode Package Info: %w", err)
	}

	version := catalog.PackageVersion{
		Version: snapshot.Version, Ref: snapshot.Ref, CommitSHA: snapshot.CommitSHA, TreeSHA: snapshot.TreeSHA,
		Sum: snapshot.Sum, ArchiveSize: snapshot.ArchiveSize, CommitTime: snapshot.CommitTime,
	}
	created, err := p.publication.Publish(ctx, packagePath, version, archive, snapshot.ArchiveMD5, releaseInfo, published, skillContents, visibility)
	if err != nil {
		return "", err
	}
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"member_count":       len(snapshot.Members),
		"new_artifact_count": map[bool]int{true: 1, false: 0}[created],
		"package_path":       packagePath,
		"version":            snapshot.Version,
	}).Debugf("repository publication committed")
	return snapshot.Version, nil
}

func closeRepositorySnapshot(snapshot *skill.RepositorySnapshot) {
	if snapshot == nil {
		return
	}
	if snapshot.Archive != nil {
		_ = snapshot.Archive.Close()
	}
}
