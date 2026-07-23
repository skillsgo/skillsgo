/*
 * [INPUT]: Depends on the disposable E2E environment, public top-level remove command, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that unhealthy content cannot be removed and the obsolete manage command is absent.
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

func TestJ17UnhealthyTargetCannotBeRemoved(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	add := execCLI(t, ctx, container, "add", testRepositoryID+"@"+testSkillVersion, "--skill", testSkillName, "--agent", "codex", "--yes", "--output", "json")
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	targetPath := containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha")
	skillPath := filepath.Join(targetPath, "SKILL.md")
	const localChange = "keep this modified content\n"
	require.NoError(t, os.WriteFile(skillPath, []byte(localChange), 0o600))

	removed := execCLI(t, ctx, container, "remove", "alpha", "--agent", "codex", "--yes", "--ui", "plain", "--color", "never")
	require.NotEqual(t, 0, removed.exitCode)
	contents, err := os.ReadFile(skillPath)
	require.NoError(t, err)
	require.Equal(t, localChange, string(contents))
	obsolete := execCLI(t, ctx, container, "manage")
	require.NotEqual(t, 0, obsolete.exitCode)
}
