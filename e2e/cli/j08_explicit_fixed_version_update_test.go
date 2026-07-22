/*
 * [INPUT]: Depends on the deterministic tagged Repository fixture, released CLI Update Plan preflight/execution, Repository-fresh head/release state, and observable Workspace files.
 * [OUTPUT]: Provides black-box coverage that a fixed installation remains pinned even when a newer release exists and preflight stays read-only.
 * [POS]: Serves as the exact-selector pinning contract in the cross-product E2E workspace.
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

func TestJ08ExplicitFixedVersionUpdate(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	const (
		repository = "fixtures.test/group/subgroup/collection"
		skillID    = repository + "/-/skills/alpha"
	)

	installedResult := execCLI(t, ctx, container,
		"add", skillID+"@v1.0.0", "--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, installedResult.exitCode, installedResult.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(installedResult.output), &installed), installedResult.output)

	seedDirectory := "/e2e/catalog-seed"
	created := execInContainer(t, ctx, container, "mkdir", "-p", seedDirectory)
	require.Equal(t, 0, created.exitCode, created.output)
	seedLatest := execCLIFrom(t, ctx, container, seedDirectory,
		"add", skillID+"@v1.1.0", "--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, seedLatest.exitCode, seedLatest.output)

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	targetRequest := map[string]any{
		"scope": "project", "projectRoot": "/e2e/project", "agent": "codex", "mode": "copy",
		"path": "/e2e/project/.agents/skills/alpha", "skillId": skillID, "version": installed.Version,
	}
	encodedTarget, err := json.Marshal(targetRequest)
	require.NoError(t, err)
	preflight := execCLI(t, ctx, container,
		"update", "--target", string(encodedTarget), "--preflight", "--output", "json",
	)
	require.Equal(t, 0, preflight.exitCode, preflight.output)
	var plan struct {
		Targets []struct {
			Action     string `json:"action"`
			ToVersion  string `json:"toVersion"`
			StateToken string `json:"stateToken"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal([]byte(preflight.output), &plan), preflight.output)
	require.Len(t, plan.Targets, 1)
	require.Equal(t, "pinned", plan.Targets[0].Action)
	require.Equal(t, installed.Version, plan.Targets[0].ToVersion)
	sumAfterPreflight, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfterPreflight, "checking a pinned installation must be read-only")
	pinnedSkill, err := os.ReadFile(filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(pinnedSkill), "Alpha at v1.")
}
