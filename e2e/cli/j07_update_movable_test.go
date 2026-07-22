/*
 * [INPUT]: Depends on the deterministic movable Repository and the released CLI, Hub, JSON, Git, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that an explicit head re-add advances from C1 to C2 while persisted state remains pinned to immutable versions.
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
	repository := "fixtures.test/group/subgroup/movable"

	oldAdd := execCLI(t, ctx, container,
		"add", "https://"+repository+"@head",
		"--skill", "skills/head",
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

	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.mod")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.NotContains(t, string(manifestBefore), "@head", "movable selector must not be persisted")

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	targetPath := filepath.Join(sandboxRoot, "project", ".agents", "skills", "movable-head-skill", "SKILL.md")
	require.FileExists(t, targetPath)
	beforeContent, err := os.ReadFile(targetPath)
	require.NoError(t, err)
	require.Contains(t, string(beforeContent), "Movable C1.")

	work := "/e2e/git-work/movable"
	for _, command := range [][]string{
		{"sed", "-i", "s/Movable C1\\./Movable C2./", work + "/skills/head/SKILL.md"},
		{"git", "-C", work, "add", "."},
		{"git", "-C", work, "commit", "-m", "movable C2"},
		{"git", "-C", work, "push", "origin", "main"},
	} {
		result := execInContainer(t, ctx, container, command...)
		require.Equal(t, 0, result.exitCode, result.output)
	}

	update := execCLI(t, ctx, container,
		"add", "https://"+repository+"@head",
		"--skill", "skills/head",
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
	afterContent, err := os.ReadFile(targetPath)
	require.NoError(t, err)
	require.Contains(t, string(afterContent), "Movable C2.")
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.NotEqual(t, sumBefore, sumAfter)
	require.Contains(t, string(sumAfter), refreshed.Version)
	require.Contains(t, string(sumAfter), oldInstalled.Version, "Workspace Sum keeps historical integrity evidence")
	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestAfter), refreshed.Version)
	require.NotContains(t, string(manifestAfter), "@head")
}
