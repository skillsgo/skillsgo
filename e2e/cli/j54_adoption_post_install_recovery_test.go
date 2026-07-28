/*
 * [INPUT]: Depends on the released CLI, a durable External recovery manifest, and managed state matching a process interruption after Package installation but before Trash handoff.
 * [OUTPUT]: Verifies retry restores the staged External over the interrupted managed Projection and completes reviewed adoption without losing bytes or corrupting Global state.
 * [POS]: Serves as the post-install crash-window adoption recovery journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ54RecoverAdoptionInterruptedAfterManagedInstall(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	external := filepath.Join(home, ".codex", "skills", "alpha")
	skillBytes := []byte("---\nname: alpha\ndescription: External Alpha.\n---\n# alpha\n")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), skillBytes, 0o644))

	recoveryRoot := filepath.Join(home, ".skillsgo", "recovery", "adopt", "post-install")
	backup := filepath.Join(recoveryRoot, "000-alpha")
	require.NoError(t, os.MkdirAll(recoveryRoot, 0o700))
	require.NoError(t, os.Rename(external, backup))
	manifest, err := json.Marshal(map[string]any{
		"schemaVersion": 1,
		"entries": []map[string]string{{
			"original": scenarioContainerPath(t, "home", ".codex", "skills", "alpha"),
			"backup":   scenarioContainerPath(t, "home", ".skillsgo", "recovery", "adopt", "post-install", "000-alpha"),
		}},
	})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(recoveryRoot, "recovery.json"), manifest, 0o600))

	installed := execCLI(t, ctx, container,
		"add", "fixtures.test/group/subgroup/collection@v1.0.0",
		"--global", "--skill-path", "skills/alpha", "--agent", "codex", "--yes", "--output", "json",
	)
	require.Equal(t, 0, installed.exitCode, installed.output)
	managedInfo, err := os.Lstat(external)
	require.NoError(t, err)
	require.NotZero(t, managedInfo.Mode()&os.ModeSymlink)

	request := adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:post-install-alpha", "alpha", "skills/alpha", "v1.0.0",
			adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
		)},
	}
	report := executeAdoption(t, ctx, container, sandboxRoot, request)
	require.Len(t, report.Results, 1)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	require.NoDirExists(t, recoveryRoot)
	after, err := os.ReadFile(filepath.Join(external, "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(after), "Alpha")
	finalInfo, err := os.Lstat(external)
	require.NoError(t, err)
	require.NotZero(t, finalInfo.Mode()&os.ModeSymlink)
	require.FileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.FileExists(t, filepath.Join(home, ".agents", "skills-lock.yaml"))
}
