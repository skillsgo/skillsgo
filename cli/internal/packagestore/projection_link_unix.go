//go:build !windows

/*
 * [INPUT]: Depends on the operating system's relative symbolic-link primitive.
 * [OUTPUT]: Provides native relative directory links, link-candidate recognition, and deterministic target matching for Agent Skill Projections on macOS and Linux.
 * [POS]: Serves as the Unix Projection-link implementation beneath Package Store transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"os"
	"path/filepath"
)

func createProjectionLink(target, link string) error {
	return os.Symlink(target, link)
}

func isProjectionLinkCandidate(info os.FileInfo) bool {
	return info.Mode()&os.ModeSymlink != 0
}

func projectionLinkMatches(link, target string) (bool, error) {
	actual, err := os.Readlink(link)
	if err != nil {
		return false, err
	}
	if !filepath.IsAbs(actual) {
		actual = filepath.Join(filepath.Dir(link), actual)
	}
	if resolved, resolveErr := filepath.EvalSymlinks(link); resolveErr == nil {
		actual = resolved
	}
	if resolved, resolveErr := filepath.EvalSymlinks(target); resolveErr == nil {
		target = resolved
	}
	return filepath.Clean(actual) == filepath.Clean(target), nil
}
