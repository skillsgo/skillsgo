//go:build windows

/*
 * [INPUT]: Depends on Windows cmd.exe's directory-junction primitive and absolute local filesystem paths.
 * [OUTPUT]: Provides unprivileged directory junctions, junction-candidate recognition, and resolved file-identity matching for Agent Skill Projections on Windows.
 * [POS]: Serves as the Windows Projection-link implementation beneath Package Store transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"fmt"
	"os"
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

func isProjectionLinkCandidate(info os.FileInfo) bool {
	// Windows directory junctions are reparse points but os.Lstat reports them
	// as directories rather than ModeSymlink on supported runners.
	return info.IsDir() || info.Mode()&os.ModeSymlink != 0
}

func projectionLinkMatches(link, target string) (bool, error) {
	linkInfo, err := os.Stat(link)
	if err != nil {
		return false, err
	}
	targetInfo, err := os.Stat(target)
	if err != nil {
		return false, err
	}
	return os.SameFile(linkInfo, targetInfo), nil
}
