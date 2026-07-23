/*
 * [INPUT]: Depends on the released CLI, two isolated Codex user Skills, a supported skills.sh lock, and an external edit after preflight.
 * [OUTPUT]: Verifies per-Skill stale-plan isolation, partial takeover, preservation of changed bytes, complete successful metadata, and an exact one-item rescan.
 * [POS]: Serves as the changed-during-takeover failure user journey in the cross-product E2E workspace.
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

func TestJ41SkipChangedSkillWithoutLosingData(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	skillsRoot := filepath.Join(sandboxRoot, "home", ".codex", "skills")
	changedTarget, stableTarget := filepath.Join(skillsRoot, "changed"), filepath.Join(skillsRoot, "stable")
	require.NoError(t, os.MkdirAll(changedTarget, 0o755))
	require.NoError(t, os.MkdirAll(stableTarget, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(changedTarget, "SKILL.md"), []byte("---\nname: alpha\ndescription: Alpha at v1.\n---\n# alpha\n"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(stableTarget, "SKILL.md"), []byte("---\nname: beta\ndescription: Beta exists only at v1.\n---\n# beta\n"), 0o644))
	writeSkillsShUserLock(t, sandboxRoot, map[string]any{
		"changed": skillsShLockRecord("skills/alpha/SKILL.md"),
		"stable":  skillsShLockRecord("skills/beta/SKILL.md"),
	})

	preview := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, preview.exitCode, preview.output)
	var plan takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(preview.output), &plan), preview.output)
	require.Equal(t, 2, plan.Summary.Eligible, preview.output)
	require.Equal(t, 2, plan.Scopes.User.Eligible)

	changedBytes := []byte("---\nname: changed\ndescription: edited after review\n---\n# Keep my edits\n")
	changedPath := filepath.Join(skillsRoot, "changed", "SKILL.md")
	require.NoError(t, os.WriteFile(changedPath, changedBytes, 0o644))

	execution := execCLI(t, ctx, container,
		"takeover", "--plan", plan.PlanID, "--user", "--yes", "--output", "json",
	)
	require.Equal(t, 0, execution.exitCode, execution.output)
	var report takeoverExecutionJSON
	require.NoError(t, json.Unmarshal([]byte(execution.output), &report), execution.output)
	require.Equal(t, 1, report.Summary.TakenOver, execution.output)
	require.Equal(t, 1, report.Summary.Skipped)
	require.Len(t, report.Results, 2)

	var changedResult, stableResult *struct {
		SkillID string `json:"skillId"`
		Status  string `json:"status"`
		Reason  string `json:"reason"`
		Target  struct {
			Path string `json:"path"`
		} `json:"target"`
	}
	for index := range report.Results {
		result := &report.Results[index]
		switch filepath.Base(result.Target.Path) {
		case "changed":
			changedResult = result
		case "stable":
			stableResult = result
		}
	}
	require.NotNil(t, changedResult)
	require.Equal(t, "skipped", changedResult.Status)
	require.Equal(t, "target-changed", changedResult.Reason)
	require.NotNil(t, stableResult)
	require.Equal(t, "taken-over", stableResult.Status)
	require.Equal(t, "fixtures.test/group/subgroup/collection/-/skills/beta", stableResult.SkillID)

	afterChanged, err := os.ReadFile(changedPath)
	require.NoError(t, err)
	require.Equal(t, changedBytes, afterChanged, "a stale plan must never overwrite user edits")
	stateRoot := filepath.Join(sandboxRoot, "home", ".skillsgo")
	require.DirExists(t, filepath.Join(stateRoot, "vendor"))
	require.FileExists(t, filepath.Join(stateRoot, "skillsgo.yaml"))
	require.FileExists(t, filepath.Join(stateRoot, "skillsgo.lock"))

	rescan := execCLI(t, ctx, container, "takeover", "--preflight", "--user", "--output", "json")
	require.Equal(t, 0, rescan.exitCode, rescan.output)
	var rescanned takeoverPreflightJSON
	require.NoError(t, json.Unmarshal([]byte(rescan.output), &rescanned), rescan.output)
	require.Equal(t, 1, rescanned.Summary.Eligible)
	require.Equal(t, 1, rescanned.Scopes.User.Eligible)
}
