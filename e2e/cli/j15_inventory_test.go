/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J15 managed and External inventory.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
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

func TestJ15Inventory(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	targetPath := filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt")
	skillPath := filepath.Join(targetPath, "SKILL.md")
	require.NoError(t, os.MkdirAll(targetPath, 0o700))
	require.NoError(t, os.WriteFile(skillPath, []byte("---\nname: ask-matt\n---\n"), 0o600))

	managedAdd := execCLI(t, ctx, container,
		"add", testReplacementSkillID+"@main",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, managedAdd.exitCode, managedAdd.output)
	require.NoError(t, os.MkdirAll(filepath.Join(sandboxRoot, "home", ".codex"), 0o755))

	inventory := execCLI(t, ctx, container,
		"inventory", "--project", "/e2e/project", "--output", "json",
	)
	require.Equal(t, 0, inventory.exitCode, inventory.output)
	var report struct {
		SchemaVersion int `json:"schemaVersion"`
		Entries       []struct {
			Name       string `json:"name"`
			SkillID    string `json:"skillId"`
			Provenance string `json:"provenance"`
			Health     string `json:"health"`
			Targets    []struct {
				Path string `json:"path"`
			} `json:"targets"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal([]byte(inventory.output), &report), inventory.output)
	require.Equal(t, 5, report.SchemaVersion)
	require.Len(t, report.Entries, 2)
	entries := make(map[string]struct {
		SkillID    string
		Provenance string
		Health     string
		Path       string
	})
	for _, entry := range report.Entries {
		require.NotEmpty(t, entry.Targets)
		entries[entry.Name] = struct {
			SkillID    string
			Provenance string
			Health     string
			Path       string
		}{entry.SkillID, entry.Provenance, entry.Health, entry.Targets[0].Path}
	}
	require.Equal(t, "external", entries["ask-matt"].Provenance)
	require.Empty(t, entries["ask-matt"].SkillID)
	require.Equal(t, "/e2e/project/.agents/skills/ask-matt", entries["ask-matt"].Path)
	require.Equal(t, "hub", entries["find-skills"].Provenance)
	require.Equal(t, testReplacementSkillID, entries["find-skills"].SkillID)
	require.Equal(t, "healthy", entries["find-skills"].Health)
}
