/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J05 atomic corrupted-download rejection.
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

func TestJ05CorruptedDownload(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@main",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	manifestPath := filepath.Join(sandboxRoot, "project", "skillsgo.yaml")
	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)

	hubZIP := findArtifactFile(t, filepath.Join(sandboxRoot, "hub", "storage"), testSkillID, ".zip")
	require.NoError(t, os.WriteFile(hubZIP, []byte("corrupted e2e artifact"), 0o600))
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "home", ".skillsgo", "store")))
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))

	restore := execCLI(t, ctx, container, "install", "--output", "json")
	require.NotEqual(t, 0, restore.exitCode, "corrupted Hub artifact unexpectedly restored: %s", restore.output)

	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt"))
	require.NoDirExists(t, containerPathOnHost(t, sandboxRoot, installed.Store))
	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter, "failed restoration must not rewrite skillsgo.yaml")
	require.Equal(t, sumBefore, sumAfter, "failed restoration must not rewrite skillsgo.sum")
}
