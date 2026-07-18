/*
 * [INPUT]: Depends on deterministic tagged, prerelease-only, and untagged Git fixture Repositories plus public CLI persistence.
 * [OUTPUT]: Provides black-box coverage for stable-first latest, prerelease fallback, and default-branch pseudo-version selection.
 * [POS]: Serves as the Repository Version Query selection journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ28RepositoryVersionSelection(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	stable := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/collection", "--agent", "codex", "--copy", "--yes", "--output", "json")
	require.Equal(t, 0, stable.exitCode, stable.output)
	manifest, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/collection v1.1.0")
	require.NotContains(t, string(manifest), "v1.1.0-beta.1")

	resetLocalInstallation(t, sandboxRoot)
	preview := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/prerelease", "--agent", "codex", "--copy", "--yes", "--output", "json")
	require.Equal(t, 0, preview.exitCode, preview.output)
	manifest, err = os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/prerelease v1.2.0-beta.2")

	resetLocalInstallation(t, sandboxRoot)
	untagged := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/untagged", "--agent", "codex", "--copy", "--yes", "--output", "json")
	require.Equal(t, 0, untagged.exitCode, untagged.output)
	manifest, err = os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.NotContains(t, string(manifest), ": main")
	require.Regexp(t, regexp.MustCompile(`fixtures\.test/group/subgroup/untagged v0\.0\.0-\d{14}-[0-9a-f]{12}`), string(manifest))
}
