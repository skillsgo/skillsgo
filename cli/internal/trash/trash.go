/*
 * [INPUT]: Depends on an absolute user-content path and the active operating-system adapter.
 * [OUTPUT]: Provides recoverable disposal through Move and a stable missing-path no-op.
 * [POS]: Serves as the platform-neutral Trash boundary for user-visible CLI mutations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package trash

import (
	"fmt"
	"os"
	"path/filepath"
)

// Move sends path to the operating system's Trash or Recycle Bin. Missing paths
// are already in the desired state and therefore succeed.
func Move(path string) error {
	if path == "" {
		return fmt.Errorf("trash path is required")
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return err
	}
	if _, err := os.Lstat(absolute); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	if err := movePlatform(absolute); err != nil {
		return fmt.Errorf("move %s to trash: %w", absolute, err)
	}
	return nil
}
