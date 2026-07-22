/*
 * [INPUT]: Depends on the deterministic multi-Skill collection Repository, released whole-Repository add, default symlink mode, and a conflicting later Agent target.
 * [OUTPUT]: Provides black-box coverage that a failed whole-Repository add preserves the external target and rolls back every new target, Manifest, Sum, and Receipt.
 * [POS]: Serves as the Repository publication installation-atomicity journey across Hub, CLI, and Workspace state.
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

func TestJ46RepositoryAddIsAtomic(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	externalTarget := filepath.Join(sandboxRoot, "project", ".agents", "skills", "beta")
	require.NoError(t, os.MkdirAll(externalTarget, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(externalTarget, "external.txt"), []byte("keep\n"), 0o600))

	result := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/collection@v1.0.0",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.NotEqual(t, 0, result.exitCode, result.output)

	require.FileExists(t, filepath.Join(externalTarget, "external.txt"))
	for _, name := range []string{"root-suite", "alpha", "camel-case", "naming"} {
		require.NoFileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", name, "SKILL.md"))
	}
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".skillsgo", "receipts"))
}
