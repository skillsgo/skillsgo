/*
 * [INPUT]: Depends on a disposable E2E environment, public CLI add/install commands, namespaced Hub HTTP routes, and portable Workspace files.
 * [OUTPUT]: Provides black-box coverage for skillsgo.mod syntax, multi-Agent restoration, /mod and /api/v1 availability, and legacy route removal.
 * [POS]: Serves as the breaking module/API namespace migration contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ36ModNamespaceAndRestore(t *testing.T) {
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
	require.NotEmpty(t, installed.Version)

	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.mod")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Equal(t,
		"require (\n\t"+testSkillID+" "+installed.Version+" [codex, claude-code]\n)\n",
		string(manifestBefore),
	)
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)

	modInfo := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/mod/"+testSkillID+"/@v/"+installed.Version+".info")
	require.Equal(t, 0, modInfo.exitCode, modInfo.output)
	apiDetail := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/api/v1/skills/"+testSkillID)
	require.Equal(t, 0, apiDetail.exitCode, apiDetail.output)
	for _, legacyURL := range []string{
		"http://127.0.0.1:3000/" + testSkillID + "/@v/" + installed.Version + ".info",
		"http://127.0.0.1:3000/v1/skills/" + testSkillID,
	} {
		legacy := execInContainer(t, ctx, container, "wget", "-S", "-qO-", legacyURL)
		require.NotEqual(t, 0, legacy.exitCode, legacyURL+" unexpectedly succeeded: "+legacy.output)
		require.Contains(t, legacy.output, http.StatusText(http.StatusNotFound))
	}

	removeTargets := execInContainer(t, ctx, container, "rm", "-rf", "/e2e/project/.agents", "/e2e/project/.claude")
	require.Equal(t, 0, removeTargets.exitCode, removeTargets.output)
	restore := execCLI(t, ctx, container, "install", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	claudeTarget := filepath.Join(sandboxRoot, "project", ".claude", "skills", "alpha")
	claudeInfo, err := os.Lstat(claudeTarget)
	require.NoError(t, err)
	require.NotZero(t, claudeInfo.Mode()&os.ModeSymlink)

	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfter)
}
