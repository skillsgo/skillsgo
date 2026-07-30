//go:build windows

/*
 * [INPUT]: Depends on the community go-windows-junction creation primitive, Go's junction-aware filesystem APIs, and absolute local filesystem paths.
 * [OUTPUT]: Provides unprivileged directory junction creation plus standard-library target inspection, identity matching, and diagnostics for Agent Skill Projections on Windows.
 * [POS]: Serves as the Windows Projection-link implementation beneath Package Store transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	junction "github.com/nyaosorg/go-windows-junction"
)

func createProjectionLink(target, link string) error {
	absoluteTarget, err := filepath.Abs(filepath.Join(filepath.Dir(link), target))
	if err != nil {
		return fmt.Errorf("resolve Agent Skill projection junction target: %w", err)
	}
	if err := junction.Create(absoluteTarget, link); err != nil {
		return fmt.Errorf("create Agent Skill projection junction: %w", err)
	}
	return nil
}

func isProjectionLinkCandidate(path string, _ os.FileInfo) bool {
	_, err := os.Readlink(path)
	return err == nil
}

func projectionLinkMatches(link, target string) (bool, error) {
	if storedTarget, readErr := os.Readlink(link); readErr == nil {
		actual := normalizeWindowsPath(storedTarget)
		if !filepath.IsAbs(actual) {
			actual = filepath.Join(filepath.Dir(link), actual)
		}
		if strings.EqualFold(filepath.Clean(actual), normalizeWindowsPath(target)) {
			return true, nil
		}
	}
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

func projectionContentMatchesBaseline(link, baseline string) (bool, error) {
	return false, nil
}

func projectionLinkDiagnostic(link string) string {
	target, err := os.Readlink(link)
	if err != nil {
		return fmt.Sprintf("read junction target: %v", err)
	}
	return fmt.Sprintf("junction target %q", normalizeWindowsPath(target))
}

func normalizeWindowsPath(path string) string {
	path = strings.TrimPrefix(path, `\??\`)
	path = strings.TrimPrefix(path, `\\?\`)
	return filepath.Clean(path)
}
