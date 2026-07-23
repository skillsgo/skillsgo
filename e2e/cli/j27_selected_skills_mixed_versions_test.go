/*
 * [INPUT]: Depends on the disposable E2E environment and the Repository-wide version plus repeated --skill selection contract.
 * [OUTPUT]: Provides black-box coverage that per-Skill versions are rejected atomically while multiple selected members inherit one resolved Repository version.
 * [POS]: Serves as the selected-member version-consistency journey in the cross-product E2E workspace.
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

func TestJ27SelectedSkillsShareRepositoryVersion(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	result := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/mixed@v1.0.0",
		"--skill", "alpha",
		"--skill", "skills/beta@v1.1.0",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.NotEqual(t, 0, result.exitCode, result.output)
	require.Contains(t, result.output, "per-Skill version selectors are unsupported")
	requireNoLocalInstallation(t, sandboxRoot)

	head := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/mixed@head", "--skill", "alpha", "--skill", "beta",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, head.exitCode, head.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(head.output), &installed), head.output)
	headSkill, err := os.ReadFile(containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(headSkill), "Alpha v2.")
	beta, err := os.ReadFile(containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path, "skills", "beta", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(beta), "Beta v2.")
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "version: "+installed.Version)
	require.Contains(t, string(manifest), "- skills/alpha")
	require.Contains(t, string(manifest), "- skills/beta")
}
