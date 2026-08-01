/*
 * [INPUT]: Depends on the released CLI, a real Git-backed External Skill directory, the fixture Hub Package, and durable adoption recovery.
 * [OUTPUT]: Verifies adoption treats a user Git directory as opaque bytes, preserves uncommitted metadata, and restores the exact directory through the public recovery command.
 * [POS]: Serves as the direct-Git External adoption and recovery journey in the cross-product E2E workspace.
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

func TestJ58AdoptAndRestoreGitBackedExternalDirectory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	external := filepath.Join(home, ".codex", "skills", "alpha")
	skillBytes := []byte("---\nname: alpha\ndescription: Git-backed external fixture\n---\n# alpha\n")
	require.NoError(t, os.MkdirAll(external, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(external, "SKILL.md"), skillBytes, 0o644))
	containerExternal := scenarioContainerPath(t, "home", ".codex", "skills", "alpha")
	for _, args := range [][]string{
		{"git", "-C", containerExternal, "init"},
		{"git", "-C", containerExternal, "config", "user.name", "SkillsGo E2E"},
		{"git", "-C", containerExternal, "config", "user.email", "skillsgo-e2e@example.invalid"},
		{"git", "-C", containerExternal, "add", "SKILL.md"},
		{"git", "-C", containerExternal, "commit", "-m", "initial Skill"},
	} {
		result := execInContainer(t, ctx, container, args...)
		require.Equal(t, 0, result.exitCode, result.output)
	}
	// Leave an uncommitted user file behind so recovery proves it did not flatten Git state.
	require.NoError(t, os.WriteFile(filepath.Join(external, "notes.md"), []byte("uncommitted note\n"), 0o600))

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:git-alpha", "alpha", "skills/alpha", "v1.0.0",
			adoptionTargetJSON{Agent: "codex", Scope: "global", Path: containerExternal},
		)},
	})
	require.Len(t, report.Results, 1)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	require.NotEmpty(t, report.Results[0].BackupID)
	managedInfo, err := os.Lstat(external)
	require.NoError(t, err)
	require.NotZero(t, managedInfo.Mode()&os.ModeSymlink)

	restore := execCLI(t, ctx, container,
		"recovery", "restore", "--backup-id", report.Results[0].BackupID,
		"--yes", "--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)
	restoredInfo, err := os.Lstat(external)
	require.NoError(t, err)
	require.True(t, restoredInfo.IsDir())
	require.Zero(t, restoredInfo.Mode()&os.ModeSymlink)
	require.Equal(t, skillBytes, mustReadAdoptionFile(t, filepath.Join(external, "SKILL.md")))
	require.Equal(t, []byte("uncommitted note\n"), mustReadAdoptionFile(t, filepath.Join(external, "notes.md")))
	status := execInContainer(t, ctx, container, "git", "-C", containerExternal, "status", "--short")
	require.Equal(t, 0, status.exitCode, status.output)
	require.Contains(t, status.output, "?? notes.md")
	branch := execInContainer(t, ctx, container, "git", "-C", containerExternal, "branch", "--show-current")
	require.Equal(t, 0, branch.exitCode, branch.output)
	require.NotEmpty(t, branch.output)
}

func mustReadAdoptionFile(t *testing.T, path string) []byte {
	t.Helper()
	contents, err := os.ReadFile(path)
	require.NoError(t, err)
	return contents
}
