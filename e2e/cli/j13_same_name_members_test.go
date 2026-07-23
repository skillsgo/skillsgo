/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage that duplicate canonical Skill Names reject the complete Repository Publication without local replacement or data loss.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ13DuplicateSkillNamesRejectRepositoryAtomically(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/duplicate"
	first := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "one",
		"--agent", "codex",

		"--yes",
		"--output", "json",
	)
	require.NotEqual(t, 0, first.exitCode, first.output)
	require.Contains(t, first.output, "HTTP 400")
	second := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "shared",
		"--agent", "codex",
		"--yes",
		"--output", "json",
	)
	require.NotEqual(t, 0, second.exitCode, second.output)
	require.Contains(t, second.output, "HTTP 400")
	require.NoFileExists(t, sandboxRoot+"/project/skillsgo.yaml")
	require.NoFileExists(t, sandboxRoot+"/project/skillsgo-lock.yaml")
}
