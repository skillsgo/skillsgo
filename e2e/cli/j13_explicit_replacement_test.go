/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that same-name Repository members coexist by stable relative path without replacement or data loss.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ13SameNameMembersCoexistByPath(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/duplicate"
	first := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "one",
		"--agent", "codex",

		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, first.exitCode, first.output)
	second := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "two",
		"--agent", "codex",
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, second.exitCode, second.output)

	coordinate := filepath.Join(sandboxRoot, "project", ".agents", "skills", "fixtures.test", "group", "subgroup", "duplicate@v1.0.0")
	require.FileExists(t, filepath.Join(coordinate, "one", "SKILL.md"))
	require.FileExists(t, filepath.Join(coordinate, "two", "SKILL.md"))
	manifestAfter, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	lockAfter, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.lock"))
	require.NoError(t, err)
	require.Contains(t, string(manifestAfter), "- one")
	require.Contains(t, string(manifestAfter), "- two")
	require.Contains(t, string(lockAfter), "sum: h1:")
}
