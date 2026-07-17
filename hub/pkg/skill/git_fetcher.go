/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Provides the skill package behavior implemented by git_fetcher.go.
 * [POS]: Serves as maintained source in the skill package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/spf13/afero"
	modmodule "golang.org/x/mod/module"
	"golang.org/x/mod/semver"
	modzip "golang.org/x/mod/zip"
)

func (g *gitFetcher) downloadWithGit(ctx context.Context, _ string, artifactDir, skillPath, revision string, resolution *Resolution) (artifactFiles, error) {
	const op errors.Op = "skill.downloadWithGit"
	skillID, err := ParseSkillID(skillPath)
	if err != nil {
		return artifactFiles{}, errors.E(op, err, errors.KindNotFound)
	}
	subdir := skillID.repositorySubdir()
	repositoryURL := skillID.RepositoryURL()
	repoDir, err := g.repositoryDir(skillID.Repository)
	if err != nil {
		return artifactFiles{}, errors.E(op, err)
	}
	if resolution == nil {
		if err := g.syncRepository(ctx, skillID); err != nil {
			return artifactFiles{}, err
		}
	} else if !isGitRepository(repoDir) {
		// FetchResolved normally follows Resolve. Recover gracefully when the
		// local mirror was removed between those operations.
		if err := g.syncRepository(ctx, skillID); err != nil {
			return artifactFiles{}, err
		}
	}

	if resolution == nil {
		resolution, err = resolveGitRevision(ctx, repoDir, skillID, revision)
		if err != nil {
			return artifactFiles{}, err
		}
	}
	hash := resolution.CommitSHA
	version := resolution.Version
	ref := resolution.Ref
	commitTime := resolution.CommitTime

	manifestFile := filepath.ToSlash(filepath.Join(subdir, "SKILL.md"))
	manifestSource, err := gitFileContent(ctx, repoDir, hash, manifestFile)
	if err != nil {
		return artifactFiles{}, errors.E(op,
			fmt.Sprintf("SKILL.md not found for Skill %q at revision %q", skillPath, revision),
			errors.S(skillPath), errors.V(revision), errors.KindNotFound)
	}
	manifest, body, err := extractManifest(manifestSource)
	if err == nil {
		err = validateManifest(manifest, body)
	}
	if err != nil {
		return artifactFiles{}, errors.E(op, err,
			errors.S(skillPath), errors.V(revision), errors.KindBadRequest)
	}

	if err := g.fs.MkdirAll(artifactDir, 0o755); err != nil {
		return artifactFiles{}, errors.E(op, err)
	}
	zipPath := filepath.Join(artifactDir, version+".zip")
	zipFile, err := g.fs.Create(zipPath)
	if err != nil {
		return artifactFiles{}, errors.E(op, err)
	}
	zipErr := modzip.CreateFromVCS(zipFile, modmodule.Version{Path: skillPath, Version: version}, repoDir, hash, subdir)
	closeErr := zipFile.Close()
	if zipErr != nil {
		return artifactFiles{}, errors.E(op, zipErr)
	}
	if closeErr != nil {
		return artifactFiles{}, errors.E(op, closeErr)
	}
	if err := recompressZipBest(g.fs, zipPath); err != nil {
		return artifactFiles{}, errors.E(op, err)
	}

	origin := storage.Origin{
		VCS:       "git",
		URL:       repositoryURL,
		Subdir:    subdir,
		Ref:       ref,
		CommitSHA: hash,
		TreeSHA:   resolution.TreeSHA,
	}
	infoBytes, err := json.Marshal(struct {
		Version string    `json:"Version"`
		Time    time.Time `json:"Time"`
		Origin  any       `json:"Origin"`
	}{version, commitTime, origin})
	if err != nil {
		return artifactFiles{}, errors.E(op, err)
	}
	infoPath := filepath.Join(artifactDir, version+".info")
	if err := afero.WriteFile(g.fs, infoPath, infoBytes, 0o644); err != nil {
		return artifactFiles{}, errors.E(op, err)
	}

	return artifactFiles{
		Path:    skillPath,
		Version: version,
		Info:    infoPath,
		Zip:     zipPath,
	}, nil
}

