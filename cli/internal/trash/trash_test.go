/*
 * [INPUT]: Depends on temporary filesystem content and the active operating-system Trash adapter.
 * [OUTPUT]: Verifies missing-path idempotence and that disposal removes content from its original path.
 * [POS]: Serves as behavioral coverage for the recoverable-disposal boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package trash

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMoveMissingPathIsNoOp(t *testing.T) {
	if err := Move(filepath.Join(t.TempDir(), "missing")); err != nil {
		t.Fatalf("Move() error = %v", err)
	}
}

func TestMoveRemovesOriginalPath(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	if err := os.Mkdir(home, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	path := filepath.Join(root, "skill")
	if err := os.Mkdir(path, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := Move(path); err != nil {
		t.Fatalf("Move() error = %v", err)
	}
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		t.Fatalf("original path still exists: %v", err)
	}
}
