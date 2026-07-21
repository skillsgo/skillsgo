/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J16 managed-target repair.
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

func TestJ16Repair(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	targetPath := filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha")
	skillPath := filepath.Join(targetPath, "SKILL.md")
	original, err := os.ReadFile(skillPath)
	require.NoError(t, err)
	const localChange = "private local e2e modification\n"
	require.NoError(t, os.WriteFile(skillPath, []byte(localChange), 0o600))

	request := map[string]any{
		"scope":       "project",
		"projectRoot": "/e2e/project",
		"agent":       "codex",
		"mode":        "symlink",
		"path":        "/e2e/project/.agents/skills/alpha",
		"skillId":     testSkillID,
		"version":     installed.Version,
	}
	preflight := execCLI(t, ctx, container,
		"repair", "--path", request["path"].(string), "--agent", "codex", "--project", "/e2e/project",
		"--preflight", "--output", "json",
	)
	require.Equal(t, 0, preflight.exitCode, preflight.output)
	var review struct {
		Targets []struct {
			Health         string   `json:"health"`
			AllowedActions []string `json:"allowedActions"`
			StateToken     string   `json:"stateToken"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal([]byte(preflight.output), &review), preflight.output)
	require.Len(t, review.Targets, 1)
	require.Equal(t, "local-modification", review.Targets[0].Health)
	require.Equal(t, []string{"repair"}, review.Targets[0].AllowedActions)
	require.NotEmpty(t, review.Targets[0].StateToken)

	repaired := execCLI(t, ctx, container,
		"repair", "--path", request["path"].(string), "--agent", "codex", "--project", "/e2e/project",
		"--expected-state", review.Targets[0].StateToken, "--output", "json",
	)
	require.Equal(t, 0, repaired.exitCode, repaired.output)
	restored, err := os.ReadFile(skillPath)
	require.NoError(t, err)
	require.Equal(t, original, restored)
}
