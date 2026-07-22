/*
 * [INPUT]: Depends on two independently locked Repository dependencies, verified ordinary-file Vendors, missing projections, one locally modified Vendor, and offline `skillsgo install`.
 * [OUTPUT]: Proves independent Repository installation groups retain a successful restoration beside one failed Local Modification group and return non-zero status with per-group results.
 * [POS]: Serves as the black-box partial-mutation contract for independent installation groups.
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

func TestJ39InstallationPartialFailure(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	for _, dependency := range []struct{ repository, skill string }{
		{"collection", "skills/alpha"},
		{"mixed", "skills/alpha"},
	} {
		result := execCLI(t, ctx, container, "add", "https://fixtures.test/group/subgroup/"+dependency.repository+"@v1.0.0", "--skill", dependency.skill, "--agent", "codex", "--output", "json")
		require.Equal(t, 0, result.exitCode, result.output)
	}
	collectionCoordinate := filepath.Join("fixtures.test", "group", "subgroup", "collection@v1.0.0")
	mixedCoordinate := filepath.Join("fixtures.test", "group", "subgroup", "mixed@v1.0.0")
	collectionProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", collectionCoordinate)
	mixedProjection := filepath.Join(sandboxRoot, "project", ".agents", "skills", mixedCoordinate)
	require.NoError(t, os.RemoveAll(collectionProjection))
	require.NoError(t, os.RemoveAll(mixedProjection))
	mixedVendorSkill := filepath.Join(sandboxRoot, "project", ".skillsgo", "vendor", mixedCoordinate, "skills", "alpha", "SKILL.md")
	const localChange = "locally modified Vendor bytes\n"
	require.NoError(t, os.WriteFile(mixedVendorSkill, []byte(localChange), 0o644))

	install := execCLI(t, ctx, container, "install", "--hub", "http://127.0.0.1:1", "--output", "json")
	require.NotEqual(t, 0, install.exitCode, install.output)
	require.Contains(t, install.output, `"repository": "fixtures.test/group/subgroup/collection"`)
	require.Contains(t, install.output, `"status": "restored"`)
	require.Contains(t, install.output, `"repository": "fixtures.test/group/subgroup/mixed"`)
	require.Contains(t, install.output, `"status": "failed"`)
	require.Contains(t, install.output, "Local Modification")
	require.FileExists(t, filepath.Join(collectionProjection, "skills", "alpha", "SKILL.md"))
	require.NoDirExists(t, mixedProjection)
	unchanged, err := os.ReadFile(mixedVendorSkill)
	require.NoError(t, err)
	require.Equal(t, localChange, string(unchanged))
}
