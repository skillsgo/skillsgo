/*
 * [INPUT]: Depends on two independently locked Repository dependencies, verified ordinary-file Package Stores, missing projections, one locally modified Package Store, and offline `skillsgo install`.
 * [OUTPUT]: Proves independent Package installation groups retain a successful restoration beside one failed Local Modification group, preserve declaration bytes, return per-group results, and converge after repair and retry.
 * [POS]: Serves as the black-box partial-mutation contract for independent installation groups.
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

func TestJ39InstallationPartialFailure(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	for _, dependency := range []struct{ repository, skill string }{
		{"collection", "alpha"},
		{"mixed", "beta"},
	} {
		result := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/"+dependency.repository+"@v1.0.0", "--skill", dependency.skill, "--agent", "codex", "--output", "json")
		require.Equal(t, 0, result.exitCode, result.output)
	}
	mixedCoordinate := filepath.Join("fixtures.test", "group", "subgroup", "mixed@v1.0.0")
	collectionProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha")
	mixedProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta")
	manifestPath := filepath.Join(sandboxRoot, "project", "skills.yaml")
	lockPath := filepath.Join(sandboxRoot, "project", "skills-lock.yaml")
	manifestBefore := mustReadFile(t, manifestPath)
	lockBefore := mustReadFile(t, lockPath)
	require.NoError(t, os.Remove(collectionProjection))
	require.NoError(t, os.Remove(mixedProjection))
	mixedPackageSkill := filepath.Join(sandboxRoot, "project", ".skillsgo", "packages", mixedCoordinate, "skills", "beta", "SKILL.md")
	originalPackageSkill := mustReadFile(t, mixedPackageSkill)
	const localChange = "locally modified Package Store bytes\n"
	require.NoError(t, os.WriteFile(mixedPackageSkill, []byte(localChange), 0o644))

	install := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.NotEqual(t, 0, install.exitCode, install.output)
	require.Contains(t, install.output, `"packagePath": "fixtures.test/group/subgroup/collection"`)
	require.Contains(t, install.output, `"status": "restored"`)
	require.Contains(t, install.output, `"packagePath": "fixtures.test/group/subgroup/mixed"`)
	require.Contains(t, install.output, `"status": "failed"`)
	require.Contains(t, install.output, "Local Modification")
	require.FileExists(t, filepath.Join(collectionProjection, "SKILL.md"))
	require.NoFileExists(t, mixedProjection)
	unchanged, err := os.ReadFile(mixedPackageSkill)
	require.NoError(t, err)
	require.Equal(t, localChange, string(unchanged))
	require.Equal(t, manifestBefore, mustReadFile(t, manifestPath))
	require.Equal(t, lockBefore, mustReadFile(t, lockPath))

	require.NoError(t, os.WriteFile(mixedPackageSkill, originalPackageSkill, 0o644))
	retried := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, retried.exitCode, retried.output)
	require.Contains(t, retried.output, `"packagePath": "fixtures.test/group/subgroup/collection"`)
	require.Contains(t, retried.output, `"packagePath": "fixtures.test/group/subgroup/mixed"`)
	require.FileExists(t, filepath.Join(collectionProjection, "SKILL.md"))
	require.FileExists(t, filepath.Join(mixedProjection, "SKILL.md"))
	require.Equal(t, manifestBefore, mustReadFile(t, manifestPath))
	require.Equal(t, lockBefore, mustReadFile(t, lockPath))
}
