/*
 * [INPUT]: Depends on the deterministic multi-Skill collection Repository, released whole-Repository add, and a conflicting coordinate Projection target.
 * [OUTPUT]: Provides black-box coverage that a failed whole-Repository add preserves the external path and rolls back Vendor, Projection, YAML, and Lock publication.
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
	coordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	externalTarget := filepath.Join(sandboxRoot, "project", ".agents", "skills", coordinate)
	require.NoError(t, os.MkdirAll(externalTarget, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(externalTarget, "external.txt"), []byte("keep\n"), 0o600))

	result := execCLI(t, ctx, container,
		"add", "https://fixtures.test/group/subgroup/collection@v1.0.0",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.NotEqual(t, 0, result.exitCode, result.output)

	require.FileExists(t, filepath.Join(externalTarget, "external.txt"))
	require.NoFileExists(t, filepath.Join(externalTarget, "SKILL.md"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".skillsgo", "vendor", coordinate))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "project", "skillsgo.lock"))
}
