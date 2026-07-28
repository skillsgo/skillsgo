/*
 * [INPUT]: Depends on the public SkillsGo-owned versioned Package, its immutable v1.2.0/v1.3.0 releases, Package-fresh latest resolution, and Scope-by-Package dry-run update previews.
 * [OUTPUT]: Provides black-box coverage that one installed Package receives its immutable latest candidate without mutation.
 * [POS]: Serves as the Catalog-fresh Package update-preview journey across the CLI and Hub.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ45CatalogFreshPackageUpdatePreview(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	const packagePath = "github.com/skillsgo/e2e-versioned-skills"

	installed := execCLI(t, ctx, container,
		"add", "https://"+packagePath+"@v1.2.0", "--skill", "alpha", "--agent", "codex", "--global", "--yes", "--output", "json",
	)
	require.Equal(t, 0, installed.exitCode, installed.output)

	checked := execCLI(t, ctx, container, "update", packagePath, "--global", "--dry-run", "--output", "json")
	require.Equal(t, 0, checked.exitCode, checked.output)

	var report struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		PackagePath   string `json:"packagePath"`
		FromVersion   string `json:"fromVersion"`
		ToVersion     string `json:"toVersion"`
		Status        string `json:"status"`
	}
	require.NoError(t, json.Unmarshal([]byte(checked.output), &report), checked.output)
	require.Equal(t, 1, report.SchemaVersion)
	require.Equal(t, "package-update-preview", report.Phase)
	require.Equal(t, packagePath, report.PackagePath)
	require.Equal(t, "v1.2.0", report.FromVersion)
	require.Equal(t, "v1.3.0", report.ToVersion)
	require.Equal(t, "update_available", report.Status)
}
