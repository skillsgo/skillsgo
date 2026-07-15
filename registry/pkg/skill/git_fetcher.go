package skill

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"github.com/spf13/afero"
	modmodule "golang.org/x/mod/module"
	"golang.org/x/mod/semver"
	modzip "golang.org/x/mod/zip"
)

func (g *gitFetcher) downloadWithGit(ctx context.Context, _ string, artifactDir, skillPath, revision string, resolution *Resolution) (artifactFiles, error) {
	const op errors.Op = "skill.downloadWithGit"
	coordinate, err := parseGitHubSkillCoordinate(skillPath)
	if err != nil {
		return artifactFiles{}, errors.E(op, err, errors.KindNotFound)
	}
	subdir := coordinate.repositorySubdir()
	repositoryURL := coordinate.RepositoryURL()
	repoDir, err := g.repositoryDir(coordinate.Repository)
	if err != nil {
		return artifactFiles{}, errors.E(op, err)
	}
	if resolution == nil {
		if err := g.syncRepository(ctx, coordinate); err != nil {
			return artifactFiles{}, err
		}
	} else if !isGitRepository(repoDir) {
		// FetchResolved normally follows Resolve. Recover gracefully when the
		// local mirror was removed between those operations.
		if err := g.syncRepository(ctx, coordinate); err != nil {
			return artifactFiles{}, err
		}
	}

	if resolution == nil {
		resolution, err = resolveGitRevision(ctx, repoDir, coordinate, revision)
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
		err = validateManifest(manifest, body, coordinate.SkillName())
	}
	if err != nil {
		return artifactFiles{}, errors.E(op, err,
			errors.S(skillPath), errors.V(revision), errors.KindBadRequest)
	}

	if err := g.fs.MkdirAll(artifactDir, 0o755); err != nil {
		return artifactFiles{}, errors.E(op, err)
	}
	manifestPath := filepath.Join(artifactDir, "manifest.yaml")
	if err := afero.WriteFile(g.fs, manifestPath, manifest, 0o644); err != nil {
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
		Path:     skillPath,
		Version:  version,
		Info:     infoPath,
		Manifest: manifestPath,
		Zip:      zipPath,
	}, nil
}

// Resolve resolves a mutable or descriptive revision without downloading and
// packaging the Skill contents.
func (g *gitFetcher) Resolve(ctx context.Context, skillPath, revision string) (*Resolution, error) {
	const op errors.Op = "gitFetcher.Resolve"
	coordinate, err := parseGitHubSkillCoordinate(skillPath)
	if err != nil {
		return nil, errors.E(op, err, errors.KindNotFound)
	}
	if err := g.syncRepository(ctx, coordinate); err != nil {
		return nil, err
	}
	repoDir, err := g.repositoryDir(coordinate.Repository)
	if err != nil {
		return nil, errors.E(op, err)
	}
	return resolveGitRevision(ctx, repoDir, coordinate, revision)
}

type repositoryMetadata struct {
	Repository string    `json:"repository"`
	URL        string    `json:"url"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

// syncRepository creates or refreshes one persistent no-checkout repository.
// Skills in different subdirectories of the same repository share this cache.
func (g *gitFetcher) syncRepository(ctx context.Context, coordinate SkillCoordinate) error {
	_, err, _ := g.syncs.Do(coordinate.Repository, func() (any, error) {
		const op errors.Op = "gitFetcher.syncRepository"
		repoDir, err := g.repositoryDir(coordinate.Repository)
		if err != nil {
			return nil, errors.E(op, err)
		}
		if err := os.MkdirAll(filepath.Dir(repoDir), 0o755); err != nil {
			return nil, errors.E(op, err)
		}

		if isGitRepository(repoDir) {
			fetch := exec.CommandContext(ctx, "git", "fetch", "--prune", "--tags", "origin")
			fetch.Dir = repoDir
			fetch.Env = os.Environ()
			if output, err := fetch.CombinedOutput(); err == nil {
				return nil, g.writeRepositoryMetadata(repoDir, coordinate)
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
		clone := exec.CommandContext(ctx, "git", "clone", "--filter=blob:none", "--no-checkout", g.cloneURL(coordinate), cloneDir)
		clone.Env = os.Environ()
		if _, err := clone.CombinedOutput(); err != nil {
			return nil, errors.E(op,
				fmt.Sprintf("Skill repository %q not found", coordinate.Repository),
				errors.S(coordinate.String()), errors.KindNotFound)
		}
		if err := os.Rename(cloneDir, repoDir); err != nil {
			return nil, errors.E(op, err)
		}
		return nil, g.writeRepositoryMetadata(repoDir, coordinate)
	})
	return err
}

func (g *gitFetcher) writeRepositoryMetadata(repoDir string, coordinate SkillCoordinate) error {
	data, err := json.MarshalIndent(repositoryMetadata{
		Repository: coordinate.Repository,
		URL:        coordinate.RepositoryURL(),
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

func resolveGitRevision(ctx context.Context, repoDir string, coordinate SkillCoordinate, revision string) (*Resolution, error) {
	const op errors.Op = "skill.resolveGitRevision"
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
			fmt.Sprintf("revision %q not found for Skill %q", revision, coordinate.String()),
			errors.S(coordinate.String()), errors.V(revision), errors.KindNotFound)
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
	if subdir := coordinate.repositorySubdir(); subdir != "" {
		treeRevision = commitSHA + ":" + subdir
	}
	treeSHA, err := gitOutput(ctx, repoDir, "rev-parse", treeRevision)
	if err != nil {
		return nil, errors.E(op,
			fmt.Sprintf("Skill path %q not found at revision %q", coordinate.SkillPath, revision),
			errors.S(coordinate.String()), errors.V(revision), errors.KindNotFound)
	}
	return &Resolution{
		Requested:  revision,
		Version:    version,
		Ref:        ref,
		CommitSHA:  commitSHA,
		TreeSHA:    treeSHA,
		CommitTime: commitTime,
	}, nil
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
