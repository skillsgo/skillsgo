/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that an explicit re-add re-resolves a movable branch while persisted state remains canonical.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
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

func TestJ07UpdateMovable(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	oldAdd := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testOldCommit,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, oldAdd.exitCode, oldAdd.output)
	var oldInstalled addResponse
	require.NoError(t, json.Unmarshal([]byte(oldAdd.output), &oldInstalled), oldAdd.output)

	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.yaml")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.NotContains(t, string(manifestBefore), "main", "movable query must not be persisted")

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	targetPath := filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md")
	require.FileExists(t, targetPath)

	update := execCLI(t, ctx, container,
		"add", testSkillID+"@main",
		"--agent", "codex",
		"--copy",
		"--replace",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, update.exitCode, update.output)
	var refreshed addResponse
	require.NoError(t, json.Unmarshal([]byte(update.output), &refreshed), update.output)
	require.NotEqual(t, oldInstalled.Version, refreshed.Version)

	require.FileExists(t, targetPath)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.NotEqual(t, sumBefore, sumAfter)
	require.Contains(t, string(sumAfter), refreshed.Version)
	require.Contains(t, string(sumAfter), oldInstalled.Version, "Workspace Sum keeps historical integrity evidence")
	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestAfter), refreshed.Version)
	require.NotContains(t, string(manifestAfter), "main")
}
