//go:build windows

/*
 * [INPUT]: Depends on Windows cmd.exe's directory-junction primitive and absolute local filesystem paths.
 * [OUTPUT]: Provides unprivileged directory junctions for Agent Skill Projections on Windows.
 * [POS]: Serves as the Windows Projection-link implementation beneath Package Store transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
)

func createProjectionLink(target, link string) error {
	absoluteTarget, err := filepath.Abs(filepath.Join(filepath.Dir(link), target))
	if err != nil {
		return fmt.Errorf("resolve Agent Skill projection junction target: %w", err)
	}
	output, err := exec.Command("cmd.exe", "/d", "/c", "mklink", "/J", link, absoluteTarget).CombinedOutput()
	if err != nil {
		return fmt.Errorf("create Agent Skill projection junction: %w: %s", err, strings.TrimSpace(string(output)))
	}
	return nil
}
