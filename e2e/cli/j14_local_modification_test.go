/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J14 Local Modification protection.
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

func TestJ14LocalModification(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testRepositoryID+"@"+testSkillVersion, "--skill", testSkillName,
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

	unsafeRemove := execCLI(t, ctx, container,
		"remove", "alpha", "--agent", "codex", "--yes", "--ui", "plain", "--color", "never",
	)
	require.NotEqual(t, 0, unsafeRemove.exitCode)
	unchanged, err := os.ReadFile(skillPath)
	require.NoError(t, err)
	require.Equal(t, localChange, string(unchanged))

	require.NotEmpty(t, original)
}
