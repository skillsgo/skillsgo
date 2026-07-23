/*
 * [INPUT]: Depends on the disposable E2E environment and a deterministic deeply nested Repository Skill.
 * [OUTPUT]: Provides black-box coverage that deep Skill paths remain resolvable across explicit immutable re-adds without false absence.
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

func TestJ24DeepSkillDiscovery(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"
	add := execCLI(t, ctx, container, "add", "https://"+repository+"@v1.0.0", "--skill", "skills/general/ideation/naming", "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "general", "ideation", "naming", "SKILL.md"))
	preflight := execCLI(t, ctx, container, "update", repository+"@v1.1.0", "--preflight", "--output", "json")
	require.Equal(t, 0, preflight.exitCode, preflight.output)
	var preview struct {
		StateToken string `json:"stateToken"`
	}
	require.NoError(t, json.Unmarshal([]byte(preflight.output), &preview), preflight.output)
	update := execCLI(t, ctx, container, "update", repository+"@v1.1.0", "--state-token", preview.StateToken, "--output", "json")
	require.Equal(t, 0, update.exitCode, update.output)
	newProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", filepath.FromSlash(repository)+"@v1.1.0")
	require.FileExists(t, filepath.Join(newProjection, "skills", "general", "ideation", "naming", "SKILL.md"))
}
