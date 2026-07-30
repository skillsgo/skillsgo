/*
 * [INPUT]: Depends on canonical Skill IDs, Git commit and ancestor-tag inspection, semantic and pseudo-version helpers, the leased lifecycle-managed repository cache, credential-free controlled Git transport, manifest validation, and SkillsGo artifact assembly.
 * [OUTPUT]: Provides bounded public-only Git synchronization, throttled cache maintenance, one-sync multi-revision discovery, Go-compatible ancestor-based immutable revision resolution with canonical refs, repository-owned Skill discovery with complete SKILL.md bytes, precise Source Failure Codes, and source-identity metadata.
 * [POS]: Serves as the Git source resolver and Repository snapshot coordinator in the Hub Skill source module.
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
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
	modmodule "golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

// Resolve resolves a mutable or descriptive revision without downloading and
// packaging the Skill contents.
func (g *gitFetcher) Resolve(ctx context.Context, skillPath, revision string) (*Resolution, error) {
	const op errors.Op = "gitFetcher.Resolve"
	skillID, err := ParsePackagePath(skillPath)
	if err != nil {
		return nil, errors.E(op, err, errors.KindNotFound)
	}
	release, err := g.acquireRepository(skillID.String())
	if err != nil {
		return nil, errors.E(op, err)
	}
	defer release()
	if err := g.syncRepository(ctx, skillID); err != nil {
		return nil, err
	}
	repoDir, err := g.repositoryDir(skillID.String())
	if err != nil {
		return nil, errors.E(op, err)
	}
	return resolveGitRevision(ctx, repoDir, skillID, revision)
}

// DiscoverRepository synchronizes and resolves a Repository once, scans the
// selected commit once, and prepares every valid Skill from that snapshot.
func (g *gitFetcher) DiscoverRepository(ctx context.Context, packagePath, revision string) (*RepositorySnapshot, error) {
	var snapshot *RepositorySnapshot
	var discoveryErr error
	err := g.VisitRepositorySnapshots(ctx, packagePath, []string{revision}, func(_ string, candidate *RepositorySnapshot, err error) error {
		snapshot, discoveryErr = candidate, err
		return nil
	})
	if err != nil {
		return nil, err
	}
	return snapshot, discoveryErr
}

// VisitRepositorySnapshots synchronizes and leases one source Repository once,
// then visits revisions in request order without repeating remote negotiation.
func (g *gitFetcher) VisitRepositorySnapshots(ctx context.Context, packagePath string, revisions []string, visit func(string, *RepositorySnapshot, error) error) error {
	const op errors.Op = "gitFetcher.VisitRepositorySnapshots"
	repository, err := ParsePackagePath(packagePath)
	if err != nil || repository.String() != packagePath {
		return errors.E(op, fmt.Errorf("invalid canonical Repository ID %q", packagePath), errors.KindBadRequest)
	}
	if visit == nil {
		return errors.E(op, fmt.Errorf("Repository snapshot visitor is required"), errors.KindBadRequest)
	}
	release, err := g.acquireRepository(repository.String())
	if err != nil {
		return errors.E(op, err)
	}
	defer release()
	repoDir, err := g.repositoryDir(repository.String())
	if err != nil {
		return errors.E(op, err)
	}
	if err := g.syncRepository(ctx, repository); err != nil {
		return err
	}
	for _, revision := range revisions {
		snapshot, discoveryErr := g.discoverRepositorySnapshot(ctx, packagePath, revision, repository, repoDir)
		if err := visit(revision, snapshot, discoveryErr); err != nil {
			return err
		}
	}
	return nil
}

func (g *gitFetcher) discoverRepositorySnapshot(ctx context.Context, packagePath, revision string, repository PackagePath, repoDir string) (*RepositorySnapshot, error) {
	const op errors.Op = "gitFetcher.DiscoverRepository"
	resolution, err := resolveGitRevision(ctx, repoDir, repository, revision)
	if err != nil {
		return nil, withSourceFailure(SourceFailureRevisionResolution, err)
	}
	listing, err := gitOutput(ctx, repoDir, "ls-tree", "-r", "--name-only", resolution.CommitSHA)
	if err != nil {
		return nil, withSourceFailure(SourceFailureTreeReadFailed, errors.E(op, err))
	}
	candidates := make([]string, 0)
	for _, file := range strings.Split(listing, "\n") {
		file = strings.TrimSpace(file)
		if isRepositoryOwnedSkillCandidate(file) {
			candidates = append(candidates, file)
		}
	}
	sort.Strings(candidates)
	if len(candidates) == 0 {
		return nil, withSourceFailure(SourceFailureNoSkills, errors.E(op, errors.S(packagePath), errors.V(revision), "Repository contains no installable Skills", errors.KindNotFound))
	}
	snapshot := &RepositorySnapshot{
		PackagePath: packagePath, Version: resolution.Version,
		Ref: resolution.Ref, CommitSHA: resolution.CommitSHA, TreeSHA: resolution.TreeSHA, CommitTime: resolution.CommitTime,
		Members: make([]RepositoryMember, 0, len(candidates)),
	}
	entries, sum, err := createRepositoryArtifact(ctx, packagePath, resolution.Version, repoDir, resolution.CommitSHA)
	if err != nil {
		return nil, withSourceFailure(SourceFailureArtifactBuild, errors.E(op, err))
	}
	snapshot.Entries = entries
	snapshot.Sum = sum
	for _, candidate := range candidates {
		directory := filepath.ToSlash(filepath.Dir(candidate))
		memberResolution := *resolution
		memberResolution.TreeSHA, err = gitOutput(ctx, repoDir, "rev-parse", resolution.CommitSHA+":"+directory)
		if directory == "." {
			memberResolution.TreeSHA = resolution.TreeSHA
			err = nil
		}
		if err != nil {
			return nil, withSourceFailure(SourceFailureTreeReadFailed, errors.E(op, err))
		}
		manifestSource, fetchErr := gitFileContent(ctx, repoDir, resolution.CommitSHA, candidate)
		if fetchErr != nil {
			return nil, withSourceFailure(SourceFailureTreeReadFailed, errors.E(op, fetchErr))
		}
		manifestBytes, body, manifestErr := extractManifest(manifestSource)
		if manifestErr == nil {
			manifestErr = validateManifest(manifestBytes, body)
		}
		if manifestErr != nil {
			if errors.Kind(manifestErr) == errors.KindBadRequest {
				continue
			}
			continue
		}
		manifest, manifestErr := protocolmanifest.ValidatePublished(manifestSource)
		if manifestErr != nil {
			continue
		}
		snapshot.Members = append(snapshot.Members, RepositoryMember{Name: manifest.Name, Path: directory, TreeSHA: memberResolution.TreeSHA, Content: append([]byte(nil), manifestSource...), Manifest: manifest})
	}
	if len(snapshot.Members) == 0 {
		return nil, withSourceFailure(SourceFailureInvalidManifest, errors.E(op, errors.S(packagePath), errors.V(revision), "Repository contains Skill candidates but none has a valid manifest", errors.KindBadRequest))
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
func (g *gitFetcher) syncRepository(ctx context.Context, skillID PackagePath) error {
	_, err, _ := g.syncs.Do(skillID.String(), func() (any, error) {
		const op errors.Op = "gitFetcher.syncRepository"
		started := time.Now()
		entry := log.EntryFromContext(ctx).WithFields(map[string]any{
			"dependency":    "git_source",
			"repository_id": skillID.String(),
			"source_host":   strings.SplitN(skillID.String(), "/", 2)[0],
		})
		entry.Debugf("repository git synchronization started")
		if err := g.maybeCleanupRepositoryCache(); err != nil {
			entry.WithFields(map[string]any{"error": err.Error()}).Warnf("repository cache cleanup failed")
		}
		repoDir, err := g.repositoryDir(skillID.String())
		if err != nil {
			return nil, errors.E(op, err)
		}
		if err := os.MkdirAll(filepath.Dir(repoDir), 0o755); err != nil {
			return nil, errors.E(op, err)
		}

		cloneURL := g.cloneURL(skillID)
		if err := validateRepositoryNetworkTarget(ctx, skillID.String(), cloneURL); err != nil {
			entry.WithFields(map[string]any{
				"duration_ms": time.Since(started).Milliseconds(),
				"error":       err.Error(),
				"git_phase":   "network_validation",
			}).Warnf("repository git synchronization failed")
			return nil, errors.E(op, err)
		}
		if isGitRepository(repoDir) {
			fetchStarted := time.Now()
			if output, err := g.runGitTransport(ctx, repoDir, "-c", "http.followRedirects=false", "fetch", "--prune", "origin",
				"+refs/heads/*:refs/remotes/origin/*", "+refs/tags/*:refs/skillsgo/upstream-tags/*"); err == nil {
				entry.WithFields(map[string]any{
					"duration_ms": time.Since(fetchStarted).Milliseconds(),
					"git_phase":   "fetch",
					"result":      "success",
				}).Debugf("repository git transport completed")
				if err := enforceRepositoryDiskLimit(repoDir); err != nil {
					return nil, withSourceFailure(SourceFailureRepositoryTooLarge, errors.E(op, err, errors.KindBadRequest))
				}
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
				fsck.Env = controlledGitEnvironment(os.Environ())
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
		if output, err := g.runGitTransport(ctx, "", "-c", "http.followRedirects=false", "clone", "--filter=blob:none", "--no-checkout", "--no-tags", cloneURL, cloneDir); err != nil {
			if ctx.Err() != nil {
				return nil, errors.E(op, ctx.Err())
			}
			diagnostic := gitTransportDiagnostic(output)
			entry.WithFields(map[string]any{
				"duration_ms": time.Since(cloneStarted).Milliseconds(),
				"error":       diagnostic,
				"git_phase":   "clone",
				"result":      "failure",
			}).Warnf("repository git transport failed")
			return nil, errors.E(op,
				fmt.Sprintf("Skill repository %q not found", skillID.String()),
				errors.S(skillID.String()), errors.KindNotFound)
		}
		entry.WithFields(map[string]any{
			"duration_ms": time.Since(cloneStarted).Milliseconds(),
			"git_phase":   "clone",
			"result":      "success",
		}).Debugf("repository git transport completed")
		if output, err := g.runGitTransport(ctx, cloneDir, "-c", "http.followRedirects=false", "fetch", "--prune", "origin", "+refs/tags/*:refs/skillsgo/upstream-tags/*"); err != nil {
			if ctx.Err() != nil {
				return nil, errors.E(op, ctx.Err())
			}
			return nil, errors.E(op, fmt.Errorf("fetch Repository Tag catalog: %s", gitTransportDiagnostic(output)))
		}
		if err := enforceRepositoryDiskLimit(cloneDir); err != nil {
			return nil, withSourceFailure(SourceFailureRepositoryTooLarge, errors.E(op, err, errors.KindBadRequest))
		}
		if err := os.Rename(cloneDir, repoDir); err != nil {
			return nil, errors.E(op, err)
		}
		return nil, g.writeRepositoryMetadata(repoDir, skillID)
	})
	return err
}

func (g *gitFetcher) runGitTransport(ctx context.Context, dir string, args ...string) ([]byte, error) {
	output, err := g.runGitCommand(ctx, dir, args, controlledGitEnvironment(os.Environ()))
	if err != nil && ctx.Err() != nil {
		return output, ctx.Err()
	}
	return output, err
}

func runGitCommand(ctx context.Context, dir string, args []string, environment []string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	cmd.Env = environment
	return cmd.CombinedOutput()
}

func controlledGitEnvironment(environment []string) []string {
	blocked := map[string]bool{
		"GIT_ALLOW_PROTOCOL": true, "GIT_ASKPASS": true, "GIT_CONFIG_COUNT": true,
		"GIT_CONFIG_GLOBAL": true, "GIT_CONFIG_NOSYSTEM": true,
		"GIT_PROTOCOL_FROM_USER": true, "GIT_SSH": true, "GIT_SSH_COMMAND": true,
		"GIT_TERMINAL_PROMPT": true, "GCM_INTERACTIVE": true, "SSH_ASKPASS": true,
	}
	filtered := make([]string, 0, len(environment)+8)
	for _, entry := range environment {
		key, _, _ := strings.Cut(entry, "=")
		if blocked[key] || strings.HasPrefix(key, "GIT_CONFIG_KEY_") || strings.HasPrefix(key, "GIT_CONFIG_VALUE_") {
			continue
		}
		filtered = append(filtered, entry)
	}
	return append(filtered,
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_CONFIG_GLOBAL="+os.DevNull,
		"GIT_TERMINAL_PROMPT=0",
		"GCM_INTERACTIVE=Never",
		"GIT_ASKPASS=/bin/false",
		"SSH_ASKPASS=/bin/false",
		"GIT_PROTOCOL_FROM_USER=0",
		"GIT_ALLOW_PROTOCOL=https:file",
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

func validateRepositoryNetworkTarget(ctx context.Context, packagePath, cloneURL string) error {
	if strings.EqualFold(strings.TrimSpace(os.Getenv("SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS")), "true") {
		return nil
	}
	host := strings.SplitN(packagePath, "/", 2)[0]
	parsed, err := url.Parse(cloneURL)
	if err != nil {
		return fmt.Errorf("invalid Repository clone URL: %w", err)
	}
	// Explicitly injected non-network transports are test/operator seams. The
	// public-host policy applies to the canonical HTTPS source transport.
	if !strings.EqualFold(parsed.Hostname(), host) {
		return nil
	}
	if parsed.Scheme != "https" || parsed.User != nil || parsed.Port() != "" {
		return fmt.Errorf("Repository clone URL must use credential-free HTTPS on the canonical host")
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

func (g *gitFetcher) writeRepositoryMetadata(repoDir string, skillID PackagePath) error {
	data, err := json.MarshalIndent(repositoryMetadata{
		Repository: skillID.String(),
		URL:        skillID.SourceURL(),
		UpdatedAt:  g.now().UTC(),
	}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(repoDir, "metadata.json"), append(data, '\n'), 0o644)
}

func isGitRepository(repoDir string) bool {
	cmd := exec.Command("git", "rev-parse", "--git-dir")
	cmd.Dir = repoDir
	cmd.Env = controlledGitEnvironment(os.Environ())
	return cmd.Run() == nil
}

func resolveGitRevision(ctx context.Context, repoDir string, skillID PackagePath, revision string) (*Resolution, error) {
	const op errors.Op = "skill.resolveGitRevision"
	requestedRevision := revision
	query, err := protocolversion.ParseQuery(revision)
	if err != nil {
		return nil, errors.E(op, err, errors.KindBadRequest)
	}
	switch query.Kind {
	case protocolversion.QueryLatest, protocolversion.QueryPrefix, protocolversion.QueryCompare:
		tags, err := canonicalRepositoryTags(ctx, repoDir)
		if err != nil {
			return nil, errors.E(op, err)
		}
		versions := make([]string, 0, len(tags))
		for _, tag := range tags {
			versions = append(versions, tag.Version)
		}
		if selected := selectSemanticVersion(versions, query); selected != "" {
			revision = selected
		} else if query.Kind == protocolversion.QueryLatest {
			defaultRef, err := gitOutput(ctx, repoDir, "symbolic-ref", "refs/remotes/origin/HEAD")
			if err != nil {
				return nil, errors.E(op, err)
			}
			revision = strings.TrimPrefix(defaultRef, "refs/remotes/origin/")
		} else {
			return nil, errors.E(op, "Package has no version matching Query", errors.S(skillID.String()), errors.V(requestedRevision), errors.KindNotFound)
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
		return nil, withSourceFailure(SourceFailureRevisionNotFound, errors.E(op,
			fmt.Sprintf("revision %q not found for Skill %q", revision, skillID.String()),
			errors.S(skillID.String()), errors.V(revision), errors.KindNotFound))
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
		tags, tagErr := canonicalRepositoryTags(ctx, repoDir)
		if tagErr != nil {
			return nil, errors.E(op, tagErr)
		}
		pointing := make([]string, 0)
		for _, tag := range tags {
			if tag.CommitSHA == commitSHA {
				pointing = append(pointing, tag.Version)
			}
		}
		if taggedVersion := highestSemanticVersion(pointing); taggedVersion != "" {
			version = taggedVersion
			ref = "refs/tags/" + taggedVersion
		} else {
			version, err = pseudoVersionForCommit(ctx, repoDir, commitSHA, commitTime)
			if err != nil {
				return nil, errors.E(op, err)
			}
			// Different movable queries can resolve to the same immutable
			// pseudo-version. Persist its commit identity instead of the input
			// branch name so repeated publication is byte-for-byte idempotent.
			ref = commitSHA
		}
	} else if !modmodule.IsPseudoVersion(version) {
		ref = "refs/tags/" + revision
	}
	treeSHA, err := gitOutput(ctx, repoDir, "rev-parse", commitSHA+"^{tree}")
	if err != nil {
		return nil, withSourceFailure(SourceFailureTreeReadFailed, errors.E(op, err, errors.S(skillID.String()), errors.V(revision), errors.KindNotFound))
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
	ancestor.Env = controlledGitEnvironment(os.Environ())
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

func selectSemanticVersion(versions []string, query protocolversion.Query) string {
	if query.Kind == protocolversion.QueryLatest {
		return latestSemanticVersion(versions)
	}
	matches := make([]string, 0, len(versions))
	preferLower := false
	for _, version := range versions {
		if !isCanonicalSemanticVersion(version) {
			continue
		}
		matched := false
		switch query.Kind {
		case protocolversion.QueryPrefix:
			floor := query.Value + ".0"
			if strings.Count(query.Value, ".") == 0 {
				floor += ".0"
			}
			matched = strings.HasPrefix(version, query.Value+".") && semver.Compare(version, floor) >= 0
		case protocolversion.QueryCompare:
			operator, target := splitVersionComparison(query.Value)
			comparison := semver.Compare(version, target)
			switch operator {
			case "<":
				matched = comparison < 0
			case "<=":
				matched = comparison <= 0
			case ">":
				matched, preferLower = comparison > 0, true
			case ">=":
				matched, preferLower = comparison >= 0, true
			}
		}
		if matched {
			matches = append(matches, version)
		}
	}
	stable := matches[:0]
	for _, version := range matches {
		if semver.Prerelease(version) == "" {
			stable = append(stable, version)
		}
	}
	if len(stable) > 0 {
		matches = stable
	}
	selected := ""
	for _, version := range matches {
		if selected == "" || (preferLower && semver.Compare(version, selected) < 0) || (!preferLower && semver.Compare(version, selected) > 0) {
			selected = version
		}
	}
	return selected
}

func splitVersionComparison(query string) (string, string) {
	for _, operator := range []string{"<=", ">=", "<", ">"} {
		if strings.HasPrefix(query, operator) {
			return operator, strings.TrimPrefix(query, operator)
		}
	}
	return "", query
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
	tags, err := canonicalRepositoryTags(ctx, repoDir)
	if err != nil {
		return "", err
	}
	ancestors := make([]string, 0, len(tags))
	for _, tag := range tags {
		if tag.CommitSHA == commitSHA {
			continue
		}
		ancestor := exec.CommandContext(ctx, "git", "merge-base", "--is-ancestor", tag.CommitSHA, commitSHA)
		ancestor.Dir = repoDir
		ancestor.Env = controlledGitEnvironment(os.Environ())
		if ancestor.Run() == nil {
			ancestors = append(ancestors, tag.Version)
		}
	}
	base := highestSemanticVersion(ancestors)
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
	cmd.Env = controlledGitEnvironment(os.Environ())
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}
