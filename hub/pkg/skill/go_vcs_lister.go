/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Provides the skill package behavior implemented by go_vcs_lister.go.
 * [POS]: Serves as maintained source in the skill package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	modmodule "golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

type vcsLister struct {
	repositories *gitFetcher
	timeout      time.Duration
}

// NewVCSLister creates an UpstreamLister that shares the Fetcher's persistent
// Git repository cache.
func NewVCSLister(fetcher Fetcher, timeout time.Duration) (UpstreamLister, error) {
	repositories, ok := fetcher.(*gitFetcher)
	if !ok {
		return nil, fmt.Errorf("VCS lister requires the Git-backed Skill fetcher")
	}
	return &vcsLister{repositories: repositories, timeout: timeout}, nil
}

type listSFResp struct {
	rev      *storage.RevInfo
	versions []string
}

func (l *vcsLister) List(ctx context.Context, skillPath string) (*storage.RevInfo, []string, error) {
	const op errors.Op = "vcsLister.List"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	value, err, _ := l.repositories.syncs.Do("list:"+skillPath, func() (any, error) {
		coordinate, err := parseGitHubSkillCoordinate(skillPath)
		if err != nil {
			return nil, errors.E(op, err, errors.KindNotFound)
		}
		subdir := coordinate.repositorySubdir()

		timeoutCtx, cancel := context.WithTimeout(ctx, l.timeout)
		defer cancel()
		if err := l.repositories.syncRepository(timeoutCtx, coordinate); err != nil {
			if errors.IsErr(timeoutCtx.Err(), context.DeadlineExceeded) {
				return nil, errors.E(op, err, errors.KindGatewayTimeout)
			}
			return nil, err
		}
		repoDir, err := l.repositories.repositoryDir(coordinate.Repository)
		if err != nil {
			return nil, errors.E(op, err)
		}
		if subdir != "" {
			headHash, err := gitOutput(timeoutCtx, repoDir, "rev-parse", "HEAD^{commit}")
			if err != nil {
				return nil, errors.E(op, err, errors.KindNotFound)
			}
			if _, err := gitFileContent(timeoutCtx, repoDir, headHash, filepath.ToSlash(filepath.Join(subdir, "SKILL.md"))); err != nil {
				return nil, errors.E(op,
					fmt.Sprintf("SKILL.md not found for Skill %q at default revision", skillPath),
					errors.S(skillPath), errors.KindNotFound)
			}
		}
		tagOutput, err := gitOutput(timeoutCtx, repoDir, "tag", "--list")
		if err != nil {
			return nil, errors.E(op, err)
		}
		versions := make([]string, 0)
		for _, tag := range strings.Fields(tagOutput) {
			if semver.IsValid(tag) {
				versions = append(versions, tag)
			}
		}
		sort.Slice(versions, func(i, j int) bool { return semver.Compare(versions[i], versions[j]) < 0 })

		version := ""
		ref := ""
		if len(versions) > 0 {
			version = versions[len(versions)-1]
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
		short := hash
		if len(short) > 12 {
			short = short[:12]
		}
		if version == "" {
			version = modmodule.PseudoVersion("v0", "", commitTime, short)
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
		return nil, nil, err
	}
	result := value.(listSFResp)
	return result.rev, result.versions, nil
}
