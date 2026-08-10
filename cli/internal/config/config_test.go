/*
 * [INPUT]: Uses temporary user homes, real Workspace directories, and the public user configuration Store API.
 * [OUTPUT]: Specifies strict YAML persistence, canonical idempotent project registration, lazy one-time project bootstrap gating, deterministic listing, and non-destructive removal.
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

func TestStoreBootstrapProjectsPersistsItsMarkerAndRemainsEmpty(t *testing.T) {
	home := t.TempDir()
	discovered := filepath.Join(home, "work", "discovered")
	require.NoError(t, os.MkdirAll(discovered, 0o700))
	store := Store{Home: home}

	projects, err := store.BootstrapProjects([]string{discovered})
	require.NoError(t, err)
	require.Len(t, projects, 1)
	removed, err := store.RemoveProject(projects[0].Root)
	require.NoError(t, err)
	require.True(t, removed)
	projects, err = store.BootstrapProjects([]string{discovered})
	require.NoError(t, err)
	require.Empty(t, projects)

	data, err := os.ReadFile(filepath.Join(home, ".skillsgo", "config.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(data), "projectsBootstrapped: true")
}

func TestStoreProjectBootstrapNeededTracksDurableMarker(t *testing.T) {
	home := t.TempDir()
	store := Store{Home: home}
	needed, err := store.ProjectBootstrapNeeded()
	require.NoError(t, err)
	require.True(t, needed)

	_, err = store.BootstrapProjects(nil)
	require.NoError(t, err)
	needed, err = store.ProjectBootstrapNeeded()
	require.NoError(t, err)
	require.False(t, needed)
}
