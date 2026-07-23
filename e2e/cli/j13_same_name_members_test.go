/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that same-name members publish completely, names resolve deterministically, and paths select exactly.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ13SameNameMembersRemainExactlySelectable(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/duplicate"
	byName := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "shared",
		"--agent", "codex",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, byName.exitCode, byName.output)
	projection := filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "duplicate@v1.0.0")
	require.FileExists(t, filepath.Join(projection, "one", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "two", "SKILL.md"))

	resetLocalInstallation(t, ctx, container)
	byPath := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill-path", "two",
		"--agent", "codex",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, byPath.exitCode, byPath.output)
	require.NoFileExists(t, filepath.Join(projection, "one", "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "two", "SKILL.md"))
}
