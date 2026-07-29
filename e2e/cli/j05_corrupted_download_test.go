/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J05 atomic corrupted-Pack rejection while restoring the shared suite Git Artifact afterward.
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
		"add", testPackagePath+"@"+testSkillVersion, "--skill", testSkillName,
		"--agent", "codex",

		"--yes",

		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)

	manifestPath := filepath.Join(sandboxRoot, "project", "skills.yaml")
	sumPath := filepath.Join(sandboxRoot, "project", "skills-lock.yaml")
	manifestBefore, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)

	hubPack := findStoredRepositoryArtifact(t, filepath.Join(suite.sandboxRoot, "hub", "storage", "packages"), installed.PackagePath, ".pack")
	originalPack, err := os.ReadFile(hubPack)
	require.NoError(t, err)
	t.Cleanup(func() {
		require.NoError(t, os.WriteFile(hubPack, originalPack, 0o600))
	})
	require.NoError(t, os.WriteFile(hubPack, []byte("corrupted e2e artifact"), 0o600))
	require.NoError(t, os.RemoveAll(containerPathOnHost(t, sandboxRoot, installed.PackageDir)))
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "home", ".skillsgo", "cache", "packages")))

	restore := execCLI(t, ctx, container, "install", "--output", "json")
	require.NotEqual(t, 0, restore.exitCode, "corrupted Hub artifact unexpectedly restored: %s", restore.output)

	require.NoDirExists(t, containerPathOnHost(t, sandboxRoot, installed.Projections[0].Path))
	require.NoDirExists(t, containerPathOnHost(t, sandboxRoot, installed.PackageDir))
	manifestAfter, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter, "failed restoration must not rewrite skills.yaml")
	require.Equal(t, sumBefore, sumAfter, "failed restoration must not rewrite skills-lock.yaml")
}
