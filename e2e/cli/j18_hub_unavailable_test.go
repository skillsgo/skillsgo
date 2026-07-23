/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J18 stable Hub-unavailable failure.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ18HubUnavailable(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	result := execCLI(t, ctx, container,
		"add", testRepositoryID+"@"+testSkillVersion, "--skill", testSkillName,
		"--agent", "codex",

		"--yes",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 69, result.exitCode, result.output)
	requireNoLocalInstallation(t, sandboxRoot)
}
