/*
 * [INPUT]: Uses temporary user homes, real Workspace directories, and the public user configuration Store API.
 * [OUTPUT]: Specifies strict YAML persistence, canonical idempotent project registration, deterministic listing, and non-destructive removal.
 * [POS]: Serves as persistence contract coverage for the CLI-owned general user configuration document.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestStoreProjectLifecycle(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, "work", "demo")
	require.NoError(t, os.MkdirAll(root, 0o700))
	store := Store{Home: home}
	first, err := store.AddProject(root)
	require.NoError(t, err)
	again, err := store.AddProject(filepath.Join(root, "."))
	require.NoError(t, err)
	require.Equal(t, first, again)

	configBytes, err := os.ReadFile(filepath.Join(home, ".skillsgo", "config.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(configBytes), "schemaVersion: 1\nprojects:\n  - ")
	require.NotContains(t, string(configBytes), "id:")
	require.NotContains(t, string(configBytes), "name:")
	require.NotContains(t, string(configBytes), "root:")
	require.NotContains(t, string(configBytes), "managed-scopes")

	conflictRoot := filepath.Join(home, "work", "conflict")
	require.NoError(t, os.MkdirAll(conflictRoot, 0o700))
	conflict, err := store.AddProject(conflictRoot)
	require.NoError(t, err)
	projects, err := store.ListProjects()
	require.NoError(t, err)
	require.ElementsMatch(t, []Project{first, conflict}, projects)
	removed, err := store.RemoveProject(first.Root)
	require.NoError(t, err)
	require.True(t, removed)
	projects, err = store.ListProjects()
	require.NoError(t, err)
	require.Equal(t, []Project{conflict}, projects)
	require.DirExists(t, root)
}

func TestStoreRejectsUnknownConfigurationKeys(t *testing.T) {
	home := t.TempDir()
	path := filepath.Join(home, ".skillsgo", "config.yaml")
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	require.NoError(t, os.WriteFile(path, []byte("schemaVersion: 1\nprojects: []\nunknown: true\n"), 0o600))
	_, err := (Store{Home: home}).ListProjects()
	require.ErrorContains(t, err, "invalid SkillsGo configuration")
}
