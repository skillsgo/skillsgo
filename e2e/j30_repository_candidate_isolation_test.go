/*
 * [INPUT]: Depends on a Repository revision containing valid root/nested Skills and one malformed SKILL.md candidate.
 * [OUTPUT]: Provides black-box coverage that malformed candidates never enter Repository Info or block valid sibling installation.
 * [POS]: Serves as invalid-candidate isolation coverage in the cross-product E2E workspace.
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

func TestJ30RepositoryCandidateIsolation(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"
	valid := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "alpha",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, valid.exitCode, valid.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	manifestBefore, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	sumBefore, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)

	info := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/"+repository+"/@v/v1.0.0.info")
	require.Equal(t, 0, info.exitCode, info.output)
	require.Contains(t, info.output, repository+"/-/skills/alpha")
	require.Contains(t, info.output, repository+"/-/skills/beta")
	require.NotContains(t, info.output, repository+"/-/skills/invalid")

	invalid := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "skills/invalid",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.NotEqual(t, 0, invalid.exitCode, invalid.output)
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "invalid"))
	manifestAfter, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	sumAfter, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter)
	require.Equal(t, sumBefore, sumAfter)
}
