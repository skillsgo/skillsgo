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
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.Len(t, installed.Targets, 2)

	canonical := filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha")
	claudeTarget := filepath.Join(sandboxRoot, "project", ".claude", "skills", "alpha")
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))
	claudeInfo, err := os.Lstat(claudeTarget)
	require.NoError(t, err)
	require.NotZero(t, claudeInfo.Mode()&os.ModeSymlink)
	claudeLink, err := os.Readlink(claudeTarget)
	require.NoError(t, err)
	require.Equal(t, "../../.agents/skills/alpha", claudeLink)
	require.Equal(t, canonical, filepath.Clean(filepath.Join(filepath.Dir(claudeTarget), claudeLink)))

	removeClaude := execCLI(t, ctx, container,
		"remove", "alpha",
		"--agent", "claude-code",
		"--yes",
		"--ui", "plain",
		"--color", "never",
	)
	require.Equal(t, 0, removeClaude.exitCode, removeClaude.output)
	_, err = os.Lstat(claudeTarget)
	require.ErrorIs(t, err, os.ErrNotExist)
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))

	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "codex")
	require.NotContains(t, string(manifest), "claude-code")
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Store, "artifact", "SKILL.md"))
}
