/*
 * [INPUT]: Depends on the disposable E2E environment, direct Skill declarations, and explicit canonical add replacement.
 * [OUTPUT]: Provides black-box coverage that re-adding one direct Skill at a new version leaves its sibling declaration and target unchanged.
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

func TestJ22UpdateOnlySelectedSkill(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/mixed"
	seed := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "alpha", "--skill", "beta",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, seed.exitCode, seed.output)
	sibling := filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta", "SKILL.md")
	beforeTarget, err := os.ReadFile(sibling)
	require.NoError(t, err)
	beforeSum, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)

	result := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.1.0", "--skill", "alpha",
		"--agent", "codex", "--copy", "--yes", "--replace", "--output", "json",
	)
	require.Equal(t, 0, result.exitCode, result.output)
	afterTarget, err := os.ReadFile(sibling)
	require.NoError(t, err)
	afterSum, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Equal(t, beforeTarget, afterTarget)
	require.Contains(t, string(afterSum), repository+"/-/skills/beta v1.0.0 ")
	require.Contains(t, string(afterSum), repository+"/-/skills/alpha v1.1.0 ")
	require.Contains(t, string(afterSum), repository+"/-/skills/alpha v1.0.0 ")
	require.Greater(t, len(afterSum), len(beforeSum))
}
