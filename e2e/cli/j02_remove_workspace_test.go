/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J02 Workspace removal.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ02RemoveWorkspace(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",

		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.Equal(t, 1, installed.SchemaVersion)
	require.Equal(t, "github.com/skillsgo/e2e-versioned-skills", installed.Repository)
	require.NotEmpty(t, installed.Version)
	require.Len(t, installed.Projections, 1)
	projection := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path)
	vendor := containerPathOnHost(t, sandboxRoot, installed.Vendor)
	require.FileExists(t, projection+"/skills/alpha/SKILL.md")
	require.FileExists(t, vendor+"/skills/alpha/SKILL.md")

	remove := execCLI(t, ctx, container,
		"remove", "alpha",
		"--agent", "codex",
		"--yes",
		"--ui", "plain",
		"--color", "never",
	)
	require.Equal(t, 0, remove.exitCode, remove.output)
	require.NoDirExists(t, projection)
	require.NoDirExists(t, vendor, "removing the last selected Skill must remove its Repository Vendor")
}
