/*
 * [INPUT]: Uses command.Execute with flat exact-path flags, managed and External targets, temporary Store receipts, and filesystem drift.
 * [OUTPUT]: Specifies top-level exact Remove/Repair, unsafe-remove blocking, Store retention, and removal of the manage command.
 * [POS]: Serves as the public CLI contract coverage for App-driven target operations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestTopLevelRemoveUsesFlatExactTargetAndRetainsStore(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	skillID := "github.com/example/skills/-/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	entry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
	target := install.Target{Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeSymlink, Path: filepath.Join(agentHome, "skills", "demo"), CanonicalPath: filepath.Join(home, ".agents", "skills", "demo")}
	related := install.Target{Agent: "codex", Scope: install.ScopeUser, Mode: install.ModeSymlink, Path: filepath.Join(home, ".codex", "skills", "demo"), CanonicalPath: target.CanonicalPath}
	require.NoError(t, install.Install(entry, []install.Target{target, related}))
	require.NoError(t, project.Upsert(project.UserRoot(home), "demo", project.SkillRequirement{Source: skillID, Ref: "main", Agents: []string{"test-agent", "codex"}}, entry.Receipt))

	preflight := managementPreflight(t, "remove", target, "")
	require.Equal(t, []string{"remove"}, preflight.AllowedActions)
	output := executeManagementAction(t, "remove", target, "", preflight.StateToken)
	require.Contains(t, output, `"outcome":"succeeded"`)
	require.NoFileExists(t, target.Path)
	require.FileExists(t, filepath.Join(related.Path, "SKILL.md"))
	require.DirExists(t, entry.Root)
}

func TestTopLevelRepairRestoresLocalModification(t *testing.T) {
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
	require.NoError(t, project.Upsert(project.UserRoot(home), "demo", project.SkillRequirement{Source: skillID, Ref: "main", Agents: []string{"test-agent"}}, entry.Receipt))
	require.NoError(t, os.WriteFile(filepath.Join(target.Path, "SKILL.md"), []byte("changed"), 0o600))

	preflight := managementPreflight(t, "repair", target, "")
	require.Equal(t, []string{"repair"}, preflight.AllowedActions)
	output := executeManagementAction(t, "repair", target, "", preflight.StateToken)
	require.Contains(t, output, `"outcome":"succeeded"`)
	contents, err := os.ReadFile(filepath.Join(target.Path, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, "v1", string(contents))
}

func TestManageCommandIsRemoved(t *testing.T) {
	var output bytes.Buffer
	err := Execute([]string{"manage"}, &output, &output)
	require.ErrorContains(t, err, "unknown command")
}

func updatePlanTestStoreEntry(t *testing.T, storage store.Store, skillID, version, requestedRef, commitSHA string) *store.Entry {
	t.Helper()
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": version})
	entry, err := storage.Put(&hub.Artifact{SkillID: skillID, Info: hub.Info{SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "test", Version: version, Risk: hub.RiskLow, ContentDigest: commandTestContentDigest(t, zipData, skillID, version), ArchiveSize: int64(len(zipData)), Ref: "refs/heads/" + requestedRef, CommitSHA: commitSHA, TreeSHA: "tree-" + commitSHA}, ZIP: zipData})
	require.NoError(t, err)
	return entry
}

type managementPreflightItem struct {
	Health         string   `json:"health"`
	AllowedActions []string `json:"allowedActions"`
	StateToken     string   `json:"stateToken"`
}

func managementPreflight(t *testing.T, command string, target install.Target, projectRoot string) managementPreflightItem {
	t.Helper()
	args := []string{command, "--path", target.Path, "--agent", target.Agent, "--preflight", "--output", "json"}
	if projectRoot != "" {
		args = append(args, "--project", projectRoot)
	}
	var output bytes.Buffer
	require.NoError(t, Execute(args, &output, &output), output.String())
	var response struct {
		Targets []managementPreflightItem `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &response), output.String())
	require.Len(t, response.Targets, 1)
	return response.Targets[0]
}

func executeManagementAction(t *testing.T, command string, target install.Target, projectRoot, stateToken string) string {
	t.Helper()
	args := []string{command, "--path", target.Path, "--agent", target.Agent, "--expected-state", stateToken, "--output", "ndjson"}
	if projectRoot != "" {
		args = append(args, "--project", projectRoot)
	}
	var output bytes.Buffer
	require.NoError(t, Execute(args, &output, &output), output.String())
	return output.String()
}
