/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J09 multi-Agent installation.
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

func TestJ09MultiAgentInstall(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@main",
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

	canonical := filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt")
	claudeTarget := filepath.Join(sandboxRoot, "project", ".claude", "skills", "ask-matt")
	require.FileExists(t, filepath.Join(canonical, "SKILL.md"))
	claudeInfo, err := os.Lstat(claudeTarget)
	require.NoError(t, err)
	require.NotZero(t, claudeInfo.Mode()&os.ModeSymlink)
	claudeLink, err := os.Readlink(claudeTarget)
	require.NoError(t, err)
	require.Equal(t, "../../.agents/skills/ask-matt", claudeLink)
	require.Equal(t, canonical, filepath.Clean(filepath.Join(filepath.Dir(claudeTarget), claudeLink)))

}
