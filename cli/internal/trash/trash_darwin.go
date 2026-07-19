//go:build darwin

/*
 * [INPUT]: Depends on the macOS user Trash directory and an absolute filesystem path passed directly to mv.
 * [OUTPUT]: Provides the Darwin implementation of recoverable disposal.
 * [POS]: Serves as the macOS adapter behind the package-level Trash boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package trash

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func movePlatform(path string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	trashDir := filepath.Join(home, ".Trash")
	if err := os.MkdirAll(trashDir, 0o700); err != nil {
		return err
	}
	base := filepath.Base(path)
	destination := filepath.Join(trashDir, base)
	for index := 1; ; index++ {
		if _, statErr := os.Lstat(destination); os.IsNotExist(statErr) {
			break
		} else if statErr != nil {
			return statErr
		}
		destination = filepath.Join(trashDir, fmt.Sprintf("%s.%d", base, index))
	}
	output, err := exec.Command("/bin/mv", path, destination).CombinedOutput()
	if err != nil {
		return fmt.Errorf("macOS Trash: %w: %s", err, output)
	}
	return nil
}