// Resolve resolves a mutable or descriptive revision without downloading and
// packaging the Skill contents.
func (g *gitFetcher) Resolve(ctx context.Context, skillPath, revision string) (*Resolution, error) {
	const op errors.Op = "gitFetcher.Resolve"
	skillID, err := ParseSkillID(skillPath)
	if err != nil {
		return nil, errors.E(op, err, errors.KindNotFound)
	}
	if err := g.syncRepository(ctx, skillID); err != nil {
		return nil, err
	}
	repoDir, err := g.repositoryDir(skillID.Repository)
	if err != nil {
		return nil, errors.E(op, err)
	}
	return resolveGitRevision(ctx, repoDir, skillID, revision)
}

// DiscoverRepository synchronizes and resolves a Repository once, scans the
// selected commit once, and prepares every valid Skill from that snapshot.
func (g *gitFetcher) DiscoverRepository(ctx context.Context, repositoryID, revision string) (*RepositorySnapshot, error) {
	const op errors.Op = "gitFetcher.DiscoverRepository"
	repository, err := ParseSkillID(repositoryID)
	if err != nil || repository.SkillPath != "." || repository.String() != repositoryID {
		return nil, errors.E(op, fmt.Errorf("invalid canonical Repository ID %q", repositoryID), errors.KindBadRequest)
	}
	if err := g.syncRepository(ctx, repository); err != nil {
		return nil, err
	}
	repoDir, err := g.repositoryDir(repository.Repository)
	if err != nil {
		return nil, errors.E(op, err)
	}
	resolution, err := resolveGitRevision(ctx, repoDir, repository, revision)
	if err != nil {
		return nil, err
	}
	listing, err := gitOutput(ctx, repoDir, "ls-tree", "-r", "--name-only", resolution.CommitSHA)
	if err != nil {
		return nil, errors.E(op, err)
	}
	candidates := make([]string, 0)
	for _, file := range strings.Split(listing, "\n") {
		file = strings.TrimSpace(file)
		if file == "SKILL.md" || strings.HasSuffix(file, "/SKILL.md") {
			candidates = append(candidates, file)
		}
	}
	sort.Strings(candidates)
	snapshot := &RepositorySnapshot{
		RepositoryID: repositoryID, Version: resolution.Version,
		CommitSHA: resolution.CommitSHA, CommitTime: resolution.CommitTime,
		Members: make([]RepositoryMember, 0, len(candidates)),
	}
	closeMembers := func() {
		for _, member := range snapshot.Members {
			if member.Version != nil && member.Version.Zip != nil {
				_ = member.Version.Zip.Close()
			}
		}
	}
	for _, candidate := range candidates {
		directory := filepath.ToSlash(filepath.Dir(candidate))
		memberID := repositoryID
		if directory != "." {
			memberID += skillPathSeparator + directory
		}
		memberResolution := *resolution
		memberResolution.TreeSHA, err = gitOutput(ctx, repoDir, "rev-parse", resolution.CommitSHA+":"+directory)
		if directory == "." {
			memberResolution.TreeSHA = resolution.TreeSHA
			err = nil
		}
		if err != nil {
			closeMembers()
			return nil, errors.E(op, err)
		}
		version, fetchErr := g.fetch(ctx, memberID, revision, &memberResolution)
		if fetchErr != nil {
			if errors.Kind(fetchErr) == errors.KindBadRequest || errors.Kind(fetchErr) == errors.KindNotFound {
				continue
			}
			closeMembers()
			return nil, fetchErr
		}
		snapshot.Members = append(snapshot.Members, RepositoryMember{SkillID: memberID, Version: version})
	}
	if len(snapshot.Members) == 0 {
		return nil, errors.E(op, errors.S(repositoryID), errors.V(revision), "Repository contains no installable Skills", errors.KindNotFound)
	}
	return snapshot, nil
}

