/*
 * [INPUT]: Uses temporary user homes, real Workspace directories, and the public Managed Scope Registry API.
 * [OUTPUT]: Specifies canonical idempotent registration, atomic relocation, deterministic listing, and non-destructive removal.
 * [POS]: Serves as persistence contract coverage for the CLI-owned Managed Scope registry.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package projectregistry

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestRegistryAddListAndRemove(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, "work", "demo")
	require.NoError(t, mkdirAll(root))
	registry := Registry{Home: home}
	first, err := registry.Add(root)
	require.NoError(t, err)
	again, err := registry.Add(filepath.Join(root, "."))
	require.NoError(t, err)
	require.Equal(t, first, again)
	movedRoot := filepath.Join(home, "work", "moved")
	require.NoError(t, mkdirAll(movedRoot))
	canonicalMovedRoot, err := filepath.EvalSymlinks(movedRoot)
	require.NoError(t, err)
	moved, err := registry.Move(first.ID, movedRoot)
	require.NoError(t, err)
	require.Equal(t, canonicalMovedRoot, moved.Root)
	conflictRoot := filepath.Join(home, "work", "conflict")
	require.NoError(t, mkdirAll(conflictRoot))
	conflict, err := registry.Add(conflictRoot)
	require.NoError(t, err)
	_, err = registry.Move(moved.ID, conflict.Root)
	require.Error(t, err)
	projects, err := registry.List()
	require.NoError(t, err)
	require.ElementsMatch(t, []Project{moved, conflict}, projects)
	removed, err := registry.Remove(moved.ID)
	require.NoError(t, err)
	require.True(t, removed)
	projects, err = registry.List()
	require.NoError(t, err)
	require.Equal(t, []Project{conflict}, projects)
	require.DirExists(t, root)
}

func mkdirAll(path string) error { return os.MkdirAll(path, 0o700) }
