/*
 * [INPUT]: Depends on a deterministic Repository whose nested Skill disappears between immutable tags.
 * [OUTPUT]: Provides black-box coverage for revision-faithful Repository membership and retained older nested-Skill availability.
 * [POS]: Serves as the immutable Repository history journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ29RepositoryHistory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"

	latest := execCLI(t, ctx, container, "add", "https://"+repository+"@v1.1.0", "--agent", "codex", "--copy", "--yes", "--output", "json")
	require.Equal(t, 0, latest.exitCode, latest.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta"))

	oldBeta := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "skills/beta",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, oldBeta.exitCode, oldBeta.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta", "SKILL.md"))

	nestedLatest := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/mod/"+repository+"/-/skills/beta/@latest")
	require.Equal(t, 0, nestedLatest.exitCode, nestedLatest.output)
	require.Contains(t, nestedLatest.output, `"Version":"v1.0.0"`)
}
