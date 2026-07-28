/*
 * [INPUT]: Depends on the released CLI and Hub, a selected member that disappears in the target Package version, and one locally modified old-version Projection.
 * [OUTPUT]: Provides black-box coverage that dry-run detects the same unsafe old-version retirement as apply and that the rejected Package-version switch preserves all prior state.
 * [POS]: Serves as the destructive Package-version replacement failure journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ53PackageVersionSwitchRollback(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	const repository = "fixtures.test/group/subgroup/collection"

	seed := execCLI(t, ctx, container,
		"add", repository+"@v1.0.0", "--skill-path", "skills/beta",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, seed.exitCode, seed.output)
	var current addResponse
	require.NoError(t, json.Unmarshal([]byte(seed.output), &current), seed.output)

	manifestPath := filepath.Join(sandboxRoot, "project", "skills.yaml")
	lockPath := filepath.Join(sandboxRoot, "project", "skills-lock.yaml")
	manifestBefore := mustReadFile(t, manifestPath)
	lockBefore := mustReadFile(t, lockPath)
	modifiedPath := containerPathOnHost(t, sandboxRoot, current.Projections[0].Path, "SKILL.md")
	const privateChange = "private beta change\n"
	require.NoError(t, os.WriteFile(modifiedPath, []byte(privateChange), 0o600))
	dryRun := execCLI(t, ctx, container,
		"add", repository+"@v1.1.0", "--skill-path", "skills/alpha",
		"--agent", "codex", "--dry-run", "--output", "json",
	)
	require.NotEqual(t, 0, dryRun.exitCode, dryRun.output)
	require.Contains(t, dryRun.output, "Local Modification")
	require.Equal(t, manifestBefore, mustReadFile(t, manifestPath))
	require.Equal(t, lockBefore, mustReadFile(t, lockPath))
	require.Equal(t, privateChange, string(mustReadFile(t, modifiedPath)))

	result := execCLI(t, ctx, container,
		"add", repository+"@v1.1.0", "--skill-path", "skills/alpha",
		"--agent", "codex", "--output", "json",
	)
	require.NotEqual(t, 0, result.exitCode, result.output)
	require.Equal(t, manifestBefore, mustReadFile(t, manifestPath))
	require.Equal(t, lockBefore, mustReadFile(t, lockPath))
	require.Equal(t, privateChange, string(mustReadFile(t, modifiedPath)))
	require.DirExists(t, containerPathOnHost(t, sandboxRoot, current.PackageDir))
	require.NoDirExists(t, filepath.Join(
		sandboxRoot,
		"project",
		".skillsgo",
		"packages",
		filepath.FromSlash(repository)+"@v1.1.0",
	))
	require.NoDirExists(t, filepath.Join(
		sandboxRoot,
		"project",
		".agents",
		"skills",
		filepath.FromSlash(repository)+"@v1.1.0",
	))
}
