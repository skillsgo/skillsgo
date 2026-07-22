/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J12 multi-Skill repository installation.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ12RepositoryInstall(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repositoryID := "fixtures.test/group/subgroup/collection"
	version := "v1.0.0"

	repositoryAdd := execCLI(t, ctx, container,
		"add", "https://"+repositoryID+"@"+version,
		"--agent", "codex",
		"--output", "json",
	)
	require.Equal(t, 0, repositoryAdd.exitCode, repositoryAdd.output)

	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	vendor := filepath.Join(sandboxRoot, "project", ".skillsgo", "vendor", coordinate)
	projection := filepath.Join(sandboxRoot, "project", ".agents", "skills", coordinate)
	for _, relativeSkillPath := range []string{".", "skills/alpha", "skills/beta", "skills/CamelCase", "skills/general/ideation/naming"} {
		require.FileExists(t, filepath.Join(vendor, filepath.FromSlash(relativeSkillPath), "SKILL.md"))
		require.FileExists(t, filepath.Join(projection, filepath.FromSlash(relativeSkillPath), "SKILL.md"))
	}
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	lock, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.lock"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), repositoryID+":")
	require.Contains(t, string(manifest), "version: "+version)
	require.Contains(t, string(manifest), "- .")
	require.Contains(t, string(manifest), "skills/alpha")
	require.Contains(t, string(manifest), "skills/beta")
	require.Contains(t, string(manifest), "skills/CamelCase")
	require.Contains(t, string(manifest), "skills/general/ideation/naming")
	require.Contains(t, string(manifest), "- codex")
	require.Contains(t, string(lock), repositoryID+":")
	require.Contains(t, string(lock), "version: "+version)
	require.Contains(t, string(lock), "sum: h1:")
}

func TestJ12ManifestNameIndependentFromSourceDirectory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repositoryID := "fixtures.test/group/subgroup/collection"
	version := "v1.0.0"

	add := execCLI(t, ctx, container,
		"add", "https://"+repositoryID+"/-/skills/CamelCase@"+version,
		"--agent", "codex",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	installed := filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "collection@v1.0.0", "skills", "CamelCase")
	require.FileExists(t, filepath.Join(installed, "SKILL.md"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "camel-case", "SKILL.md"))
	lock, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.lock"))
	require.NoError(t, err)
	require.Contains(t, string(lock), "sum: h1:")

	require.NoError(t, os.RemoveAll(installed))
	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(installed, "SKILL.md"))
}
