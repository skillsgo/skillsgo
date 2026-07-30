//go:build !windows

/*
 * [INPUT]: Depends on the operating system's relative symbolic-link primitive.
 * [OUTPUT]: Provides native relative directory links for Agent Skill Projections on macOS and Linux.
 * [POS]: Serves as the Unix Projection-link implementation beneath Package Store transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import "os"

func createProjectionLink(target, link string) error {
	return os.Symlink(target, link)
}
