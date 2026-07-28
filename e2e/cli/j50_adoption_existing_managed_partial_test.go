/*
 * [INPUT]: Depends on the released CLI, an already managed Global Package member, a duplicate External directory, and an independent broken Project link.
 * [OUTPUT]: Verifies idempotent External retirement for an existing coordinate and per-destination failure isolation in one reviewed adoption request.
 * [POS]: Serves as the existing-managed and partial-adoption user journey in the cross-product E2E workspace.
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

func TestJ50RetireDuplicateExternalBesideExistingManagedCoordinateAndIsolateFailure(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	installed := execCLI(t, ctx, container,
		"add", "fixtures.test/group/subgroup/collection@v1.0.0",
		"--skill-path", "skills/alpha", "--agent", "codex", "--global", "--output", "json",
	)
	require.Equal(t, 0, installed.exitCode, installed.output)

	home := filepath.Join(sandboxRoot, "home")
	external := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), []byte("---\nname: alpha\ndescription: old external copy\n---\n"), 0o644))
	project := filepath.Join(sandboxRoot, "project")
	broken := filepath.Join(project, ".codex", "skills", "beta")
	require.NoError(t, os.MkdirAll(filepath.Dir(broken), 0o755))
	require.NoError(t, os.Symlink("../../missing/beta", broken))

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{
			fixtureAdoptionItem(
				"external:duplicate-alpha", "alpha", "skills/alpha", "v1.0.0",
				adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
			),
			fixtureAdoptionItem(
				"external:broken-beta", "beta", "skills/beta", "v1.0.0",
				adoptionTargetJSON{Agent: "codex", Scope: "project", ProjectRoot: scenarioContainerPath(t, "project"), Path: scenarioContainerPath(t, "project", ".codex", "skills", "beta")},
			),
		},
	})
	require.Len(t, report.Results, 2)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	require.Equal(t, "failed", report.Results[1].Status)
	require.Contains(t, report.Results[1].Reason, "external skill is unavailable")
	require.NoDirExists(t, external)
	info, err := os.Lstat(broken)
	require.NoError(t, err)
	require.NotZero(t, info.Mode()&os.ModeSymlink)
	require.FileExists(t, filepath.Join(home, ".codex", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.FileExists(t, filepath.Join(home, ".agents", "skills-lock.yaml"))
	require.NoFileExists(t, filepath.Join(project, "skills.yaml"))
}
