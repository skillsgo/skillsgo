/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J10 exact Agent-binding removal.
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

func TestJ10RemoveOneBinding(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
		"--agent", "codex",
		"--agent", "claude-code",
		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.Len(t, installed.Projections, 2)
	var codexTarget, claudeTarget string
	for _, projection := range installed.Projections {
		if projection.Agents[0] == "codex" {
			codexTarget = containerPathOnHost(t, sandboxRoot, projection.Path)
		} else if projection.Agents[0] == "claude-code" {
			claudeTarget = containerPathOnHost(t, sandboxRoot, projection.Path)
		}
	}
	require.FileExists(t, filepath.Join(codexTarget, "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(claudeTarget, "skills", "alpha", "SKILL.md"))

	removeClaude := execCLI(t, ctx, container,
		"remove", "alpha",
		"--agent", "claude-code",
		"--yes",
		"--ui", "plain",
		"--color", "never",
	)
	require.Equal(t, 0, removeClaude.exitCode, removeClaude.output)
	_, err := os.Lstat(claudeTarget)
	require.ErrorIs(t, err, os.ErrNotExist)
	require.FileExists(t, filepath.Join(codexTarget, "skills", "alpha", "SKILL.md"))

	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "codex")
	require.NotContains(t, string(manifest), "claude-code")
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Vendor, "skills", "alpha", "SKILL.md"))
}
