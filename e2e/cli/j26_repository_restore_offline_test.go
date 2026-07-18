/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, Manifest, Sum, Info Cache, Store, and Agent filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for complete whole-Repository restoration while the Hub is unavailable.
 * [POS]: Serves as the Repository expansion recovery journey in the cross-product E2E workspace.
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

func TestJ26RepositoryRestoreOffline(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/collection@v1.0.0",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	manifestBefore, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	sumBefore, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Contains(t, string(manifestBefore), "fixtures.test/group/subgroup/collection ")
	require.NotContains(t, string(manifestBefore), "/-/")

	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))
	restore := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)
	for _, name := range []string{"root-suite", "alpha", "beta"} {
		require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", name, "SKILL.md"))
	}
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "invalid"))
	manifestAfter, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	sumAfter, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Equal(t, manifestBefore, manifestAfter)
	require.Equal(t, sumBefore, sumAfter)
}
