/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, exact Package add, YAML/Lock, authoritative Workspace Package Store, and direct Agent Skill link contracts.
 * [OUTPUT]: Proves offline projection restoration, repeated healthy install without rewrites, unpublished-manifest filtering, declaration stability, and Local Modification preservation.
 * [POS]: Serves as the Repository expansion recovery journey in the cross-product E2E workspace.
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

func TestJ26RepositoryRestoreOffline(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	packagePath, version := "fixtures.test/group/subgroup/collection", "v1.0.0"
	add := execCLI(t, ctx, container, "add", "https://"+packagePath+"@"+version, "--agent", "codex", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	manifestPath := filepath.Join(sandboxRoot, "project", "skills.yaml")
	lockPath := filepath.Join(sandboxRoot, "project", "skills-lock.yaml")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	lockBefore, err := os.ReadFile(lockPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestBefore), packagePath+":")
	require.Contains(t, string(manifestBefore), "version: "+version)

	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	projectionRoot := filepath.Join(sandboxRoot, "project", ".agents", "skills")
	packageDir := filepath.Join(sandboxRoot, "project", ".skillsgo", "packages", coordinate)
	for _, name := range []string{"alpha", "beta", "camel-case", "naming"} {
		require.NoError(t, os.Remove(filepath.Join(projectionRoot, name)))
	}
	restore := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)
	for _, name := range []string{"alpha", "beta", "camel-case", "naming"} {
		require.FileExists(t, filepath.Join(projectionRoot, name, "SKILL.md"))
	}
	require.NoFileExists(t, filepath.Join(projectionRoot, "invalid"))
	require.NoFileExists(t, filepath.Join(packageDir, "skills", "invalid", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(packageDir, "runtime", "shared.sh"))
	shared := filepath.Join(projectionRoot, "alpha", "SKILL.md")
	before, err := os.Stat(shared)
	require.NoError(t, err)
	healthy := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, healthy.exitCode, healthy.output)
	after, err := os.Stat(shared)
	require.NoError(t, err)
	require.Equal(t, before.ModTime(), after.ModTime())

	const localChange = "user-owned projection change\n"
	require.NoError(t, os.WriteFile(shared, []byte(localChange), 0o644))
	conflict := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.NotEqual(t, 0, conflict.exitCode, conflict.output)
	require.Contains(t, conflict.output, "Local Modification")
	unchanged, err := os.ReadFile(shared)
	require.NoError(t, err)
	require.Equal(t, localChange, string(unchanged))
	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	lockAfter, err := os.ReadFile(lockPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter)
	require.Equal(t, lockBefore, lockAfter)
}
