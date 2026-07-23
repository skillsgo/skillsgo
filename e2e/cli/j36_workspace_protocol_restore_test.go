/*
 * [INPUT]: Depends on a disposable E2E environment, public CLI add/install commands, namespaced Hub HTTP routes, and portable Workspace files.
 * [OUTPUT]: Provides black-box coverage for portable YAML/Lock syntax, multi-Agent restoration, root Proxy and /api/v1 separation, and /mod removal.
 * [POS]: Serves as the breaking module/API namespace migration contract in the cross-product E2E workspace.
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

func TestJ36WorkspaceProtocolAndRestore(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testRepositoryID+"@"+testSkillVersion, "--skill", testSkillName,
		"--agent", "codex",
		"--agent", "claude-code",
		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.NotEmpty(t, installed.Version)

	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.yaml")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Contains(t, string(manifestBefore), installed.Repository+":")
	require.Contains(t, string(manifestBefore), "version: "+installed.Version)
	require.Contains(t, string(manifestBefore), "- alpha")
	require.Contains(t, string(manifestBefore), "- claude-code")
	require.Contains(t, string(manifestBefore), "- codex")
	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo-lock.yaml")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)

	proxyInfo := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/"+installed.Repository+"/@v/"+installed.Version+".info")
	require.Equal(t, 0, proxyInfo.exitCode, proxyInfo.output)
	apiDetail := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/api/v1/skills/detail?repositoryId="+installed.Repository+"&name="+testSkillName)
	require.Equal(t, 0, apiDetail.exitCode, apiDetail.output)
	for _, legacyURL := range []string{
		"http://127.0.0.1:3000/mod/" + installed.Repository + "/@v/" + installed.Version + ".info",
		"http://127.0.0.1:3000/" + installed.Repository + "/-/skills/alpha/@v/" + installed.Version + ".info",
		"http://127.0.0.1:3000/v1/skills/" + installed.Repository + "/-/skills/alpha",
	} {
		legacy := execInContainer(t, ctx, container, "wget", "-S", "-qO-", legacyURL)
		require.NotEqual(t, 0, legacy.exitCode, legacyURL+" unexpectedly succeeded: "+legacy.output)
	}

	removeTargets := execInContainer(t, ctx, container, "rm", "-rf", "/e2e/project/.agents", "/e2e/project/.claude")
	require.Equal(t, 0, removeTargets.exitCode, removeTargets.output)
	restore := execCLI(t, ctx, container, "install", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)
	for _, projection := range installed.Projections {
		require.FileExists(t, containerPathOnHost(t, sandboxRoot, projection.Path, "skills", "alpha", "SKILL.md"))
	}

	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfter)
}
