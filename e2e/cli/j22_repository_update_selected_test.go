/*
 * [INPUT]: Depends on the disposable E2E environment, one multi-Skill Repository dependency, and state-bound Repository update.
 * [OUTPUT]: Provides black-box coverage that all selected siblings move atomically to one Repository version.
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

func TestJ22SelectedSkillsUpdateAtRepositoryGranularity(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/mixed"
	seed := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "alpha", "--skill", "beta",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, seed.exitCode, seed.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(seed.output), &installed), seed.output)
	sibling := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "beta", "SKILL.md")
	beforeTarget, err := os.ReadFile(sibling)
	require.NoError(t, err)
	beforeSum, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo-lock.yaml"))
	require.NoError(t, err)

	preflight := execCLI(t, ctx, container, "update", repository+"@v1.1.0", "--preflight", "--output", "json")
	require.Equal(t, 0, preflight.exitCode, preflight.output)
	var preview struct {
		StateToken string `json:"stateToken"`
	}
	require.NoError(t, json.Unmarshal([]byte(preflight.output), &preview), preflight.output)
	result := execCLI(t, ctx, container, "update", repository+"@v1.1.0", "--state-token", preview.StateToken, "--output", "json")
	require.Equal(t, 0, result.exitCode, result.output)
	newProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", filepath.FromSlash(repository)+"@v1.1.0")
	afterTarget, err := os.ReadFile(filepath.Join(newProjection, "skills", "beta", "SKILL.md"))
	require.NoError(t, err)
	afterSum, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo-lock.yaml"))
	require.NoError(t, err)
	require.NotEqual(t, beforeTarget, afterTarget)
	require.Contains(t, string(afterSum), "version: v1.1.0")
	require.NotContains(t, string(afterSum), "v1.0.0")
	require.NotEqual(t, beforeSum, afterSum)
}
