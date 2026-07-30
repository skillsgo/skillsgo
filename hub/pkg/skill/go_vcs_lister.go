/*
 * [INPUT]: Depends on the leased shared Git repository cache, canonical semantic Tag selection, ancestor-based pseudo-version generation, bounded timeouts, and storage revision metadata.
 * [OUTPUT]: Provides TTL-cached upstream canonical Repository Tag catalogs, explicit leased one-sync Backfill sessions with bounded top-twenty Tag or no-Tag default-branch revisions, precise preparation failures, and stable-first latest immutable revisions.
 * [POS]: Serves as the upstream version-listing adapter between Git source resolution and the Hub download protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/mod/semver"
)

type vcsLister struct {
	repositories *gitFetcher
	timeout      time.Duration
	ttl          time.Duration
	now          func() time.Time
	mu           sync.Mutex
	catalogs     map[string]tagCatalog
}

const maxRepositoryBackfillVersions = 20

type tagCatalog struct {
	expires  time.Time
	rev      storage.RevInfo
	versions []string
	err      error
}

type repositoryBackfillSession struct {
	packagePath string
	versions    []RepositoryTag
	fetcher     *gitFetcher
	repository  PackagePath
	repoDir     string
	release     func()
	closeOnce   sync.Once
}

func (session *repositoryBackfillSession) PackagePath() string { return session.packagePath }
func (session *repositoryBackfillSession) Versions() []RepositoryTag {
	return append([]RepositoryTag(nil), session.versions...)
}
func (session *repositoryBackfillSession) Close() { session.closeOnce.Do(session.release) }
func (session *repositoryBackfillSession) VisitSnapshots(ctx context.Context, revisions []string, visit func(string, *RepositorySnapshot, error) error) error {
	if visit == nil {
		return fmt.Errorf("Repository snapshot visitor is required")
	}
	for _, revision := range revisions {
		snapshot, err := session.fetcher.discoverRepositorySnapshot(ctx, session.packagePath, revision, session.repository, session.repoDir)
		if visitErr := visit(revision, snapshot, err); visitErr != nil {
			return visitErr
		}
	}
	return nil
}

// NewVCSLister creates an UpstreamLister that shares the Fetcher's persistent
// Git repository cache.
func NewVCSLister(fetcher RepositoryFetcher, timeout time.Duration) (RepositoryVersionLister, error) {
	repositories, ok := fetcher.(*gitFetcher)
	if !ok {
		return nil, fmt.Errorf("VCS lister requires the Git-backed Skill fetcher")
	}
	ttl := time.Minute
	if configured := strings.TrimSpace(os.Getenv("SKILLSGO_REPOSITORY_TAG_TTL")); configured != "" {
		parsed, err := time.ParseDuration(configured)
		if err != nil || parsed <= 0 {
			return nil, fmt.Errorf("invalid SKILLSGO_REPOSITORY_TAG_TTL %q", configured)
		}
		ttl = parsed
	}
	return &vcsLister{repositories: repositories, timeout: timeout, ttl: ttl, now: time.Now, catalogs: map[string]tagCatalog{}}, nil
}

func (l *vcsLister) ListRepositoryTags(ctx context.Context, packagePath string) ([]RepositoryTag, error) {
	parsed, err := ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", packagePath)
	}
	release, err := l.repositories.acquireRepository(parsed.String())
	if err != nil {
		return nil, err
	}
	defer release()
	if _, _, err := l.List(ctx, packagePath); err != nil {
		return nil, err
	}
	repoDir, err := l.repositories.repositoryDir(parsed.String())
	if err != nil {
		return nil, err
	}
	return canonicalRepositoryTags(ctx, repoDir)
}

func (l *vcsLister) ListRepositoryBackfillVersions(ctx context.Context, packagePath string) ([]RepositoryTag, error) {
	session, err := l.PrepareRepositoryBackfill(ctx, packagePath)
	if err != nil {
		return nil, err
	}
	defer session.Close()
	return session.Versions(), nil
}

func (l *vcsLister) PrepareRepositoryBackfill(ctx context.Context, packagePath string) (RepositoryBackfillSession, error) {
	parsed, err := ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return nil, withSourceFailure(SourceFailureInvalidPackagePath, fmt.Errorf("invalid canonical Repository ID %q", packagePath))
	}
	release, err := l.repositories.acquireRepository(packagePath)
	if err != nil {
		return nil, withSourceFailure(SourceFailureCacheUnavailable, err)
	}
	failed := true
	defer func() {
		if failed {
			release()
		}
	}()
	timeoutCtx, cancel := context.WithTimeout(ctx, l.timeout)
	defer cancel()
	if err := l.repositories.syncRepository(timeoutCtx, parsed); err != nil {
		return nil, withSourceFailure(sourceSyncFailureCode(err), err)
	}
	repoDir, err := l.repositories.repositoryDir(packagePath)
	if err != nil {
		return nil, withSourceFailure(SourceFailureCacheUnavailable, err)
	}
	versions, err := repositoryBackfillVersions(timeoutCtx, repoDir)
	if err != nil {
		return nil, withSourceFailure(SourceFailureVersionListFailed, err)
	}
	failed = false
	return &repositoryBackfillSession{packagePath: packagePath, versions: versions, fetcher: l.repositories, repository: parsed, repoDir: repoDir, release: release}, nil
}

func sourceSyncFailureCode(err error) SourceFailureCode {
	switch errors.Kind(err) {
	case errors.KindNotFound, errors.KindGatewayTimeout:
		return SourceFailureUnavailable
	case errors.KindRateLimit:
		return SourceFailureRateLimited
	case errors.KindBadRequest:
		return SourceFailureAccessRejected
	default:
		return SourceFailureSyncFailed
	}
}

func repositoryBackfillVersions(ctx context.Context, repoDir string) ([]RepositoryTag, error) {
	tags, err := canonicalRepositoryTags(ctx, repoDir)
	if err != nil {
		return nil, err
	}
	if len(tags) > 0 {
		if len(tags) > maxRepositoryBackfillVersions {
			tags = tags[len(tags)-maxRepositoryBackfillVersions:]
		}
		return tags, nil
	}
	defaultRef, err := gitOutput(ctx, repoDir, "symbolic-ref", "refs/remotes/origin/HEAD")
	if err != nil {
		return nil, err
	}
	output, err := gitOutput(ctx, repoDir, "rev-list", fmt.Sprintf("--max-count=%d", maxRepositoryBackfillVersions), defaultRef)
	if err != nil {
		return nil, err
	}
	commits := strings.Fields(output)
	versions := make([]RepositoryTag, 0, len(commits))
	for _, commitSHA := range commits {
		commitTime, err := gitCommitTime(ctx, repoDir, commitSHA)
		if err != nil {
			return nil, err
		}
		version, err := pseudoVersionForCommit(ctx, repoDir, commitSHA, commitTime)
		if err != nil {
			return nil, err
		}
		versions = append(versions, RepositoryTag{Version: version, CommitSHA: commitSHA})
	}
	return versions, nil
}

type listSFResp struct {
	rev      *storage.RevInfo
	versions []string
}

func (l *vcsLister) List(ctx context.Context, skillPath string) (*storage.RevInfo, []string, error) {
	const op errors.Op = "vcsLister.List"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	skillID, err := ParsePackagePath(skillPath)
	if err != nil {
		return nil, nil, errors.E(op, err, errors.KindNotFound)
	}
	release, err := l.repositories.acquireRepository(skillID.String())
	if err != nil {
		return nil, nil, errors.E(op, err)
	}
	defer release()
	l.mu.Lock()
	cached, ok := l.catalogs[skillID.String()]
	if ok && l.now().Before(cached.expires) {
		l.mu.Unlock()
		if cached.err != nil {
			return nil, nil, cached.err
		}
		rev := cached.rev
		return &rev, append([]string(nil), cached.versions...), nil
	}
	l.mu.Unlock()
	value, err, _ := l.repositories.syncs.Do("list:"+skillID.String(), func() (any, error) {

		timeoutCtx, cancel := context.WithTimeout(ctx, l.timeout)
		defer cancel()
		if err := l.repositories.syncRepository(timeoutCtx, skillID); err != nil {
			if errors.IsErr(timeoutCtx.Err(), context.DeadlineExceeded) {
				return nil, errors.E(op, err, errors.KindGatewayTimeout)
			}
			return nil, err
		}
		repoDir, err := l.repositories.repositoryDir(skillID.String())
		if err != nil {
			return nil, errors.E(op, err)
		}
		tags, err := canonicalRepositoryTags(timeoutCtx, repoDir)
		if err != nil {
			return nil, errors.E(op, err)
		}
		versions := make([]string, 0, len(tags))
		for _, tag := range tags {
			versions = append(versions, tag.Version)
		}

		version := ""
		ref := ""
		if selected := latestSemanticVersion(versions); selected != "" {
			version = selected
			ref = semanticTagRef(timeoutCtx, repoDir, version)
		} else {
			ref, err = gitOutput(timeoutCtx, repoDir, "symbolic-ref", "refs/remotes/origin/HEAD")
			if err != nil {
				return nil, errors.E(op, err)
			}
		}
		hash, err := gitOutput(timeoutCtx, repoDir, "rev-parse", ref+"^{commit}")
		if err != nil {
			return nil, errors.E(op, err)
		}
		commitTime, err := gitCommitTime(timeoutCtx, repoDir, hash)
		if err != nil {
			return nil, errors.E(op, err)
		}
		if version == "" {
			version, err = pseudoVersionForCommit(timeoutCtx, repoDir, hash, commitTime)
			if err != nil {
				return nil, errors.E(op, err)
			}
		}

		return listSFResp{
			rev: &storage.RevInfo{
				Version: version,
				Time:    commitTime,
			},
			versions: versions,
		}, nil
	})
	if err != nil {
		negativeTTL := 15 * time.Second
		if l.ttl < negativeTTL {
			negativeTTL = l.ttl
		}
		l.mu.Lock()
		l.catalogs[skillID.String()] = tagCatalog{expires: l.now().Add(negativeTTL), err: err}
		l.mu.Unlock()
		return nil, nil, err
	}
	result := value.(listSFResp)
	l.mu.Lock()
	l.catalogs[skillID.String()] = tagCatalog{expires: l.now().Add(l.ttl), rev: *result.rev, versions: append([]string(nil), result.versions...)}
	l.mu.Unlock()
	return result.rev, result.versions, nil
}

// canonicalRepositoryTags returns one deterministic local view of fetched
// upstream tags, with a local-tag fallback used by repository fixtures.
func canonicalRepositoryTags(ctx context.Context, repoDir string) ([]RepositoryTag, error) {
	versions := map[string]bool{}
	if local, err := gitOutput(ctx, repoDir, "tag", "--list"); err == nil {
		for _, version := range strings.Fields(local) {
			if isCanonicalSemanticVersion(version) {
				versions[version] = true
			}
		}
	}
	if upstream, err := gitOutput(ctx, repoDir, "for-each-ref", "--format=%(refname:strip=3)", "refs/skillsgo/upstream-tags"); err == nil {
		for _, version := range strings.Fields(upstream) {
			if isCanonicalSemanticVersion(version) {
				versions[version] = true
			}
		}
	}
	tags := make([]RepositoryTag, 0, len(versions))
	for version := range versions {
		ref := semanticTagRef(ctx, repoDir, version)
		commitSHA, err := gitOutput(ctx, repoDir, "rev-parse", ref+"^{commit}")
		if err != nil {
			return nil, fmt.Errorf("resolve Repository Tag %s through %s: %w", version, ref, err)
		}
		tags = append(tags, RepositoryTag{Version: version, CommitSHA: commitSHA})
	}
	sort.Slice(tags, func(i, j int) bool { return semver.Compare(tags[i].Version, tags[j].Version) < 0 })
	return tags, nil
}
