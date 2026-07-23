/*
 * [INPUT]: Depends on the released CLI, an isolated Codex user Skill, and a supported skills.sh user lock.
 * [OUTPUT]: Verifies preflight counts, content-preserving takeover, complete SkillsGo metadata, managed inventory, and a zero-count rescan.
 * [POS]: Serves as the successful existing-Skill takeover user journey in the cross-product E2E workspace.
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

func TestJ40TakeOverExistingSkillAndRescan(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	targetRoot := filepath.Join(sandboxRoot, "home", ".codex", "skills", "demo")
	skillBytes := []byte("---\nname: alpha\ndescription: Alpha at v1.\n---\n# alpha\n")
	require.NoError(t, os.MkdirAll(targetRoot, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(targetRoot, "SKILL.md"), skillBytes, 0o644))
	writeSkillsShUserLock(t, sandboxRoot, map[string]any{
		"demo": skillsShLockRecord("skills/alpha/SKILL.md"),
	})

	preview := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, preview.exitCode, preview.output)
	var plan takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(preview.output), &plan), preview.output)
	require.Len(t, plan.PlanID, 64)
	require.Equal(t, 1, plan.Summary.Eligible, preview.output)
	require.Equal(t, 1, plan.Scopes.User.Eligible)
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "vendor"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "skillsgo.yaml"))
	require.NoFileExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "skillsgo-lock.yaml"))

	execution := execCLI(t, ctx, container,
		"takeover", "--plan", plan.PlanID, "--user", "--yes", "--output", "json",
	)
	require.Equal(t, 0, execution.exitCode, execution.output)
	var report takeoverExecutionJSON
	require.NoError(t, json.Unmarshal([]byte(execution.output), &report), execution.output)
	require.Equal(t, 1, report.Summary.TakenOver, execution.output)
	require.Zero(t, report.Summary.Skipped)
	require.Len(t, report.Results, 1)
	require.Equal(t, "taken-over", report.Results[0].Status)
	require.Equal(t, "fixtures.test/group/subgroup/collection/-/skills/alpha", report.Results[0].SkillID)

	require.NoDirExists(t, targetRoot)
	projection := filepath.Join(sandboxRoot, "home", ".codex", "skills", "fixtures.test", "group", "subgroup", "collection@v1.0.0", "skills", "alpha")
	afterSkill, err := os.ReadFile(filepath.Join(projection, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, skillBytes, afterSkill)

	stateRoot := filepath.Join(sandboxRoot, "home", ".skillsgo")
	require.DirExists(t, filepath.Join(stateRoot, "vendor"))
	require.FileExists(t, filepath.Join(stateRoot, "skillsgo.yaml"))
	require.FileExists(t, filepath.Join(stateRoot, "skillsgo-lock.yaml"))

	inventory := execCLI(t, ctx, container, "inventory", "--user", "--output", "json")
	require.Equal(t, 0, inventory.exitCode, inventory.output)
	var inventoryReport struct {
		Entries []struct {
			Name       string `json:"name"`
			Provenance string `json:"provenance"`
			Health     string `json:"health"`
		} `json:"entries"`
	}
	require.NoError(t, json.Unmarshal([]byte(inventory.output), &inventoryReport), inventory.output)
	require.Len(t, inventoryReport.Entries, 1)
	require.Equal(t, "alpha", inventoryReport.Entries[0].Name)
	require.Equal(t, "hub", inventoryReport.Entries[0].Provenance)
	require.Equal(t, "healthy", inventoryReport.Entries[0].Health)

	rescan := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, rescan.exitCode, rescan.output)
	var rescanned takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(rescan.output), &rescanned), rescan.output)
	require.Zero(t, rescanned.Summary.Eligible)
	require.Zero(t, rescanned.Scopes.User.Eligible)
}

type takeoverPreflightJSON struct {
	PlanID  string `json:"planId"`
	Summary struct {
		Eligible int `json:"eligible"`
		Skipped  int `json:"skipped"`
	} `json:"summary"`
	Scopes struct {
		User struct {
			Eligible int `json:"eligible"`
		} `json:"user"`
	} `json:"scopes"`
}

type takeoverExecutionJSON struct {
	Summary struct {
		TakenOver int `json:"takenOver"`
		Skipped   int `json:"skipped"`
	} `json:"summary"`
	Results []struct {
		SkillID string `json:"skillId"`
		Status  string `json:"status"`
		Reason  string `json:"reason"`
		Target  struct {
			Path string `json:"path"`
		} `json:"target"`
	} `json:"results"`
}

func skillsShLockRecord(skillPath string) map[string]any {
	return map[string]any{
		"source":      "fixture-collection",
		"sourceType":  "git",
		"sourceUrl":   "https://fixtures.test/group/subgroup/collection",
		"ref":         "v1.0.0",
		"skillPath":   skillPath,
		"installedAt": "2026-01-01T00:00:00Z",
		"updatedAt":   "2026-01-01T00:00:00Z",
	}
}

func writeSkillsShUserLock(t *testing.T, sandboxRoot string, skills map[string]any) {
	t.Helper()
	lockRoot := filepath.Join(sandboxRoot, "home", ".agents")
	require.NoError(t, os.MkdirAll(lockRoot, 0o700))
	data, err := json.Marshal(map[string]any{"version": 3, "skills": skills})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(lockRoot, ".skill-lock.json"), data, 0o600))
}
