/*
 * [INPUT]: Uses command.Execute with exact managed targets, temporary Store receipts, filesystem drift, and Workspace metadata.
 * [OUTPUT]: Specifies exact-target removal, unsafe-remove blocking, Repair, Stop Managing content preservation, Store retention, and machine progress/results.
 * [POS]: Serves as the public CLI contract coverage for App-driven Target Management Plans.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestManagementPlanRemovesOnlyTheExactSelectedTargetAndRetainsStore(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	testAgentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", testAgentHome)
	skillID := "github.com/example/skills/-/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	entry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
	targets := []install.Target{
		{Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeSymlink, Path: filepath.Join(testAgentHome, "skills", "demo")},
		{Agent: "codex", Scope: install.ScopeUser, Mode: install.ModeSymlink, Path: filepath.Join(home, ".codex", "skills", "demo")},
	}
	require.NoError(t, install.Install(entry, targets))

	requestJSON := func(target install.Target, action, stateToken string) string {
		body, err := json.Marshal(map[string]any{
			"scope": target.Scope, "agent": target.Agent, "mode": target.Mode,
			"path": target.Path, "skillId": skillID, "version": "v1",
			"action": action, "stateToken": stateToken,
		})
		require.NoError(t, err)
		return string(body)
	}
	var output bytes.Buffer
	require.NoError(t, Execute([]string{
		"manage",
		"--target", requestJSON(targets[0], "", ""),
		"--target", requestJSON(targets[1], "", ""),
		"--preflight", "--output", "json",
	}, &output, &output))
	var preflight struct {
		Targets []struct {
			AllowedActions []string `json:"allowedActions"`
			StateToken     string   `json:"stateToken"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Equal(t, []string{"remove"}, preflight.Targets[0].AllowedActions)
	require.Equal(t, []string{"remove"}, preflight.Targets[1].AllowedActions)

	output.Reset()
	require.NoError(t, Execute([]string{
		"manage", "--target", requestJSON(targets[0], "remove", preflight.Targets[0].StateToken),
		"--output", "ndjson",
	}, &output, &output))
	require.NoFileExists(t, targets[0].Path)
	require.FileExists(t, filepath.Join(targets[1].Path, "SKILL.md"))
	installations, err := install.ListInstallations(storage.Root, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.Equal(t, "codex", installations[0].Target.Agent)
	require.DirExists(t, entry.Root)
	require.Contains(t, output.String(), `"phase":"management-execution"`)
}

func TestManagementPlanBlocksUnsafeRemoveAndSupportsRepairOrStopManaging(t *testing.T) {
	t.Run("repair Local Modification", func(t *testing.T) {
		root := t.TempDir()
		home := filepath.Join(root, "home")
		agentHome := filepath.Join(root, "test-agent")
		t.Setenv("HOME", home)
		t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
		skillID := "github.com/example/skills/-/demo"
		storage := store.Store{Root: store.DefaultRoot(home)}
		entry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
		target := install.Target{Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeCopy, Path: filepath.Join(agentHome, "skills", "demo")}
		require.NoError(t, install.Install(entry, []install.Target{target}))
		require.NoError(t, os.WriteFile(filepath.Join(target.Path, "SKILL.md"), []byte("changed"), 0o600))

		preflight := managementPreflight(t, target, "", skillID, "v1")
		require.Equal(t, "local-modification", preflight.Health)
		require.Equal(t, []string{"repair", "stop-managing"}, preflight.AllowedActions)
		unsafeRequest, err := json.Marshal(map[string]any{
			"scope": target.Scope, "agent": target.Agent, "mode": target.Mode,
			"path": target.Path, "skillId": skillID, "version": "v1",
			"action": "remove", "stateToken": preflight.StateToken,
		})
		require.NoError(t, err)
		var unsafeOutput bytes.Buffer
		err = Execute([]string{
			"manage", "--target", string(unsafeRequest), "--output", "ndjson",
		}, &unsafeOutput, &unsafeOutput)
		require.ErrorContains(t, err, "not allowed")
		contents, err := os.ReadFile(filepath.Join(target.Path, "SKILL.md"))
		require.NoError(t, err)
		require.Equal(t, "changed", string(contents))

		output := executeManagementAction(t, target, "", skillID, "v1", "repair", preflight.StateToken)
		require.Contains(t, output, `"outcome":"succeeded"`)
		contents, err = os.ReadFile(filepath.Join(target.Path, "SKILL.md"))
		require.NoError(t, err)
		require.Equal(t, "v1", string(contents))
	})

	t.Run("stop managing preserves project content", func(t *testing.T) {
		root := t.TempDir()
		home := filepath.Join(root, "home")
		agentHome := filepath.Join(root, "test-agent")
		projectRoot := filepath.Join(root, "project")
		t.Setenv("HOME", home)
		t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
		require.NoError(t, os.MkdirAll(projectRoot, 0o700))
		skillID := "github.com/example/skills/-/demo"
		storage := store.Store{Root: store.DefaultRoot(home)}
		entry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
		target := install.Target{Agent: "test-agent", Scope: install.ScopeProject, Mode: install.ModeCopy, Path: filepath.Join(projectRoot, ".test-agent", "skills", "demo")}
		require.NoError(t, install.Install(entry, []install.Target{target}))
		require.NoError(t, project.Upsert(projectRoot, "demo", project.SkillRequirement{Source: skillID, Ref: "main", Agents: []string{"test-agent"}, Mode: install.ModeCopy}, entry.Receipt))
		require.NoError(t, os.WriteFile(filepath.Join(target.Path, "SKILL.md"), []byte("private local change"), 0o600))

		preflight := managementPreflight(t, target, projectRoot, skillID, "v1")
		require.NotContains(t, preflight.AllowedActions, "remove")
		output := executeManagementAction(t, target, projectRoot, skillID, "v1", "stop-managing", preflight.StateToken)
		require.Contains(t, output, `"outcome":"succeeded"`)
		contents, err := os.ReadFile(filepath.Join(target.Path, "SKILL.md"))
		require.NoError(t, err)
		require.Equal(t, "private local change", string(contents))
		installations, err := install.ListInstallations(storage.Root, install.InventoryFilter{})
		require.NoError(t, err)
		require.Empty(t, installations)
		manifest, lockfile, err := project.Load(projectRoot)
		require.NoError(t, err)
		require.NotContains(t, manifest.Skills, "demo")
		require.NotContains(t, lockfile.Skills, "demo")
	})
}

type managementPreflightItem struct {
	Health         string   `json:"health"`
	AllowedActions []string `json:"allowedActions"`
	StateToken     string   `json:"stateToken"`
}

func managementPreflight(t *testing.T, target install.Target, projectRoot, skillID, version string) managementPreflightItem {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"scope": target.Scope, "projectRoot": projectRoot, "agent": target.Agent,
		"mode": target.Mode, "path": target.Path, "skillId": skillID, "version": version,
	})
	require.NoError(t, err)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"manage", "--target", string(body), "--preflight", "--output", "json"}, &output, &output))
	var response struct {
		Targets []managementPreflightItem `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &response))
	require.Len(t, response.Targets, 1)
	return response.Targets[0]
}

func executeManagementAction(t *testing.T, target install.Target, projectRoot, skillID, version, action, stateToken string) string {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"scope": target.Scope, "projectRoot": projectRoot, "agent": target.Agent,
		"mode": target.Mode, "path": target.Path, "skillId": skillID, "version": version,
		"action": action, "stateToken": stateToken,
	})
	require.NoError(t, err)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"manage", "--target", string(body), "--output", "ndjson"}, &output, &output))
	return output.String()
}
