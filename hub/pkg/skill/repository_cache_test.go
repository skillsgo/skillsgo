/*
 * [INPUT]: Depends on temporary Git repositories, the Skill ID parser, repository caching, and Git resolution behavior.
 * [OUTPUT]: Specifies shared repository caching, nested Skill resolution, refresh, tag listing, and concurrent access behavior.
 * [POS]: Serves as the repository integration contract for the Hub Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/spf13/afero"
	"github.com/stretchr/testify/require"
	"golang.org/x/mod/module"
)

type localRepositoryFixture struct {
	origin  string
	work    string
	cache   string
	skillID string
	fetcher *gitFetcher
}

func newLocalRepositoryFixture(t *testing.T) *localRepositoryFixture {
	t.Helper()
	root := t.TempDir()
	f := &localRepositoryFixture{
		origin:  filepath.Join(root, "origin.git"),
		work:    filepath.Join(root, "work"),
		cache:   filepath.Join(root, "cache"),
		skillID: "github.com/skillsgo-test/repo",
	}
	runGit(t, "", "init", "--bare", "--initial-branch=main", f.origin)
	runGit(t, "", "clone", f.origin, f.work)
	runGit(t, f.work, "config", "user.name", "SkillsGo Test")
	runGit(t, f.work, "config", "user.email", "skillsgo@example.com")
	f.writeSkill(t, ".", "repo", "initial")
	f.writeSkill(t, "skills/child", "child", "nested")
	f.commit(t, "initial")
	runGit(t, f.work, "tag", "v1.0.0")
	runGit(t, f.work, "push", "origin", "HEAD", "--tags")

	fetcher, err := NewFetcher(f.cache, afero.NewOsFs())
	require.NoError(t, err)
	f.fetcher = fetcher.(*gitFetcher)
	f.fetcher.cloneURL = func(SkillID) string { return f.origin }
	return f
}

func (f *localRepositoryFixture) writeSkill(t *testing.T, dir, name, description string) {
	t.Helper()
	path := filepath.Join(f.work, dir)
	require.NoError(t, os.MkdirAll(path, 0o755))
	content := "---\nname: " + name + "\ndescription: " + description + "\n---\n\n# " + name + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), []byte(content), 0o644))
}

func (f *localRepositoryFixture) commit(t *testing.T, message string) {
	t.Helper()
	runGit(t, f.work, "add", ".")
	runGit(t, f.work, "commit", "-m", message)
}

func runGit(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_CONFIG_NOSYSTEM=1")
	output, err := cmd.CombinedOutput()
	require.NoError(t, err, "%s", output)
	return string(output)
}

func TestRepositoryCacheResolveAndFetchResolved(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	resolution, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.NotEmpty(t, resolution.CommitSHA)
	require.NotEmpty(t, resolution.TreeSHA)

	version, err := f.fetcher.FetchResolved(t.Context(), f.skillID, resolution)
	require.NoError(t, err)
	defer version.Zip.Close()
	zipBytes, err := io.ReadAll(version.Zip)
	require.NoError(t, err)
	require.NotEmpty(t, zipBytes)
}

func TestRepositoryCacheRefreshesMutableBranch(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	first, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)

	f.writeSkill(t, ".", "repo", "changed")
	f.commit(t, "change Skill")
	runGit(t, f.work, "push", "origin", "HEAD")
	second, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.NotEqual(t, first.CommitSHA, second.CommitSHA)
	require.NotEqual(t, first.TreeSHA, second.TreeSHA)
	require.NotEqual(t, first.Version, second.Version)
	require.True(t, module.IsPseudoVersion(second.Version), second.Version)
}

func TestRevisionResolutionCanonicalizesTagsAndUntaggedCommits(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	tagged, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", tagged.Version)
	require.Equal(t, "refs/tags/v1.0.0", tagged.Ref)

	f.writeSkill(t, ".", "repo", "untagged change")
	f.commit(t, "untagged change")
	runGit(t, f.work, "push", "origin", "HEAD")
	commit := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
	branch, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.True(t, module.IsPseudoVersion(branch.Version), branch.Version)
	require.Equal(t, "refs/heads/main", branch.Ref)
	exact, err := f.fetcher.Resolve(t.Context(), f.skillID, commit)
	require.NoError(t, err)
	require.Equal(t, branch.Version, exact.Version)
	require.Equal(t, commit, exact.Ref)

	runGit(t, f.work, "tag", "v1.1.0")
	runGit(t, f.work, "push", "origin", "--tags")
	taggedExact, err := f.fetcher.Resolve(t.Context(), f.skillID, commit)
	require.NoError(t, err)
	require.Equal(t, "v1.1.0", taggedExact.Version)
	require.Equal(t, "refs/tags/v1.1.0", taggedExact.Ref)
}

func TestRepositoryTagCatalogUsesInjectedClockForFreshAndStaleTTL(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	now := time.Date(2026, 7, 18, 12, 0, 0, 0, time.UTC)
	lister := &vcsLister{
		repositories: f.fetcher,
		timeout:      time.Minute,
		ttl:          time.Minute,
		now:          func() time.Time { return now },
		catalogs:     map[string]tagCatalog{},
	}
	_, versions, err := lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0"}, versions)

	runGit(t, f.work, "tag", "v2.0.0")
	runGit(t, f.work, "push", "origin", "--tags")
	_, versions, err = lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0"}, versions, "fresh catalog must not repeat upstream discovery")

	now = now.Add(time.Minute + time.Nanosecond)
	_, versions, err = lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0", "v2.0.0"}, versions)
}

func TestRepositoryCacheIsSharedBySkillsInOneRepository(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	_, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	_, err = f.fetcher.Resolve(t.Context(), f.skillID+"/-/skills/child", "main")
	require.NoError(t, err)

	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.True(t, isGitRepository(repositoryDir))
	entries, err := os.ReadDir(filepath.Join(f.cache, "repositories", "github.com", "skillsgo-test"))
	require.NoError(t, err)
	require.Len(t, entries, 1)
}

func TestRepositoryDiscoverySkipsInvalidCandidatesWithoutBlockingValidSiblings(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	invalidDir := filepath.Join(f.work, "skills", "invalid")
	require.NoError(t, os.MkdirAll(invalidDir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(invalidDir, "SKILL.md"), []byte("---\nname: invalid\n---\nMissing description.\n"), 0o644))
	f.commit(t, "add invalid candidate")
	runGit(t, f.work, "tag", "v1.1.0")
	runGit(t, f.work, "push", "origin", "HEAD", "--tags")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "v1.1.0")
	require.NoError(t, err)
	t.Cleanup(func() {
		for _, member := range snapshot.Members {
			if member.Version != nil && member.Version.Zip != nil {
				require.NoError(t, member.Version.Zip.Close())
			}
		}
	})
	ids := make([]string, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		ids = append(ids, member.SkillID)
	}
	require.Contains(t, ids, f.skillID)
	require.Contains(t, ids, f.skillID+"/-/skills/child")
	require.NotContains(t, ids, f.skillID+"/-/skills/invalid")
}

func TestRepositoryCacheCoalescesConcurrentResolve(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	const requests = 8
	start := make(chan struct{})
	results := make(chan *Resolution, requests)
	errs := make(chan error, requests)
	var workers sync.WaitGroup
	for range requests {
		workers.Add(1)
		go func() {
			defer workers.Done()
			<-start
			resolution, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
			results <- resolution
			errs <- err
		}()
	}
	close(start)
	workers.Wait()
	close(results)
	close(errs)

	var commitSHA string
	for err := range errs {
		require.NoError(t, err)
	}
	for resolution := range results {
		require.NotNil(t, resolution)
		if commitSHA == "" {
			commitSHA = resolution.CommitSHA
		}
		require.Equal(t, commitSHA, resolution.CommitSHA)
	}
	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.True(t, isGitRepository(repositoryDir))
}

func TestRepositoryCacheRecoversCorruptRepository(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	_, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.NoError(t, os.RemoveAll(filepath.Join(repositoryDir, ".git")))

	_, err = f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.True(t, isGitRepository(repositoryDir))
}

func TestRepositoryCacheKeepsUsableCacheWhenFetchFails(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	_, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.NoError(t, os.Rename(f.origin, f.origin+".offline"))

	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()
	_, err = f.fetcher.Resolve(ctx, f.skillID, "main")
	require.Error(t, err)
	require.True(t, isGitRepository(repositoryDir))
}

func TestVCSListerUsesRepositoryCache(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	lister, err := NewVCSLister(f.fetcher, 10*time.Second)
	require.NoError(t, err)
	revision, versions, err := lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Equal(t, []string{"v1.0.0"}, versions)
	require.Equal(t, "v1.0.0", revision.Version)

	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.True(t, isGitRepository(repositoryDir))
}

func TestNoTagLatestObservesRemoteDefaultBranchAndReturnsPseudoVersion(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	runGit(t, f.work, "tag", "-d", "v1.0.0")
	runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")
	lister, err := NewVCSLister(f.fetcher, 10*time.Second)
	require.NoError(t, err)
	revision, versions, err := lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Empty(t, versions)
	require.True(t, module.IsPseudoVersion(revision.Version), revision.Version)

	resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "latest")
	require.NoError(t, err)
	require.Equal(t, revision.Version, resolved.Version)
	require.Equal(t, "refs/heads/main", resolved.Ref)
}
