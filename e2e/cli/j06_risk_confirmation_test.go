/*
 * [INPUT]: Depends on the SkillsGo-owned immutable high-risk fixture plus public CLI, Hub, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that a real High assessment blocks an unconfirmed install and permits an explicitly confirmed install.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ06RiskConfirmation(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	immutableSource := "github.com/skillsgo/e2e-risk-skills/-/skills/high-risk@v1.0.0"

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
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "high-risk", "SKILL.md"))
}
