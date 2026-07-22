/*
 * [INPUT]: Depends on the shared Git repository cache, canonical semantic Tag selection, ancestor-based pseudo-version generation, bounded timeouts, and storage revision metadata.
 * [OUTPUT]: Provides TTL-cached upstream canonical Repository Tag catalogs, per-Tag commit identities, and their stable-first latest immutable revision.
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

type tagCatalog struct {
	expires  time.Time
	rev      storage.RevInfo
	versions []string
	err      error
}

// NewVCSLister creates an UpstreamLister that shares the Fetcher's persistent
// Git repository cache.
func NewVCSLister(fetcher Fetcher, timeout time.Duration) (RepositoryVersionLister, error) {
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

func (l *vcsLister) ListRepositoryTags(ctx context.Context, repositoryID string) ([]RepositoryTag, error) {
	parsed, err := ParseSkillID(repositoryID)
	if err != nil || parsed.SkillPath != "." || parsed.String() != repositoryID {
		return nil, fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	repoDir, err := l.repositories.repositoryDir(parsed.Repository)
	if err != nil {
		return nil, err
	}
	timeoutCtx, cancel := context.WithTimeout(ctx, l.timeout)
	defer cancel()
	if !isGitRepository(repoDir) {
		if err := l.repositories.syncRepository(timeoutCtx, parsed); err != nil {
			return nil, err
		}
	}
	githubSource := strings.EqualFold(strings.SplitN(parsed.Repository, "/", 2)[0], "github.com")
	output, err := l.repositories.runGitTransport(timeoutCtx, repoDir, githubSource,
		"-c", "http.followRedirects=false", "ls-remote", "--tags", "origin")
	if err != nil {
		return nil, errors.E("vcsLister.ListRepositoryTags", fmt.Errorf("git ls-remote failed: %s", gitTransportDiagnostic(output)))
	}
	tagsByVersion := make(map[string]RepositoryTag)
	for _, line := range strings.Split(string(output), "\n") {
		fields := strings.Fields(line)
		if len(fields) != 2 || !strings.HasPrefix(fields[1], "refs/tags/") {
			continue
		}
		version := strings.TrimPrefix(fields[1], "refs/tags/")
		peeled := strings.HasSuffix(version, "^{}")
		version = strings.TrimSuffix(version, "^{}")
		if !isCanonicalSemanticVersion(version) {
			continue
		}
		if current, exists := tagsByVersion[version]; !exists || peeled || current.CommitSHA == "" {
			tagsByVersion[version] = RepositoryTag{Version: version, CommitSHA: fields[0]}
		}
	}
	tags := make([]RepositoryTag, 0, len(tagsByVersion))
	for _, tag := range tagsByVersion {
		tags = append(tags, tag)
	}
	sort.Slice(tags, func(i, j int) bool { return semver.Compare(tags[i].Version, tags[j].Version) < 0 })
	return tags, nil
}

type listSFResp struct {
	rev      *storage.RevInfo
	versions []string
}

func (l *vcsLister) List(ctx context.Context, skillPath string) (*storage.RevInfo, []string, error) {
	const op errors.Op = "vcsLister.List"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	skillID, err := ParseSkillID(skillPath)
	if err != nil {
		return nil, nil, errors.E(op, err, errors.KindNotFound)
	}
	l.mu.Lock()
	cached, ok := l.catalogs[skillID.Repository]
	if ok && l.now().Before(cached.expires) {
		l.mu.Unlock()
		if cached.err != nil {
			return nil, nil, cached.err
		}
		rev := cached.rev
		return &rev, append([]string(nil), cached.versions...), nil
	}
	l.mu.Unlock()
	value, err, _ := l.repositories.syncs.Do("list:"+skillID.Repository, func() (any, error) {

		timeoutCtx, cancel := context.WithTimeout(ctx, l.timeout)
		defer cancel()
		if err := l.repositories.syncRepository(timeoutCtx, skillID); err != nil {
			if errors.IsErr(timeoutCtx.Err(), context.DeadlineExceeded) {
				return nil, errors.E(op, err, errors.KindGatewayTimeout)
			}
			return nil, err
		}
		repoDir, err := l.repositories.repositoryDir(skillID.Repository)
		if err != nil {
			return nil, errors.E(op, err)
		}
		tagOutput, err := gitOutput(timeoutCtx, repoDir, "tag", "--list")
		if err != nil {
			return nil, errors.E(op, err)
		}
		versions := make([]string, 0)
		for _, tag := range strings.Fields(tagOutput) {
			if isCanonicalSemanticVersion(tag) {
				versions = append(versions, tag)
			}
		}
		sort.Slice(versions, func(i, j int) bool { return semver.Compare(versions[i], versions[j]) < 0 })

		version := ""
		ref := ""
		if selected := latestSemanticVersion(versions); selected != "" {
			version = selected
			ref = "refs/tags/" + version
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
		l.catalogs[skillID.Repository] = tagCatalog{expires: l.now().Add(negativeTTL), err: err}
		l.mu.Unlock()
		return nil, nil, err
	}
	result := value.(listSFResp)
	l.mu.Lock()
	l.catalogs[skillID.Repository] = tagCatalog{expires: l.now().Add(l.ttl), rev: *result.rev, versions: append([]string(nil), result.versions...)}
	l.mu.Unlock()
	return result.rev, result.versions, nil
}
