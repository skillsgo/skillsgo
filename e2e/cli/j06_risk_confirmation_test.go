/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J06 immutable risk confirmation.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ06RiskConfirmation(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	seed := execCLI(t, ctx, container,
		"add", testSkillID+"@main",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, seed.exitCode, seed.output)
	var seeded addResponse
	require.NoError(t, json.Unmarshal([]byte(seed.output), &seeded), seed.output)
	require.NotEmpty(t, seeded.Version)
	immutableSource := testSkillID + "@" + seeded.Version

	hubInfo := findArtifactFile(t, filepath.Join(sandboxRoot, "hub", "storage"), testSkillID, ".info")
	resetLocalInstallation(t, sandboxRoot)
	rewriteJSONField(t, hubInfo, "Risk", "high")

	highBlocked := execCLI(t, ctx, container,
		"add", immutableSource,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--output", "json",
	)
	require.NotEqual(t, 0, highBlocked.exitCode)
	requireNoLocalInstallation(t, sandboxRoot)

	highApproved := execCLI(t, ctx, container,
		"add", immutableSource,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--output", "json",
	)
	require.Equal(t, 0, highApproved.exitCode, highApproved.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"))

	resetLocalInstallation(t, sandboxRoot)
	rewriteJSONField(t, hubInfo, "Risk", "critical")
	criticalBlocked := execCLI(t, ctx, container,
		"add", immutableSource,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--output", "json",
	)
	require.NotEqual(t, 0, criticalBlocked.exitCode)
	requireNoLocalInstallation(t, sandboxRoot)

	criticalApproved := execCLI(t, ctx, container,
		"add", immutableSource,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, criticalApproved.exitCode, criticalApproved.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"))
}
