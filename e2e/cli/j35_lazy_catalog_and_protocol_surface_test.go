/*
 * [INPUT]: Depends on an initially empty Catalog, ordinary CLI add, public Skill detail, canonical Repository protocol routes, and legacy route absence.
 * [OUTPUT]: Provides black-box coverage that demand discovery populates Catalog while the maintained protocol excludes resolve, manifest, and skillsgo resources.
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
	skillID := repository + "/-/skills/alpha"
	detailURL := "http://127.0.0.1:3000/api/v1/skills/" + skillID
	before := execInContainer(t, ctx, container, "wget", "-S", "-qO-", detailURL)
	require.NotEqual(t, 0, before.exitCode, before.output)

	add := execCLI(t, ctx, container,
		"add", "https://"+repository+"@v1.0.0", "--skill", "alpha",
		"--agent", "codex", "--copy", "--yes", "--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)
	after := execInContainer(t, ctx, container, "wget", "-qO-", detailURL)
	require.Equal(t, 0, after.exitCode, after.output)
	require.Contains(t, after.output, `"id":"`+skillID+`"`)

	canonical := execInContainer(t, ctx, container, "wget", "-qO-", "http://127.0.0.1:3000/mod/"+repository+"/@v/v1.0.0.info")
	require.Equal(t, 0, canonical.exitCode, canonical.output)
	for _, path := range []string{
		"/" + repository + "/@resolve?selector=latest",
		"/" + repository + "/@v/v1.0.0.manifest",
		"/" + repository + "/@v/v1.0.0.skillsgo",
	} {
		legacy := execInContainer(t, ctx, container, "wget", "-S", "-qO-", "http://127.0.0.1:3000"+path)
		require.NotEqual(t, 0, legacy.exitCode, path+" unexpectedly succeeded: "+legacy.output)
		require.Contains(t, legacy.output, http.StatusText(http.StatusNotFound))
	}
}
