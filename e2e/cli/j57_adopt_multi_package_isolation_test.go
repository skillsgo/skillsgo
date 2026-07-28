/*
 * [INPUT]: Depends on the released CLI, two reviewed External Skills mapped to independent Package groups, one valid immutable Package, and one unavailable Package.
 * [OUTPUT]: Verifies adopt commits the valid Package group, leaves the failed group's External bytes in place, and publishes no failed Package declaration.
 * [POS]: Serves as the multi-Package saga-isolation journey for reviewed adoption.
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

func TestJ57AdoptIsolatesIndependentPackageGroups(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	valid := filepath.Join(home, ".codex", "skills", "alpha")
	unavailable := filepath.Join(home, ".codex", "skills", "other")
	for path, name := range map[string]string{valid: "alpha", unavailable: "other"} {
		require.NoError(t, os.MkdirAll(path, 0o755))
		contents := []byte("---\nname: " + name + "\ndescription: External " + name + ".\n---\n")
		require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), contents, 0o644))
	}

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{
			fixtureAdoptionItem(
				"external:valid-alpha", "alpha", "skills/alpha", "v1.0.0",
				adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
			),
			{
				InventoryKey: "external:unavailable-other",
				Name:         "other",
				PackagePath:  "fixtures.test/group/subgroup/missing",
				Version:      "v1.0.0",
				SkillPath:    "skills/other",
				Targets: []adoptionTargetJSON{{
					Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "other"),
				}},
			},
		},
	})
	require.Len(t, report.Results, 2)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	require.Equal(t, "failed", report.Results[1].Status)
	require.Contains(t, report.Results[1].Reason, "install-prepare-failed")
	validInfo, err := os.Lstat(valid)
	require.NoError(t, err)
	require.NotZero(t, validInfo.Mode()&os.ModeSymlink)
	require.FileExists(t, filepath.Join(valid, "SKILL.md"))
	require.FileExists(t, filepath.Join(unavailable, "SKILL.md"))
	manifest := mustReadFile(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.Contains(t, string(manifest), "fixtures.test/group/subgroup/collection")
	require.NotContains(t, string(manifest), "fixtures.test/group/subgroup/missing")
}
