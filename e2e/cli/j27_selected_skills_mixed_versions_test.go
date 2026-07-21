/*
 * [INPUT]: Depends on the disposable E2E environment and public repeated --skill Version Query contract.
 * [OUTPUT]: Provides black-box coverage for human Repository URLs, inherited selector versions, and per-Skill version overrides.
 * [POS]: Serves as the mixed selected-member installation journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ27SelectedSkillsMixedVersions(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	result := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/mixed@v1.0.0",
		"--skill", "alpha",
		"--skill", "skills/beta@v1.1.0",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, result.exitCode, result.output)

	alpha, err := os.ReadFile(filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	beta, err := os.ReadFile(filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(alpha), "Alpha v1.")
	require.Contains(t, string(beta), "Beta v2.")
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/mixed/-/skills/alpha v1.0.0")
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/mixed/-/skills/beta v1.1.0")
	require.NotContains(t, string(manifest), "fixtures.test/group/subgroup/mixed:")

	resetLocalInstallation(t, ctx, container)
	branch := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/mixed", "--skill", "alpha@main",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, branch.exitCode, branch.output)
	branchSkill, err := os.ReadFile(filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(branchSkill), "Alpha v2.")

	resetLocalInstallation(t, ctx, container)
	commit := execInContainer(t, ctx, container, "git", "--git-dir=/e2e/git/group/subgroup/mixed", "rev-parse", "v1.0.0^{commit}")
	require.Equal(t, 0, commit.exitCode, commit.output)
	pinned := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/mixed", "--skill", "alpha@"+strings.TrimSpace(commit.output),
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, pinned.exitCode, pinned.output)
	pinnedSkill, err := os.ReadFile(filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(pinnedSkill), "Alpha v1.")
}
