//go:build windows

/*
 * [INPUT]: Depends on Windows cmd.exe's directory-junction primitive and absolute local filesystem paths.
 * [OUTPUT]: Provides unprivileged directory junctions, junction-candidate recognition, resolved file-identity matching, declared-content baseline matching, and reparse-target diagnostics for Agent Skill Projections on Windows.
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
	"unicode/utf16"

	"golang.org/x/sys/windows"
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

func isProjectionLinkCandidate(path string, _ os.FileInfo) bool {
	pointer, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return false
	}
	attributes, err := windows.GetFileAttributes(pointer)
	return err == nil && attributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0
}

func projectionLinkMatches(link, target string) (bool, error) {
	buffer := make([]byte, windows.MAXIMUM_REPARSE_DATA_BUFFER_SIZE)
	if length, readErr := windows.Readlink(link, buffer); readErr == nil {
		actual := normalizeWindowsPath(string(buffer[:length]))
		if !filepath.IsAbs(actual) {
			actual = filepath.Join(filepath.Dir(link), actual)
		}
		if strings.EqualFold(filepath.Clean(actual), normalizeWindowsPath(target)) {
			return true, nil
		}
	}
	resolvedLink, linkErr := windowsFinalPath(link)
	resolvedTarget, targetErr := windowsFinalPath(target)
	if linkErr == nil && targetErr == nil && strings.EqualFold(resolvedLink, resolvedTarget) {
		return true, nil
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
	actual, err := projectionDigestFromDirectory(link, nil)
	if err != nil {
		return false, err
	}
	expected, err := projectionDigestFromDirectory(baseline, nil)
	if err != nil {
		return false, err
	}
	return actual == expected, nil
}

func projectionLinkDiagnostic(link string) string {
	buffer := make([]byte, windows.MAXIMUM_REPARSE_DATA_BUFFER_SIZE)
	length, err := windows.Readlink(link, buffer)
	if err != nil {
		return fmt.Sprintf("read junction target: %v", err)
	}
	return fmt.Sprintf("junction target %q", normalizeWindowsPath(string(buffer[:length])))
}

func windowsFinalPath(path string) (string, error) {
	pointer, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return "", err
	}
	handle, err := windows.CreateFile(
		pointer,
		0,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_FLAG_BACKUP_SEMANTICS,
		0,
	)
	if err != nil {
		return "", err
	}
	defer windows.CloseHandle(handle)

	buffer := make([]uint16, 512)
	for {
		length, pathErr := windows.GetFinalPathNameByHandle(handle, &buffer[0], uint32(len(buffer)), 0)
		if pathErr != nil {
			return "", pathErr
		}
		if int(length) < len(buffer) {
			resolved := string(utf16.Decode(buffer[:length]))
			return normalizeWindowsPath(resolved), nil
		}
		buffer = make([]uint16, int(length)+1)
	}
}

func normalizeWindowsPath(path string) string {
	path = strings.TrimPrefix(path, `\??\`)
	path = strings.TrimPrefix(path, `\\?\`)
	return filepath.Clean(path)
}