type repositoryMetadata struct {
	Repository string    `json:"repository"`
	URL        string    `json:"url"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

// syncRepository creates or refreshes one persistent no-checkout repository.
// Skills in different subdirectories of the same repository share this cache.
func (g *gitFetcher) syncRepository(ctx context.Context, skillID SkillID) error {
	_, err, _ := g.syncs.Do(skillID.Repository, func() (any, error) {
		const op errors.Op = "gitFetcher.syncRepository"
		repoDir, err := g.repositoryDir(skillID.Repository)
		if err != nil {
			return nil, errors.E(op, err)
		}
		if err := os.MkdirAll(filepath.Dir(repoDir), 0o755); err != nil {
			return nil, errors.E(op, err)
		}

		cloneURL := g.cloneURL(skillID)
		if err := validateRepositoryNetworkTarget(ctx, skillID.Repository, cloneURL); err != nil {
			return nil, errors.E(op, err)
		}
		if isGitRepository(repoDir) {
			fetch := exec.CommandContext(ctx, "git", "-c", "http.followRedirects=false", "fetch", "--prune", "--tags", "origin")
			fetch.Dir = repoDir
			fetch.Env = os.Environ()
			if output, err := fetch.CombinedOutput(); err == nil {
				return nil, g.writeRepositoryMetadata(repoDir, skillID)
			} else if ctx.Err() != nil {
				return nil, errors.E(op, ctx.Err())
			} else {
				// A remote or authentication failure must not destroy a usable
				// cache. Reclone only when Git confirms local object corruption.
				fsck := exec.CommandContext(ctx, "git", "fsck", "--connectivity-only")
				fsck.Dir = repoDir
				fsck.Env = os.Environ()
				if _, fsckErr := fsck.CombinedOutput(); fsckErr == nil {
					return nil, errors.E(op, fmt.Errorf("git fetch failed: %s", strings.TrimSpace(string(output))))
				}
				if err := os.RemoveAll(repoDir); err != nil {
					return nil, errors.E(op, err)
				}
			}
		} else if _, err := os.Stat(repoDir); err == nil {
			if err := os.RemoveAll(repoDir); err != nil {
				return nil, errors.E(op, err)
			}
		}

		tmpDir, err := os.MkdirTemp(filepath.Dir(repoDir), ".clone-")
		if err != nil {
			return nil, errors.E(op, err)
		}
		defer os.RemoveAll(tmpDir)
		cloneDir := filepath.Join(tmpDir, "repository")
		clone := exec.CommandContext(ctx, "git", "-c", "http.followRedirects=false", "clone", "--filter=blob:none", "--no-checkout", cloneURL, cloneDir)
		clone.Env = os.Environ()
		if _, err := clone.CombinedOutput(); err != nil {
			return nil, errors.E(op,
				fmt.Sprintf("Skill repository %q not found", skillID.Repository),
				errors.S(skillID.String()), errors.KindNotFound)
		}
		if err := enforceRepositoryDiskLimit(cloneDir); err != nil {
			return nil, errors.E(op, err, errors.KindBadRequest)
		}
		if err := os.Rename(cloneDir, repoDir); err != nil {
			return nil, errors.E(op, err)
		}
		return nil, g.writeRepositoryMetadata(repoDir, skillID)
	})
	return err
}

func validateRepositoryNetworkTarget(ctx context.Context, repositoryID, cloneURL string) error {
	if strings.EqualFold(strings.TrimSpace(os.Getenv("SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS")), "true") {
		return nil
	}
	host := strings.SplitN(repositoryID, "/", 2)[0]
	parsed, err := url.Parse(cloneURL)
	if err != nil {
		return fmt.Errorf("invalid Repository clone URL: %w", err)
	}
	// Explicitly injected non-network transports are test/operator seams. The
	// public-host policy applies to the canonical HTTPS source transport.
	if !strings.EqualFold(parsed.Hostname(), host) {
		return nil
	}
	addresses, err := net.DefaultResolver.LookupIPAddr(ctx, host)
	if err != nil {
		return errors.E("validateRepositoryNetworkTarget", fmt.Errorf("resolve Repository host %q: %w", host, err), errors.KindNotFound)
	}
	if len(addresses) == 0 {
		return fmt.Errorf("Repository host %q has no address", host)
	}
	for _, address := range addresses {
		ip := address.IP
		if !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsUnspecified() {
			return errors.E("validateRepositoryNetworkTarget", fmt.Errorf("Repository host %q resolves to a non-public address", host), errors.KindBadRequest)
		}
	}
	return nil
}

func enforceRepositoryDiskLimit(root string) error {
	limit := int64(512 << 20)
	if configured := strings.TrimSpace(os.Getenv("SKILLSGO_REPOSITORY_MAX_BYTES")); configured != "" {
		parsed, err := strconv.ParseInt(configured, 10, 64)
		if err != nil || parsed <= 0 {
			return fmt.Errorf("invalid SKILLSGO_REPOSITORY_MAX_BYTES %q", configured)
		}
		limit = parsed
	}
	var total int64
	return filepath.WalkDir(root, func(_ string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if !entry.Type().IsRegular() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		total += info.Size()
		if total > limit {
			return fmt.Errorf("Repository exceeds configured %d-byte cache limit", limit)
		}
		return nil
	})
}

func (g *gitFetcher) writeRepositoryMetadata(repoDir string, skillID SkillID) error {
	data, err := json.MarshalIndent(repositoryMetadata{
		Repository: skillID.Repository,
		URL:        skillID.RepositoryURL(),
		UpdatedAt:  time.Now().UTC(),
	}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(repoDir, "metadata.json"), append(data, '\n'), 0o644)
}

func isGitRepository(repoDir string) bool {
	cmd := exec.Command("git", "rev-parse", "--git-dir")
	cmd.Dir = repoDir
	return cmd.Run() == nil
}

func resolveGitRevision(ctx context.Context, repoDir string, skillID SkillID, revision string) (*Resolution, error) {
	const op errors.Op = "skill.resolveGitRevision"
	requestedRevision := revision
	if revision == "latest" {
		tagOutput, err := gitOutput(ctx, repoDir, "tag", "--list")
		if err != nil {
			return nil, errors.E(op, err)
		}
		versions := make([]string, 0)
		for _, tag := range strings.Fields(tagOutput) {
			if semver.IsValid(tag) {
				versions = append(versions, tag)
			}
		}
		if selected := latestSemanticVersion(versions); selected != "" {
			revision = selected
		} else {
			defaultRef, err := gitOutput(ctx, repoDir, "symbolic-ref", "refs/remotes/origin/HEAD")
			if err != nil {
				return nil, errors.E(op, err)
			}
			revision = strings.TrimPrefix(defaultRef, "refs/remotes/origin/")
		}
	}
	resolvedRevision := revision
	if semver.IsValid(revision) && modmodule.IsPseudoVersion(revision) {
		if pseudoRevision, err := modmodule.PseudoVersionRev(revision); err == nil {
			resolvedRevision = pseudoRevision
		}
	} else if !semver.IsValid(revision) {
		// A no-checkout cache keeps its local default branch at the clone-time
		// commit. Resolve branch names through the refreshed remote-tracking ref.
		remoteRevision := "refs/remotes/origin/" + revision
		if _, err := gitOutput(ctx, repoDir, "rev-parse", "--verify", remoteRevision); err == nil {
			resolvedRevision = remoteRevision
		}
	}
	commitSHA, err := gitOutput(ctx, repoDir, "rev-parse", resolvedRevision+"^{commit}")
	if err != nil {
		return nil, errors.E(op,
			fmt.Sprintf("revision %q not found for Skill %q", revision, skillID.String()),
			errors.S(skillID.String()), errors.V(revision), errors.KindNotFound)
	}
	commitTime, err := gitCommitTime(ctx, repoDir, commitSHA)
	if err != nil {
		return nil, errors.E(op, err)
	}
	version := revision
	ref := revision
	if !semver.IsValid(version) {
		shortHash := commitSHA
		if len(shortHash) > 12 {
			shortHash = shortHash[:12]
		}
		version = modmodule.PseudoVersion("v0", "", commitTime, shortHash)
		ref = "refs/heads/" + revision
	} else if !modmodule.IsPseudoVersion(version) {
		ref = "refs/tags/" + revision
	}
	treeRevision := commitSHA + "^{tree}"
	if subdir := skillID.repositorySubdir(); subdir != "" {
		treeRevision = commitSHA + ":" + subdir
	}
	treeSHA, err := gitOutput(ctx, repoDir, "rev-parse", treeRevision)
	if err != nil {
		return nil, errors.E(op,
			fmt.Sprintf("Skill path %q not found at revision %q", skillID.SkillPath, revision),
			errors.S(skillID.String()), errors.V(revision), errors.KindNotFound)
	}
	return &Resolution{
		Requested:  requestedRevision,
		Version:    version,
		Ref:        ref,
		CommitSHA:  commitSHA,
		TreeSHA:    treeSHA,
		CommitTime: commitTime,
	}, nil
}

func latestSemanticVersion(versions []string) string {
	stable := ""
	prerelease := ""
	for _, version := range versions {
		if !semver.IsValid(version) {
			continue
		}
		if semver.Prerelease(version) == "" {
			if stable == "" || semver.Compare(version, stable) > 0 {
				stable = version
			}
		} else if prerelease == "" || semver.Compare(version, prerelease) > 0 {
			prerelease = version
		}
	}
	if stable != "" {
		return stable
	}
	return prerelease
}

func gitOutput(ctx context.Context, repoDir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = repoDir
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}
