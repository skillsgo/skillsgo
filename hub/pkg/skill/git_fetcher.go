/*
 * [INPUT]: Depends on canonical Skill IDs, Git commit and ancestor-tag inspection, semantic and pseudo-version helpers, the shared repository cache, optional GitHub-token failover, manifest validation, and SkillsGo artifact assembly.
 * [OUTPUT]: Provides bounded shared Git synchronization with per-process GitHub credential failover, Go-compatible ancestor-based immutable revision resolution, repository-owned Skill discovery, and source-identity metadata.
 * [POS]: Serves as the Git source resolver and Repository snapshot coordinator in the Hub Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"encoding/base64"
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
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
	"github.com/spf13/afero"
	modmodule "golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

func (g *gitFetcher) downloadWithGit(ctx context.Context, _ string, artifactDir, skillPath, revision string, resolution *Resolution) (artifactFiles, error) {
	const op errors.Op = "skill.downloadWithGit"
	skillID, err := ParseSkillID(skillPath)
	if err != nil {
		return artifactFiles{}, errors.E(op, err, errors.KindNotFound)
	}
	subdir := skillID.RepositorySubdir()
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
	if err := createSkillZipFromVCS(ctx, g.fs, zipPath, skillPath, version, repoDir, hash, subdir); err != nil {
		return artifactFiles{}, errors.E(op, err)
	}

	infoBytes, err := json.Marshal(struct {
		Version   string    `json:"Version"`
		Time      time.Time `json:"Time"`
		Ref       string    `json:"Ref"`
		CommitSHA string    `json:"CommitSHA"`
		TreeSHA   string    `json:"TreeSHA"`
	}{version, commitTime, ref, hash, resolution.TreeSHA})
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
		if isRepositoryOwnedSkillCandidate(file) {
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

func isRepositoryOwnedSkillCandidate(file string) bool {
	if file == "SKILL.md" {
		return true
	}
	if !strings.HasSuffix(file, "/SKILL.md") {
		return false
	}
	for _, segment := range strings.Split(strings.TrimSuffix(file, "/SKILL.md"), "/") {
		if strings.HasPrefix(segment, ".") {
			return false
		}
	}
	return true
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
		started := time.Now()
		entry := log.EntryFromContext(ctx).WithFields(map[string]any{
			"dependency":    "git_source",
			"repository_id": skillID.Repository,
			"source_host":   strings.SplitN(skillID.Repository, "/", 2)[0],
		})
		entry.Debugf("repository git synchronization started")
		repoDir, err := g.repositoryDir(skillID.Repository)
		if err != nil {
			return nil, errors.E(op, err)
		}
		if err := os.MkdirAll(filepath.Dir(repoDir), 0o755); err != nil {
			return nil, errors.E(op, err)
		}

		cloneURL := g.cloneURL(skillID)
		if err := validateRepositoryNetworkTarget(ctx, skillID.Repository, cloneURL); err != nil {
			entry.WithFields(map[string]any{
				"duration_ms": time.Since(started).Milliseconds(),
				"error":       err.Error(),
				"git_phase":   "network_validation",
			}).Warnf("repository git synchronization failed")
			return nil, errors.E(op, err)
		}
		githubSource := strings.EqualFold(strings.SplitN(skillID.Repository, "/", 2)[0], "github.com")
		if isGitRepository(repoDir) {
			fetchStarted := time.Now()
			if output, err := g.runGitTransport(ctx, repoDir, githubSource, "-c", "http.followRedirects=false", "fetch", "--prune", "origin",
				"+refs/heads/*:refs/remotes/origin/*", "+refs/tags/*:refs/skillsgo/upstream-tags/*"); err == nil {
				entry.WithFields(map[string]any{
					"duration_ms": time.Since(fetchStarted).Milliseconds(),
					"git_phase":   "fetch",
					"result":      "success",
				}).Debugf("repository git transport completed")
				return nil, g.writeRepositoryMetadata(repoDir, skillID)
			} else if ctx.Err() != nil {
				entry.WithFields(map[string]any{
					"duration_ms": time.Since(fetchStarted).Milliseconds(),
					"error":       ctx.Err().Error(),
					"git_phase":   "fetch",
					"result":      "canceled",
				}).Warnf("repository git transport failed")
				return nil, errors.E(op, ctx.Err())
			} else {
				// A remote or authentication failure must not destroy a usable
				// cache. Reclone only when Git confirms local object corruption.
				fsck := exec.CommandContext(ctx, "git", "fsck", "--connectivity-only")
				fsck.Dir = repoDir
				fsck.Env = os.Environ()
				if _, fsckErr := fsck.CombinedOutput(); fsckErr == nil {
					diagnostic := gitTransportDiagnostic(output)
					entry.WithFields(map[string]any{
						"duration_ms":             time.Since(fetchStarted).Milliseconds(),
						"error":                   diagnostic,
						"git_phase":               "fetch",
						"local_repository_usable": true,
						"result":                  "failure",
					}).Warnf("repository git transport failed")
					return nil, errors.E(op, fmt.Errorf("git fetch failed: %s", diagnostic))
				}
				entry.WithFields(map[string]any{
					"duration_ms":             time.Since(fetchStarted).Milliseconds(),
					"error":                   gitTransportDiagnostic(output),
					"git_phase":               "fetch",
					"local_repository_usable": false,
					"result":                  "failure",
				}).Warnf("repository git transport failed")
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
		cloneStarted := time.Now()
		if output, err := g.runGitTransport(ctx, "", githubSource, "-c", "http.followRedirects=false", "clone", "--filter=blob:none", "--no-checkout", cloneURL, cloneDir); err != nil {
			diagnostic := gitTransportDiagnostic(output)
			entry.WithFields(map[string]any{
				"duration_ms": time.Since(cloneStarted).Milliseconds(),
				"error":       diagnostic,
				"git_phase":   "clone",
				"result":      "failure",
			}).Warnf("repository git transport failed")
			return nil, errors.E(op,
				fmt.Sprintf("Skill repository %q not found", skillID.Repository),
				errors.S(skillID.String()), errors.KindNotFound)
		}
		entry.WithFields(map[string]any{
			"duration_ms": time.Since(cloneStarted).Milliseconds(),
			"git_phase":   "clone",
			"result":      "success",
		}).Debugf("repository git transport completed")
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

func (g *gitFetcher) runGitTransport(ctx context.Context, dir string, githubSource bool, args ...string) ([]byte, error) {
	attempts := 1
	if githubSource && len(g.githubTokens) > 0 {
		attempts = len(g.githubTokens)
	}
	start := g.activeToken.Load()
	var output []byte
	var err error
	for offset := range attempts {
		environment := os.Environ()
		if githubSource && len(g.githubTokens) > 0 {
			index := (start + uint64(offset)) % uint64(len(g.githubTokens))
			environment = gitHubTokenEnvironment(environment, g.githubTokens[index])
		}
		output, err = g.runGitCommand(ctx, dir, args, environment)
		if err == nil {
			if offset > 0 {
				g.activeToken.CompareAndSwap(start, start+uint64(offset))
			}
			return output, nil
		}
		if ctx.Err() != nil {
			return output, ctx.Err()
		}
	}
	return output, err
}

func runGitCommand(ctx context.Context, dir string, args []string, environment []string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	cmd.Env = environment
	return cmd.CombinedOutput()
}

func gitHubTokenEnvironment(environment []string, token string) []string {
	filtered := make([]string, 0, len(environment)+3)
	for _, entry := range environment {
		if strings.HasPrefix(entry, "GIT_CONFIG_COUNT=") || strings.HasPrefix(entry, "GIT_CONFIG_KEY_0=") || strings.HasPrefix(entry, "GIT_CONFIG_VALUE_0=") {
			continue
		}
		filtered = append(filtered, entry)
	}
	credential := base64.StdEncoding.EncodeToString([]byte("x-access-token:" + token))
	return append(filtered,
		"GIT_CONFIG_COUNT=1",
		"GIT_CONFIG_KEY_0=http.https://github.com/.extraHeader",
		"GIT_CONFIG_VALUE_0=Authorization: Basic "+credential,
	)
}

func gitTransportDiagnostic(output []byte) string {
	const maxBytes = 4096
	diagnostic := strings.TrimSpace(string(output))
	if len(diagnostic) <= maxBytes {
		return diagnostic
	}
	return diagnostic[:maxBytes] + "…"
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
			if isCanonicalSemanticVersion(tag) {
				versions = append(versions, tag)
			}
		}
		upstreamOutput, upstreamErr := gitOutput(ctx, repoDir, "for-each-ref", "--format=%(refname:strip=3)", "refs/skillsgo/upstream-tags")
		if upstreamErr == nil {
			for _, tag := range strings.Fields(upstreamOutput) {
				if isCanonicalSemanticVersion(tag) {
					versions = append(versions, tag)
				}
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
	} else if isCanonicalSemanticVersion(revision) {
		resolvedRevision = semanticTagRef(ctx, repoDir, revision)
	} else {
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
	if modmodule.IsPseudoVersion(revision) {
		if err := validatePseudoVersion(ctx, repoDir, revision, commitSHA, commitTime); err != nil {
			return nil, errors.E(op, err, errors.S(skillID.String()), errors.V(revision), errors.KindBadRequest)
		}
	}
	version := revision
	ref := revision
	if !isCanonicalSemanticVersion(version) {
		tagOutput, tagErr := gitOutput(ctx, repoDir, "tag", "--points-at", commitSHA)
		if tagErr != nil {
			return nil, errors.E(op, tagErr)
		}
		if taggedVersion := highestSemanticVersion(strings.Fields(tagOutput)); taggedVersion != "" {
			version = taggedVersion
			ref = "refs/tags/" + taggedVersion
		} else {
			version, err = pseudoVersionForCommit(ctx, repoDir, commitSHA, commitTime)
			if err != nil {
				return nil, errors.E(op, err)
			}
			if resolvedRevision != "refs/remotes/origin/"+revision {
				ref = commitSHA
			} else {
				ref = "refs/heads/" + revision
			}
		}
	} else if !modmodule.IsPseudoVersion(version) {
		ref = "refs/tags/" + revision
	}
	treeRevision := commitSHA + "^{tree}"
	if subdir := skillID.RepositorySubdir(); subdir != "" {
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

func validatePseudoVersion(ctx context.Context, repoDir, version, commitSHA string, commitTime time.Time) error {
	revision, err := modmodule.PseudoVersionRev(version)
	if err != nil {
		return fmt.Errorf("invalid pseudo-version %q: %w", version, err)
	}
	expectedRevision := commitSHA
	if len(expectedRevision) > 12 {
		expectedRevision = expectedRevision[:12]
	}
	if revision != expectedRevision {
		return fmt.Errorf("invalid pseudo-version %q: commit suffix must be %s", version, expectedRevision)
	}

	versionTime, err := modmodule.PseudoVersionTime(version)
	if err != nil {
		return fmt.Errorf("invalid pseudo-version %q: %w", version, err)
	}
	if !versionTime.Equal(commitTime.Truncate(time.Second)) {
		return fmt.Errorf("invalid pseudo-version %q: timestamp must be %s", version, commitTime.UTC().Format(modmodule.PseudoVersionTimestampFormat))
	}

	base, err := modmodule.PseudoVersionBase(version)
	if err != nil {
		return fmt.Errorf("invalid pseudo-version %q: %w", version, err)
	}
	if base == "" {
		if semver.Major(version) != "v0" {
			return fmt.Errorf("invalid pseudo-version %q: a version without a preceding Tag must use major v0", version)
		}
		return nil
	}

	baseCommit, err := gitOutput(ctx, repoDir, "rev-parse", semanticTagRef(ctx, repoDir, base)+"^{commit}")
	if err != nil {
		return fmt.Errorf("invalid pseudo-version %q: preceding Tag %s was not found", version, base)
	}
	if baseCommit == commitSHA {
		return fmt.Errorf("invalid pseudo-version %q: commit already has canonical Tag %s", version, base)
	}
	ancestor := exec.CommandContext(ctx, "git", "merge-base", "--is-ancestor", baseCommit, commitSHA)
	ancestor.Dir = repoDir
	ancestor.Env = os.Environ()
	if err := ancestor.Run(); err != nil {
		return fmt.Errorf("invalid pseudo-version %q: commit is not a descendant of preceding Tag %s", version, base)
	}
	return nil
}

func semanticTagRef(ctx context.Context, repoDir, version string) string {
	upstream := "refs/skillsgo/upstream-tags/" + version
	if _, err := gitOutput(ctx, repoDir, "rev-parse", "--verify", upstream); err == nil {
		return upstream
	}
	return "refs/tags/" + version
}

func latestSemanticVersion(versions []string) string {
	return protocolversion.LatestCanonicalPublished(versions)
}

func highestSemanticVersion(versions []string) string {
	highest := ""
	for _, version := range versions {
		if isCanonicalSemanticVersion(version) && (highest == "" || semver.Compare(version, highest) > 0) {
			highest = version
		}
	}
	return highest
}

func isCanonicalSemanticVersion(version string) bool {
	return semver.IsValid(version) && semver.Canonical(version) == version
}

func pseudoVersionForCommit(ctx context.Context, repoDir, commitSHA string, commitTime time.Time) (string, error) {
	tagOutput, err := gitOutput(ctx, repoDir, "tag", "--merged", commitSHA)
	if err != nil {
		return "", err
	}
	base := highestSemanticVersion(strings.Fields(tagOutput))
	major := semver.Major(base)
	if major == "" {
		major = "v0"
	}
	shortHash := commitSHA
	if len(shortHash) > 12 {
		shortHash = shortHash[:12]
	}
	return modmodule.PseudoVersion(major, base, commitTime, shortHash), nil
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
