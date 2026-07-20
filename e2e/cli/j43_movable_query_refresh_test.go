/*
 * [INPUT]: Depends on a mutable local Git remote, public Repository main Info resolution, released CLI installation, and Workspace Manifest persistence.
 * [OUTPUT]: Provides black-box coverage that repeating an explicit main query observes C2 while an installation pinned at C1 remains unchanged.
 * [POS]: Serves as the movable-query refresh journey across Git, Hub, CLI, and Workspace state.
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

func TestJ43MovableQueryRefresh(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/movable"
	mainInfoURL := "http://127.0.0.1:3000/mod/" + repository + "/@v/main.info"

	firstResponse := execInContainer(t, ctx, container, "wget", "-qO-", mainInfoURL)
	require.Equal(t, 0, firstResponse.exitCode, firstResponse.output)
	var first struct {
		Version   string `json:"Version"`
		CommitSHA string `json:"CommitSHA"`
	}
	require.NoError(t, json.Unmarshal([]byte(firstResponse.output), &first), firstResponse.output)
	require.NotEmpty(t, first.Version)
	require.GreaterOrEqual(t, len(first.CommitSHA), 12)
	require.Contains(t, first.Version, first.CommitSHA[:12])

	installed := execCLI(t, ctx, container,
		"add", "https://"+repository+"@main",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, installed.exitCode, installed.output)
	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.mod")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestBefore), repository+" "+first.Version)

	work := "/e2e/git-work/movable"
	updated := execInContainer(t, ctx, container, "sed", "-i", "s/Movable C1\\./Movable C2./", work+"/skills/head/SKILL.md")
	require.Equal(t, 0, updated.exitCode, updated.output)
	for _, command := range [][]string{
		{"git", "-C", work, "add", "."},
		{"git", "-C", work, "commit", "-m", "movable C2"},
		{"git", "-C", work, "push", "origin", "main"},
	} {
		result := execInContainer(t, ctx, container, command...)
		require.Equal(t, 0, result.exitCode, result.output)
	}

	secondResponse := execInContainer(t, ctx, container, "wget", "-qO-", mainInfoURL)
	require.Equal(t, 0, secondResponse.exitCode, secondResponse.output)
	var second struct {
		Version   string `json:"Version"`
		CommitSHA string `json:"CommitSHA"`
	}
	require.NoError(t, json.Unmarshal([]byte(secondResponse.output), &second), secondResponse.output)
	require.NotEmpty(t, second.Version)
	require.GreaterOrEqual(t, len(second.CommitSHA), 12)
	require.NotEqual(t, first.Version, second.Version)
	require.NotEqual(t, first.CommitSHA, second.CommitSHA)
	require.Contains(t, second.Version, second.CommitSHA[:12])
	require.Contains(t, secondResponse.output, "Movable C2.")

	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter, "searching main must not mutate the installed immutable version")
}
