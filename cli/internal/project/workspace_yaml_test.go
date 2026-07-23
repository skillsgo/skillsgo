/*
 * [INPUT]: Uses strict YAML documents and temporary Workspace roots at the public Workspace persistence seam.
 * [OUTPUT]: Specifies canonical skillsgo.yaml/skillsgo-lock.yaml parsing, validation, nearest YAML-root discovery, deterministic writing, atomic paired publication, and read-time crash recovery.
 * [POS]: Serves as the executable contract for Repository dependency intent and integrity state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestWorkspaceYAMLStrictRepositoryDependencyContract(t *testing.T) {
	require.Equal(t, "skillsgo-lock.yaml", DependencyLockName)
	document := []byte(`dependencies:
  github.com/example/skills:
    version: v1.2.3
    skills: [".", skills/design]
    agents: [codex, zed]
`)
	manifest, err := ParseWorkspaceManifest("skillsgo.yaml", document)
	require.NoError(t, err)
	dependency := manifest.Dependencies["github.com/example/skills"]
	require.Equal(t, "v1.2.3", dependency.Version)
	require.Equal(t, []string{".", "skills/design"}, dependency.Skills)
	require.Equal(t, []string{"codex", "zed"}, dependency.Agents)
}

func TestWorkspaceYAMLRejectsAmbiguousOrIncompleteState(t *testing.T) {
	tests := map[string]string{
		"unknown root field":       "dependencies: {}\nextra: true\n",
		"unknown dependency field": "dependencies:\n  github.com/example/skills:\n    version: v1.0.0\n    skills: ['.']\n    agents: [codex]\n    mode: copy\n",
		"duplicate repository":     "dependencies:\n  github.com/example/skills: {version: v1.0.0, skills: ['.'], agents: [codex]}\n  github.com/example/skills: {version: v1.0.0, skills: ['.'], agents: [zed]}\n",
		"nested repository ID":     "dependencies:\n  github.com/example/skills/-/design: {version: v1.0.0, skills: ['.'], agents: [codex]}\n",
		"movable version":          "dependencies:\n  github.com/example/skills: {version: main, skills: ['.'], agents: [codex]}\n",
		"empty skills":             "dependencies:\n  github.com/example/skills: {version: v1.0.0, skills: [], agents: [codex]}\n",
		"empty agents":             "dependencies:\n  github.com/example/skills: {version: v1.0.0, skills: ['.'], agents: []}\n",
		"duplicate member":         "dependencies:\n  github.com/example/skills: {version: v1.0.0, skills: [skills/design, skills/design], agents: [codex]}\n",
		"invalid root spelling":    "dependencies:\n  github.com/example/skills: {version: v1.0.0, skills: [./], agents: [codex]}\n",
		"implicit scalar type":     "dependencies:\n  github.com/example/skills: {version: 1.0, skills: ['.'], agents: [codex]}\n",
		"yaml alias":               "dependencies:\n  github.com/example/skills: &dependency {version: v1.0.0, skills: ['.'], agents: [codex]}\n",
	}
	for name, document := range tests {
		t.Run(name, func(t *testing.T) {
			_, err := ParseWorkspaceManifest("skillsgo.yaml", []byte(document))
			require.Error(t, err)
		})
	}
}

func TestWriteWorkspaceStatePublishesCanonicalManifestAndLock(t *testing.T) {
	root := t.TempDir()
	manifest := WorkspaceManifest{Dependencies: map[string]RepositoryDependency{
		"github.com/example/skills": {Version: "v1.2.3", Skills: []string{"skills/design", "."}, Agents: []string{"zed", "codex"}},
	}}
	lock := DependencyLock{Dependencies: map[string]LockedRepository{
		"github.com/example/skills": {Version: "v1.2.3", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="},
	}}
	require.NoError(t, WriteWorkspaceState(root, manifest, lock))

	loadedManifest, err := LoadWorkspaceManifest(root)
	require.NoError(t, err)
	require.Equal(t, []string{".", "skills/design"}, loadedManifest.Dependencies["github.com/example/skills"].Skills)
	require.Equal(t, []string{"codex", "zed"}, loadedManifest.Dependencies["github.com/example/skills"].Agents)
	loadedLock, err := LoadDependencyLock(root)
	require.NoError(t, err)
	require.Equal(t, lock.Dependencies, loadedLock.Dependencies)
	for _, name := range []string{WorkspaceManifestName, DependencyLockName} {
		info, err := os.Stat(filepath.Join(root, name))
		require.NoError(t, err)
		require.True(t, info.Mode().IsRegular())
	}
}

func TestLoadWorkspaceStateRecoversInterruptedFirstPublicationBeforeRead(t *testing.T) {
	root := t.TempDir()
	paths := []string{filepath.Join(root, WorkspaceManifestName), filepath.Join(root, DependencyLockName)}
	snapshots := []metadataFileSnapshot{{Path: paths[0]}, {Path: paths[1]}}
	_, err := beginMetadataTransaction(root, snapshots)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(paths[0], []byte("dependencies: {}\n"), 0o600))

	manifest, lock, found, err := LoadWorkspaceState(root)
	require.NoError(t, err)
	require.False(t, found)
	require.Empty(t, manifest.Dependencies)
	require.Empty(t, lock.Dependencies)
	require.NoFileExists(t, paths[0])
	require.NoFileExists(t, paths[1])
	require.NoFileExists(t, metadataTransactionPath(root))
}

func TestFindWorkspaceRootUsesSkillsgoYAML(t *testing.T) {
	root := t.TempDir()
	nested := filepath.Join(root, "nested", "deeper")
	require.NoError(t, os.MkdirAll(nested, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(root, WorkspaceManifestName), []byte("dependencies: {}\n"), 0o644))
	found, err := FindWorkspaceRoot(nested)
	require.NoError(t, err)
	require.Equal(t, root, found)
}

func TestValidateWorkspaceStateRequiresExactRepositorySet(t *testing.T) {
	manifest := WorkspaceManifest{Dependencies: map[string]RepositoryDependency{
		"github.com/example/skills": {Version: "v1.2.3", Skills: []string{"."}, Agents: []string{"codex"}},
	}}
	lock := DependencyLock{Dependencies: map[string]LockedRepository{
		"github.com/example/skills": {Version: "v1.2.3", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="},
		"github.com/example/extra":  {Version: "v1.0.0", Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="},
	}}
	require.ErrorContains(t, ValidateWorkspaceState(manifest, lock), "same Repositories")
}
