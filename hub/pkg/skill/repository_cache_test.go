/*
 * [INPUT]: Depends on temporary Git repositories, the Repository ID parser, repository cache leases and lifecycle policy, Git resolution, and SkillsGo-owned Artifact tree assembly.
 * [OUTPUT]: Specifies shared repository caching, TTL and quota reclamation, active-repository protection, Go-compatible ancestor-based pseudo-versions, bounded no-Tag default-branch backfill selection, batch-version identity including v2+ tags without Go Package suffixes, complete Git-tracked Package Artifact trees with safe internal symlinks, export exclusions, member tree identity, refresh, tag listing, and concurrent access behavior.
 * [POS]: Serves as the repository integration contract for the Hub Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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

	fetcher, err := NewRepositoryFetcher(f.cache, afero.NewOsFs())
	require.NoError(t, err)
	f.fetcher = fetcher.(*gitFetcher)
	f.fetcher.cloneURL = func(PackagePath) string { return f.origin }
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

func artifactIdentity(t *testing.T, infoBytes []byte) (string, string, string) {
	t.Helper()
	var info struct {
		Version   string `json:"Version"`
		CommitSHA string `json:"CommitSHA"`
		TreeSHA   string `json:"TreeSHA"`
	}
	require.NoError(t, json.Unmarshal(infoBytes, &info))
	return info.Version, info.CommitSHA, info.TreeSHA
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
	require.Equal(t, commit, branch.Ref)
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

func TestRevisionResolutionBasesPseudoVersionOnHighestAncestorTag(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	f.writeSkill(t, ".", "repo", "untagged descendant")
	f.commit(t, "untagged descendant")
	runGit(t, f.work, "push", "origin", "HEAD")

	commit := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
	commitTime, err := gitCommitTime(t.Context(), f.work, commit)
	require.NoError(t, err)
	resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)

	require.Equal(t, module.PseudoVersion("v1", "v1.0.0", commitTime, commit[:12]), resolved.Version)
	require.Equal(t, "v1.0.1-0", resolved.Version[:len("v1.0.1-0")])
	require.Equal(t, commit, resolved.CommitSHA)
}

func TestRevisionResolutionUsesHighestTagAtCommitWhileReleasePrefersStable(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	runGit(t, f.work, "tag", "v2.0.0-beta.1")
	runGit(t, f.work, "push", "origin", "--tags")

	branch, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.Equal(t, "v2.0.0-beta.1", branch.Version)
	require.Equal(t, "refs/tags/v2.0.0-beta.1", branch.Ref)

	release, err := f.fetcher.Resolve(t.Context(), f.skillID, "latest")
	require.NoError(t, err)
	require.Equal(t, "v1.0.0", release.Version)
	require.Equal(t, "refs/tags/v1.0.0", release.Ref)
}

func TestPseudoVersionRemainsResolvableAfterItsCommitIsTagged(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	runGit(t, f.work, "tag", "-d", "v1.0.0")
	runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")

	beforeTag, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.True(t, strings.HasPrefix(beforeTag.Version, "v0.0.0-"), beforeTag.Version)

	runGit(t, f.work, "tag", "v1.0.0")
	runGit(t, f.work, "push", "origin", "v1.0.0")
	pinned, err := f.fetcher.Resolve(t.Context(), f.skillID, beforeTag.Version)
	require.NoError(t, err)
	require.Equal(t, beforeTag.Version, pinned.Version)
	require.Equal(t, beforeTag.CommitSHA, pinned.CommitSHA)

	f.writeSkill(t, ".", "repo", "after tag")
	f.commit(t, "after tag")
	runGit(t, f.work, "push", "origin", "HEAD")
	afterTag, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	require.True(t, strings.HasPrefix(afterTag.Version, "v1.0.1-0."), afterTag.Version)
	require.NotEqual(t, beforeTag.CommitSHA, afterTag.CommitSHA)
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

func TestRepositoryCacheUsesOnlyCanonicalRepositoryIdentity(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	_, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	_, err = f.fetcher.Resolve(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	_, err = f.fetcher.Resolve(t.Context(), f.skillID+"/-/skills/child", "main")
	require.Error(t, err, "member-shaped coordinates must not alias the Repository cache")

	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.True(t, isGitRepository(repositoryDir))
	entries, err := os.ReadDir(filepath.Join(f.cache, "repositories", "github.com"))
	require.NoError(t, err)
	require.Len(t, entries, 1)
}

func TestRepositoryCacheCleanupRemovesExpiredInactiveRepository(t *testing.T) {
	root := t.TempDir()
	fetcher, err := NewRepositoryFetcher(root, afero.NewOsFs(), WithRepositoryCachePolicy(time.Hour, 0))
	require.NoError(t, err)
	g := fetcher.(*gitFetcher)
	now := time.Date(2026, 7, 22, 12, 0, 0, 0, time.UTC)
	g.now = func() time.Time { return now }
	dir := writeRepositoryCacheFixture(t, g, "github.com/acme/expired", now.Add(-2*time.Hour), 32)

	require.NoError(t, g.cleanupRepositoryCache())
	_, err = os.Stat(dir)
	require.ErrorIs(t, err, os.ErrNotExist)
}

func TestRepositoryCacheCleanupUsesLRUQuotaAndProtectsActiveRepository(t *testing.T) {
	root := t.TempDir()
	fetcher, err := NewRepositoryFetcher(root, afero.NewOsFs(), WithRepositoryCachePolicy(0, 80))
	require.NoError(t, err)
	g := fetcher.(*gitFetcher)
	now := time.Date(2026, 7, 22, 12, 0, 0, 0, time.UTC)
	g.now = func() time.Time { return now }
	activeDir := writeRepositoryCacheFixture(t, g, "github.com/acme/active", now.Add(-3*time.Hour), 64)
	oldDir := writeRepositoryCacheFixture(t, g, "github.com/acme/old", now.Add(-2*time.Hour), 64)
	newDir := writeRepositoryCacheFixture(t, g, "github.com/acme/new", now.Add(-time.Hour), 64)
	release, err := g.acquireRepository("github.com/acme/active")
	require.NoError(t, err)
	defer release()

	require.NoError(t, g.cleanupRepositoryCache())
	require.DirExists(t, activeDir)
	require.NoDirExists(t, oldDir)
	require.NoDirExists(t, newDir, "quota remains exceeded after preserving the active mirror")
}

func writeRepositoryCacheFixture(t *testing.T, g *gitFetcher, repository string, updatedAt time.Time, bytes int) string {
	t.Helper()
	dir, err := g.repositoryDir(repository)
	require.NoError(t, err)
	require.NoError(t, os.MkdirAll(dir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "objects.pack"), make([]byte, bytes), 0o644))
	metadata, err := json.Marshal(repositoryMetadata{Repository: repository, URL: "https://" + repository, UpdatedAt: updatedAt})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(dir, "metadata.json"), metadata, 0o644))
	require.NoError(t, os.Chtimes(filepath.Join(dir, "metadata.json"), updatedAt, updatedAt))
	return dir
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
	names := make([]string, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		names = append(names, member.Name)
	}
	require.Contains(t, names, "repo")
	require.Contains(t, names, "child")
	require.NotContains(t, names, "invalid")
}

func TestRepositoryDiscoveryPreservesDuplicateSkillNamesAtDistinctPaths(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	f.writeSkill(t, "skills/duplicate", "child", "duplicate canonical name")
	f.commit(t, "add duplicate Skill name")
	runGit(t, f.work, "tag", "v1.1.0")
	runGit(t, f.work, "push", "origin", "HEAD", "--tags")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "v1.1.0")
	require.NoError(t, err)
	paths := make([]string, 0, 2)
	for _, member := range snapshot.Members {
		if member.Name == "child" {
			paths = append(paths, member.Path)
		}
	}
	require.Equal(t, []string{"skills/child", "skills/duplicate"}, paths)
}

func TestRepositoryDiscoveryExcludesSkillsInstalledUnderHiddenDirectories(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	f.writeSkill(t, ".claude/skills/release-skills", "release-skills", "installed dependency")
	f.writeSkill(t, ".agents/skills/shared-skill", "shared-skill", "installed dependency")
	f.writeSkill(t, ".codex/skills/local-skill", "local-skill", "installed dependency")
	f.commit(t, "add installed hidden skills")
	runGit(t, f.work, "tag", "v1.1.0")
	runGit(t, f.work, "push", "origin", "HEAD", "--tags")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "v1.1.0")
	require.NoError(t, err)
	names := make([]string, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		names = append(names, member.Name)
	}
	require.ElementsMatch(t, []string{"repo", "child"}, names)
	artifactNames := entryNames(snapshot.Entries)
	require.NotContains(t, artifactNames, ".claude/skills/release-skills/SKILL.md")
	require.NotContains(t, artifactNames, ".agents/skills/shared-skill/SKILL.md")
	require.NotContains(t, artifactNames, ".codex/skills/local-skill/SKILL.md")
}

func TestRepositoryArtifactUsesTrackedTreeAndExportIgnore(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	require.NoError(t, os.WriteFile(filepath.Join(f.work, ".gitignore"), []byte("untracked.txt\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(f.work, ".gitattributes"), []byte("excluded.txt export-ignore\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(f.work, "included.txt"), []byte("included\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(f.work, "excluded.txt"), []byte("excluded\n"), 0o644))
	f.commit(t, "add export rules")
	require.NoError(t, os.WriteFile(filepath.Join(f.work, "untracked.txt"), []byte("worktree only\n"), 0o644))
	runGit(t, f.work, "tag", "v1.1.0")
	runGit(t, f.work, "push", "origin", "HEAD", "--tags")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "v1.1.0")
	require.NoError(t, err)
	names := entryNames(snapshot.Entries)
	require.Contains(t, names, ".gitignore")
	require.Contains(t, names, ".gitattributes")
	require.Contains(t, names, "included.txt")
	require.NotContains(t, names, "excluded.txt")
	require.NotContains(t, names, "untracked.txt")
}

func TestRepositoryArtifactPreservesInternalSymlinksAndSkipsUnsafeOnes(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	require.NoError(t, os.WriteFile(filepath.Join(f.work, "CLAUDE.md"), []byte("shared instructions\n"), 0o644))
	require.NoError(t, os.Symlink("CLAUDE.md", filepath.Join(f.work, "AGENTS.md")))
	require.NoError(t, os.Symlink("../../outside", filepath.Join(f.work, "outside-link")))
	require.NoError(t, os.Symlink("missing.md", filepath.Join(f.work, "broken-link")))
	f.commit(t, "add symlinks")
	runGit(t, f.work, "tag", "v1.1.0")
	runGit(t, f.work, "push", "origin", "HEAD", "--tags")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "v1.1.0")
	require.NoError(t, err)
	entries := make(map[string]protocolartifact.Entry, len(snapshot.Entries))
	for _, file := range snapshot.Entries {
		entries[file.Path] = file
	}
	link, ok := entries["AGENTS.md"]
	require.True(t, ok)
	require.True(t, link.IsSymlink())
	require.Equal(t, "CLAUDE.md", string(link.Contents))
	require.NotContains(t, entries, "outside-link")
	require.NotContains(t, entries, "broken-link")
}

func TestRepositoryDiscoveryUsesTagAsSharedBatchVersionAndTreeAsMemberIdentity(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "latest")
	require.NoError(t, err)

	require.Equal(t, "v1.0.0", snapshot.Version)
	require.NotEmpty(t, snapshot.CommitSHA)
	require.Len(t, snapshot.Members, 2)
	trees := make(map[string]struct{}, len(snapshot.Members))
	for _, member := range snapshot.Members {
		require.NotEmpty(t, member.TreeSHA)
		trees[member.TreeSHA] = struct{}{}
	}
	require.Len(t, trees, 2, "each Skill directory must retain its own tree identity")
}

func TestRepositoryDiscoveryPackagesV2WithoutGoPackagePathSuffix(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	runGit(t, f.work, "tag", "v2.2.10")
	runGit(t, f.work, "push", "origin", "--tags")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "v2.2.10")
	require.NoError(t, err)
	require.Equal(t, "v2.2.10", snapshot.Version)
	require.Len(t, snapshot.Members, 2)
	require.Contains(t, entryNames(snapshot.Entries), "SKILL.md")
	require.Contains(t, entryNames(snapshot.Entries), "skills/child/SKILL.md")
}

func entryNames(files []protocolartifact.Entry) []string {
	names := make([]string, 0, len(files))
	for _, file := range files {
		names = append(names, file.Path)
	}
	return names
}

func TestRepositoryDiscoveryLatestFallsBackToDefaultBranchPseudoVersion(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	runGit(t, f.work, "tag", "-d", "v1.0.0")
	runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")

	snapshot, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "latest")
	require.NoError(t, err)

	require.True(t, module.IsPseudoVersion(snapshot.Version), snapshot.Version)
	require.Contains(t, snapshot.Version, snapshot.CommitSHA[:12])
	for _, member := range snapshot.Members {
		require.NotEmpty(t, member.TreeSHA)
	}
}

func TestUnrelatedSkillChangeAdvancesBatchWithoutChangingSiblingTree(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	first, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "main")
	require.NoError(t, err)
	childTree := ""
	for _, member := range first.Members {
		if member.Name == "child" {
			childTree = member.TreeSHA
		}
	}
	require.NotEmpty(t, childTree)

	f.writeSkill(t, ".", "repo", "root changed only")
	f.commit(t, "change root Skill only")
	runGit(t, f.work, "push", "origin", "HEAD")
	second, err := f.fetcher.DiscoverRepository(t.Context(), f.skillID, "main")
	require.NoError(t, err)

	require.NotEqual(t, first.Version, second.Version)
	require.NotEqual(t, first.CommitSHA, second.CommitSHA)
	for _, member := range second.Members {
		if member.Name == "child" {
			require.Equal(t, childTree, member.TreeSHA)
		}
	}
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
	tags, err := lister.ListRepositoryTags(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Len(t, tags, 1)
	resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "v1.0.0")
	require.NoError(t, err)
	require.Equal(t, RepositoryTag{Version: "v1.0.0", CommitSHA: resolved.CommitSHA}, tags[0])

	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	require.True(t, isGitRepository(repositoryDir))
}

func TestRepositoryTagListerObservesMovedTagAfterSharedCatalogExpires(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	lister, err := NewVCSLister(f.fetcher, 10*time.Second)
	require.NoError(t, err)
	now := time.Date(2026, 7, 22, 0, 0, 0, 0, time.UTC)
	concrete := lister.(*vcsLister)
	concrete.now = func() time.Time { return now }
	initial, err := lister.ListRepositoryTags(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Len(t, initial, 1)

	f.writeSkill(t, ".", "repo", "moved tag")
	f.commit(t, "move tag")
	movedCommit := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
	runGit(t, f.work, "tag", "-f", "v1.0.0")
	runGit(t, f.work, "push", "--force", "origin", "refs/tags/v1.0.0")
	tags, err := lister.ListRepositoryTags(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Equal(t, initial, tags, "fresh Tag view must stay stable for every consumer")
	now = now.Add(concrete.ttl + time.Nanosecond)
	tags, err = lister.ListRepositoryTags(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Equal(t, []RepositoryTag{{Version: "v1.0.0", CommitSHA: movedCommit}}, tags)

	resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "v1.0.0")
	require.NoError(t, err)
	require.Equal(t, movedCommit, resolved.CommitSHA)
	require.NotEqual(t, initial[0].CommitSHA, resolved.CommitSHA)
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
	require.Equal(t, resolved.CommitSHA, resolved.Ref)
}

func TestRepositoryBackfillListerUsesUpToTwentyVersionsWithoutMixingTagsAndCommits(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	lister, err := NewVCSLister(f.fetcher, 10*time.Second)
	require.NoError(t, err)

	versions, err := lister.ListRepositoryBackfillVersions(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Len(t, versions, 1)
	require.Equal(t, "v1.0.0", versions[0].Version)

	runGit(t, f.work, "tag", "-d", "v1.0.0")
	runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")
	for index := 0; index < 22; index++ {
		f.writeSkill(t, ".", "repo", fmt.Sprintf("backfill commit %d", index))
		f.commit(t, fmt.Sprintf("backfill commit %d", index))
	}
	runGit(t, f.work, "push", "origin", "HEAD")
	concrete := lister.(*vcsLister)
	concrete.mu.Lock()
	concrete.catalogs = map[string]tagCatalog{}
	concrete.mu.Unlock()

	versions, err = lister.ListRepositoryBackfillVersions(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Len(t, versions, maxRepositoryBackfillVersions)
	for _, version := range versions {
		require.True(t, module.IsPseudoVersion(version.Version), version.Version)
	}
	repositoryDir, err := f.fetcher.repositoryDir(f.skillID)
	require.NoError(t, err)
	wantCommits := strings.Fields(runGit(t, repositoryDir, "rev-list", "--max-count=20", "refs/remotes/origin/HEAD"))
	actualCommits := make([]string, 0, len(versions))
	for _, version := range versions {
		actualCommits = append(actualCommits, version.CommitSHA)
	}
	require.Equal(t, wantCommits, actualCommits)
}

func TestRepositoryBackfillListerKeepsOnlyHighestTwentySemanticTags(t *testing.T) {
	f := newLocalRepositoryFixture(t)
	for index := 1; index <= 25; index++ {
		tag := fmt.Sprintf("v1.0.%d", index)
		runGit(t, f.work, "tag", tag)
		runGit(t, f.work, "push", "origin", tag)
	}
	lister, err := NewVCSLister(f.fetcher, 10*time.Second)
	require.NoError(t, err)
	versions, err := lister.ListRepositoryBackfillVersions(t.Context(), f.skillID)
	require.NoError(t, err)
	require.Len(t, versions, maxRepositoryBackfillVersions)
	require.Equal(t, "v1.0.6", versions[0].Version)
	require.Equal(t, "v1.0.25", versions[len(versions)-1].Version)
}
