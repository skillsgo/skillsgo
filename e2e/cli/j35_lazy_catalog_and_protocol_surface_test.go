/*
 * [INPUT]: Depends on an initially empty Catalog, public Package Version Skill demand publication, ordinary CLI add, canonical Package routes, and legacy route absence.
 * [OUTPUT]: Provides black-box coverage that a version-scoped Skill read populates Catalog while the maintained protocol excludes resolve, manifest, and skillsgo resources.
 * [POS]: Serves as lazy Catalog visibility and protocol-contraction coverage in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ35LazyCatalogAndProtocolSurface(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	repository := "fixtures.test/group/subgroup/collection"
	detailURL := "http://127.0.0.1:3000/api/v1/" + repository + "/versions/v1.0.0/skills?path=skills/alpha"
	cold := execInContainer(t, ctx, container, "wget", "-qO-", detailURL)
	require.Equal(t, 0, cold.exitCode, cold.output)
	require.Contains(t, cold.output, `"path":"skills/alpha"`)

	add := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "alpha",
		"--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	canonical := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/api/v1/"+repository+"/versions/v1.0.0")
	require.Equal(t, 0, canonical.exitCode, canonical.output)
	for _, path := range []string{
		"/" + repository + "/@resolve?selector=latest",
		"/" + repository + "/versions/v1.0.0.manifest",
		"/" + repository + "/versions/v1.0.0.skillsgo",
	} {
		legacy := execInContainer(t, ctx, container, "wget", "-S", "-qO-", "http://127.0.0.1:3000"+path)
		require.NotEqual(t, 0, legacy.exitCode, path+" unexpectedly succeeded: "+legacy.output)
		require.Contains(t, legacy.output, http.StatusText(http.StatusNotFound))
	}
}
