/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J19 deterministic immutable-artifact reuse.
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

func TestJ19ImmutableReuse(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@main",
		"--agent", "codex",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	artifactURL := "http://127.0.0.1:3000/mod/" + testSkillID + "/@v/" + installed.Version + ".zip"
	firstDownload := execInContainer(t, ctx, container,
		"wget", "-qO", "/e2e/artifacts/first.zip", artifactURL,
	)
	require.Equal(t, 0, firstDownload.exitCode, firstDownload.output)
	secondDownload := execInContainer(t, ctx, container,
		"wget", "-qO", "/e2e/artifacts/second.zip", artifactURL,
	)
	require.Equal(t, 0, secondDownload.exitCode, secondDownload.output)
	firstBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "artifacts", "first.zip"))
	require.NoError(t, err)
	secondBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "artifacts", "second.zip"))
	require.NoError(t, err)
	require.NotEmpty(t, firstBytes)
	require.Equal(t, firstBytes, secondBytes)

	secondTarget := execCLI(t, ctx, container,
		"add", testSkillID+"@"+installed.Version,
		"--agent", "claude-code",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, secondTarget.exitCode, secondTarget.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"))
	claudeInfo, err := os.Lstat(filepath.Join(sandboxRoot, "project", ".claude", "skills", "ask-matt"))
	require.NoError(t, err)
	require.NotZero(t, claudeInfo.Mode()&os.ModeSymlink)
	require.DirExists(t, containerPathOnHost(t, sandboxRoot, installed.Store))
}
