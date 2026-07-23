/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that install refuses to overwrite a locally modified Repository Projection and leaves recovery to the user.
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

func TestJ16InstallDoesNotOverwriteLocalModification(t *testing.T) {
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

	targetPath := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha")
	skillPath := filepath.Join(targetPath, "SKILL.md")
	original, err := os.ReadFile(skillPath)
	require.NoError(t, err)
	const localChange = "private local e2e modification\n"
	require.NoError(t, os.WriteFile(skillPath, []byte(localChange), 0o600))

	restore := execCLI(t, ctx, container, "install", "--output", "json")
	require.NotEqual(t, 0, restore.exitCode, restore.output)
	require.Contains(t, restore.output, "Local Modification")
	restored, err := os.ReadFile(skillPath)
	require.NoError(t, err)
	require.Equal(t, localChange, string(restored))
	require.NotEqual(t, original, restored)
}
