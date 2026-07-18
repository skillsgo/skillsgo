/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J08 pinned-installation preservation.
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

func TestJ08PreservePin(t *testing.T) {
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

	hubInfo := findArtifactFile(t, filepath.Join(sandboxRoot, "hub", "storage"), testSkillID, ".info")
	infoBytes, err := os.ReadFile(hubInfo)
	require.NoError(t, err)
	var info struct {
		CommitSHA string `json:"CommitSHA"`
	}
	require.NoError(t, json.Unmarshal(infoBytes, &info))
	require.NotEmpty(t, info.CommitSHA)

	resetLocalInstallation(t, sandboxRoot)
	pinnedAdd := execCLI(t, ctx, container,
		"add", testSkillID+"@"+info.CommitSHA,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, pinnedAdd.exitCode, pinnedAdd.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(pinnedAdd.output), &installed), pinnedAdd.output)

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	targetRequest, err := json.Marshal(map[string]any{
		"scope":       "project",
		"projectRoot": "/e2e/project",
		"agent":       "codex",
		"mode":        "copy",
		"path":        "/e2e/project/.agents/skills/ask-matt",
		"skillId":     testSkillID,
		"version":     installed.Version,
	})
	require.NoError(t, err)

	preflight := execCLI(t, ctx, container,
		"update",
		"--target", string(targetRequest),
		"--preflight",
		"--output", "json",
	)
	require.Equal(t, 0, preflight.exitCode, preflight.output)
	var plan struct {
		Targets []struct {
			Action     string `json:"action"`
			ReasonCode string `json:"reasonCode"`
		} `json:"targets"`
		Summary struct {
			Pinned int `json:"pinned"`
		} `json:"summary"`
	}
	require.NoError(t, json.Unmarshal([]byte(preflight.output), &plan), preflight.output)
	require.Len(t, plan.Targets, 1)
	require.Equal(t, "pinned", plan.Targets[0].Action)
	require.Equal(t, "fixed-commit", plan.Targets[0].ReasonCode)
	require.Equal(t, 1, plan.Summary.Pinned)

	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"))
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfter, "pinned update preflight must not rewrite skillsgo.sum")
}
