/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J12 root/nested multi-Skill Repository installation, one authoritative Package Store, shared runtime preservation, hidden-member filtering, and Cartesian multi-Agent projections.
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
	packagePath := "fixtures.test/group/subgroup/collection"
	version := "v1.0.0"

	repositoryAdd := execCLI(t, ctx, container,
		"add", "https://"+packagePath+"@"+version,
		"--agent", "codex",
		"--agent", "goose",
		"--output", "json",
	)
	require.Equal(t, 0, repositoryAdd.exitCode, repositoryAdd.output)

	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	packageDir := filepath.Join(sandboxRoot, "project", ".skillsgo", "packages", coordinate)
	for _, relativeSkillPath := range []string{".", "skills/alpha", "skills/beta", "skills/CamelCase", "skills/general/ideation/naming"} {
		require.FileExists(t, filepath.Join(packageDir, filepath.FromSlash(relativeSkillPath), "SKILL.md"))
	}
	for _, projectionRoot := range []string{filepath.Join(sandboxRoot, "project", ".agents", "skills"), filepath.Join(sandboxRoot, "project", ".goose", "skills")} {
		for _, name := range []string{"root-suite", "alpha", "beta", "camel-case", "naming"} {
			projection := filepath.Join(projectionRoot, name)
			require.FileExists(t, filepath.Join(projection, "SKILL.md"))
			info, err := os.Lstat(projection)
			require.NoError(t, err)
			require.NotZero(t, info.Mode()&os.ModeSymlink)
		}
		require.NoDirExists(t, filepath.Join(projectionRoot, coordinate))
	}
	require.FileExists(t, filepath.Join(packageDir, "skills", "invalid", "SKILL.md"))
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "root-suite", "runtime", "shared.sh"))
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skills.yaml"))
	require.NoError(t, err)
	lock, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skills-lock.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), packagePath+":")
	require.Contains(t, string(manifest), "version: "+version)
	require.Contains(t, string(manifest), "- root-suite")
	require.Contains(t, string(manifest), "- alpha")
	require.Contains(t, string(manifest), "- beta")
	require.Contains(t, string(manifest), "- camel-case")
	require.Contains(t, string(manifest), "- naming")
	require.Contains(t, string(manifest), "- codex")
	require.Contains(t, string(manifest), "- goose")
	require.Contains(t, string(lock), packagePath+":")
	require.Contains(t, string(lock), "version: "+version)
	require.Contains(t, string(lock), "sum: h1:")
}

func TestJ12SkillNameIndependentFromSourceDirectory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	packagePath := "fixtures.test/group/subgroup/collection"
	version := "v1.0.0"

	add := execCLI(t, ctx, container,
		"add", "https://"+packagePath+"@"+version, "--skill", "camel-case",
		"--agent", "codex",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	installed := filepath.Join(sandboxRoot, "project", ".agents", "skills", "camel-case")
	require.FileExists(t, filepath.Join(installed, "SKILL.md"))
	lock, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skills-lock.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(lock), "sum: h1:")

	require.NoError(t, os.Remove(installed))
	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(installed, "SKILL.md"))
}

func TestJ12SelectedRepositoryProjectionLifecycle(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	packagePath, version := "fixtures.test/group/subgroup/collection", "v1.0.0"

	rootAdd := execCLI(t, ctx, container,
		"add", "https://"+packagePath+"@"+version,
		"--skill", "root-suite",
		"--agent", "codex",
		"--output", "json",
	)
	require.Equal(t, 0, rootAdd.exitCode, rootAdd.output)
	nestedAdd := execCLI(t, ctx, container,
		"add", "https://"+packagePath+"@"+version,
		"--skill", "naming",
		"--agent", "goose",
		"--output", "json",
	)
	require.Equal(t, 0, nestedAdd.exitCode, nestedAdd.output)

	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	packageDir := filepath.Join(sandboxRoot, "project", ".skillsgo", "packages", coordinate)
	projections := []string{filepath.Join(sandboxRoot, "project", ".agents", "skills"), filepath.Join(sandboxRoot, "project", ".goose", "skills")}
	require.FileExists(t, filepath.Join(packageDir, "skills", "beta", "SKILL.md"))
	for _, projection := range projections {
		require.FileExists(t, filepath.Join(projection, "root-suite", "SKILL.md"))
		require.FileExists(t, filepath.Join(projection, "naming", "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projection, "beta"))
	}

	removeNested := execCLI(t, ctx, container, "remove", "naming", "--yes", "--ui", "plain", "--color", "never")
	require.Equal(t, 0, removeNested.exitCode, removeNested.output)
	for _, projection := range projections {
		require.FileExists(t, filepath.Join(projection, "root-suite", "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projection, "naming"))
	}

	removeGoose := execCLI(t, ctx, container, "remove", "root-suite", "--agent", "goose", "--yes", "--ui", "plain", "--color", "never")
	require.Equal(t, 0, removeGoose.exitCode, removeGoose.output)
	require.FileExists(t, filepath.Join(projections[0], "root-suite", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projections[1], "root-suite"))
	require.FileExists(t, filepath.Join(packageDir, "skills", "general", "ideation", "naming", "SKILL.md"))
}
