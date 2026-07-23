/*
 * [INPUT]: Depends on a mutable local Git remote, add-time Repository resolution, immutable root Proxy reads, released CLI installation, and strict Workspace YAML persistence.
 * [OUTPUT]: Proves repeating a moved head query resolves C2 in a separate Workspace while C1 remains immutable/downloadable and the first Workspace stays pinned.
 * [POS]: Serves as the movable-query refresh journey across Git, Hub product resolution, root Repository Proxy, CLI, and Workspace state.
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
	firstResult := execCLI(t, ctx, container, "add", "https://"+repository+"@head", "--agent", "codex", "--output", "json")
	require.Equal(t, 0, firstResult.exitCode, firstResult.output)
	var first struct {
		Version string `json:"version"`
	}
	require.NoError(t, json.Unmarshal([]byte(firstResult.output), &first), firstResult.output)
	require.NotEmpty(t, first.Version)
	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.yaml")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestBefore), "version: "+first.Version)
	require.NotContains(t, string(manifestBefore), "version: head")

	fixtureRepository(container, "movable").ReplaceAndPublish(t, ctx, "skills/head/SKILL.md", "Movable C1\\.", "Movable C2.", "movable C2")
	require.Equal(t, 0, execInContainer(t, ctx, container, "mkdir", "-p", "/e2e/project-c2").exitCode)
	secondResult := execCLIFrom(t, ctx, container, "/e2e/project-c2", "add", "https://"+repository+"@head", "--agent", "codex", "--output", "json")
	require.Equal(t, 0, secondResult.exitCode, secondResult.output)
	var second struct {
		Version string `json:"version"`
	}
	require.NoError(t, json.Unmarshal([]byte(secondResult.output), &second), secondResult.output)
	require.NotEmpty(t, second.Version)
	require.NotEqual(t, first.Version, second.Version)

	for _, version := range []string{first.Version, second.Version} {
		exact := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/"+repository+"/@v/"+version+".info")
		require.Equal(t, 0, exact.exitCode, exact.output)
		require.Contains(t, exact.output, `"Version":"`+version+`"`)
	}
	secondExact := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/"+repository+"/@v/"+second.Version+".info")
	require.Contains(t, secondExact.output, "Movable C2.")
	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter)
}
