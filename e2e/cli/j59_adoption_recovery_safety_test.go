/*
 * [INPUT]: Depends on the released CLI, a managed Global adoption, a user-replaced target, and the public adoption recovery commands.
 * [OUTPUT]: Verifies recovery refuses to overwrite a newly occupied user directory, retains the durable backup, and leaves the managed declaration available for a later retry.
 * [POS]: Serves as the occupied-target recovery safety journey in the cross-product E2E workspace.
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

func TestJ59RecoveryRefusesNewlyOccupiedExternalTarget(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	external := filepath.Join(home, ".codex", "skills", "alpha")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), []byte("---\nname: alpha\ndescription: original\n---\n"), 0o644))

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:occupied-alpha", "alpha", "skills/alpha", "v1.0.0",
			adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
		)},
	})
	require.Len(t, report.Results, 1)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	require.NotEmpty(t, report.Results[0].BackupID)

	// Simulate a user deleting the managed link and creating a new, unrelated directory.
	require.NoError(t, os.Remove(external))
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "user-data.txt"), []byte("do not overwrite\n"), 0o600))

	restore := execCLI(t, ctx, container,
		"recovery", "restore", "--backup-id", report.Results[0].BackupID,
		"--yes", "--output", "json",
	)
	require.NotEqual(t, 0, restore.exitCode, restore.output)
	require.Contains(t, restore.output, "Local Modification")
	require.FileExists(t, filepath.Join(external, "user-data.txt"))
	require.FileExists(t, filepath.Join(home, ".agents", "skills.yaml"))

	listing := execCLI(t, ctx, container, "recovery", "list", "--output", "json")
	require.Equal(t, 0, listing.exitCode, listing.output)
	require.Contains(t, listing.output, report.Results[0].BackupID)
	require.Contains(t, listing.output, `"status":"ready"`)
}
