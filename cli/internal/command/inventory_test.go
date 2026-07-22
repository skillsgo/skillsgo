/*
 * [INPUT]: Uses command.Execute with temporary Store receipts, explicit project roots, Workspace files, and the test Agent.
 * [OUTPUT]: Specifies the inventory v5 managed/external target and derived-visibility JSON contract, target reconciliation, Local Modification health, inventory-key separation, read-only inspection, and explicit-root privacy boundary.
 * [POS]: Serves as executable contract coverage for the App-facing unified Library inventory.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestInventoryJSONAggregatesExplicitScopesAndHidesUnselectedProjects(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	userAgentHome := filepath.Join(root, `agent home;$(touch nope)`)
	selectedProject := filepath.Join(root, `selected project;$(touch nope)`)
	unselectedProject := filepath.Join(root, "unselected-project")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", userAgentHome)
	storage := store.Store{Root: store.DefaultRoot(home)}
	skillID := "github.com/example/skills/-/demo"

	userEntry := commandTestStoreEntry(t, storage, skillID, "v1")
	require.NoError(t, install.Install(userEntry, []install.Target{{
		Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeSymlink,
		Path: filepath.Join(userAgentHome, "skills", "demo"), CanonicalPath: filepath.Join(home, ".agents", "skills", "demo"),
	}}))
	require.NoError(t, project.Upsert(project.UserRoot(home), "demo", project.SkillRequirement{Source: skillID, Ref: "main", Agents: []string{"test-agent"}}, userEntry.Receipt))

	projectEntry := commandTestStoreEntry(t, storage, skillID, "v2")
	selectedTarget := install.Target{
		Agent: "test-agent", Scope: install.ScopeProject, Mode: install.ModeCopy,
		Path: filepath.Join(selectedProject, ".test-agent", "skills", "demo"),
	}
	require.NoError(t, install.Install(projectEntry, []install.Target{selectedTarget}))
	require.NoError(t, project.Upsert(
		selectedProject,
		"demo",
		project.SkillRequirement{Agents: []string{"test-agent"}, Mode: install.ModeCopy},
		projectEntry.Receipt,
	))

	hiddenEntry := commandTestStoreEntry(t, storage, "github.com/private/hidden/-/secret", "v1")
	require.NoError(t, install.Install(hiddenEntry, []install.Target{{
		Agent: "test-agent", Scope: install.ScopeProject, Mode: install.ModeSymlink,
		Path: filepath.Join(unselectedProject, ".test-agent", "skills", "secret"), CanonicalPath: filepath.Join(unselectedProject, ".agents", "skills", "secret"),
	}}))

	var stdout, stderr bytes.Buffer
	err := Execute(
		[]string{"inventory", "--user", "--project", selectedProject, "--output", "json"},
		&stdout,
		&stderr,
	)
	require.NoError(t, err)
	require.Empty(t, stderr.String())

	var report inventoryReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Equal(t, 5, report.SchemaVersion)
	require.Len(t, report.Entries, 1)
	entry := report.Entries[0]
	require.Equal(t, "hub:"+skillID, entry.InventoryKey)
	require.Equal(t, skillID, entry.SkillID)
	require.Equal(t, "demo", entry.Name)
	require.Equal(t, "hub", string(entry.Provenance))
	require.Equal(t, "unknown", string(entry.Risk))
	require.Equal(t, []string{"test-agent"}, entry.Agents)
	require.Equal(t, []string{selectedProject}, entry.Projects)
	require.Equal(t, []string{"v1", "v2"}, entry.Versions)
	require.True(t, entry.VersionDivergence)
	require.Equal(t, "healthy", string(entry.Health))
	require.Len(t, entry.Targets, 2)
	require.Len(t, entry.Visibility, 2)
	require.Equal(t, "test-agent", entry.Visibility[0].Agent)
	require.Equal(t, install.ScopeUser, entry.Visibility[0].Scope)
	require.Equal(t, []string{filepath.Join(userAgentHome, "skills", "demo")}, entry.Visibility[0].Paths)
	require.Equal(t, "unverified", string(entry.Visibility[0].Verification))
	require.Equal(t, install.ScopeProject, entry.Visibility[1].Scope)
	require.Equal(t, selectedProject, entry.Visibility[1].ProjectRoot)
	require.Equal(t, "healthy", string(entry.Targets[0].Health))
	require.Empty(t, entry.Targets[0].ProjectRoot)
	require.Equal(t, selectedProject, entry.Targets[1].ProjectRoot)
	require.Equal(t, string(install.ModeCopy), string(entry.Targets[1].Mode))
	require.Equal(t, "v2", entry.Targets[1].Version)
	require.NotContains(t, stdout.String(), unselectedProject)
	require.NotContains(t, stdout.String(), "secret")

	require.NoError(t, os.WriteFile(
		filepath.Join(selectedTarget.Path, "SKILL.md"),
		[]byte("# locally modified\n"),
		0o600,
	))
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute(
		[]string{"inventory", "--user", "--project", selectedProject, "--output", "json"},
		&stdout,
		&stderr,
	))
	report = inventoryReport{}
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Equal(t, "local-modification", string(report.Entries[0].Health))
	require.Equal(t, "local-modification", string(report.Entries[0].Targets[1].Health))
	original, err := os.ReadFile(filepath.Join(projectEntry.Artifact, "SKILL.md"))
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(selectedTarget.Path, "SKILL.md"), original, 0o600))

	manifestPath := filepath.Join(selectedProject, "skillsgo.mod")
	manifestBytes, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(
		manifestPath,
		bytes.ReplaceAll(manifestBytes, []byte("v2"), []byte("v999")),
		0o600,
	))
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute(
		[]string{"inventory", "--user", "--project", selectedProject, "--output", "json"},
		&stdout,
		&stderr,
	))
	report = inventoryReport{}
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Equal(t, "healthy", string(report.Entries[0].Health))

	require.NoError(t, os.RemoveAll(selectedTarget.Path))
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute(
		[]string{"inventory", "--user", "--project", selectedProject, "--output", "json"},
		&stdout,
		&stderr,
	))
	report = inventoryReport{}
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Len(t, report.Entries[0].Targets, 1)

	unexpectedPath := filepath.Join(root, "arbitrary", "demo")
	require.NoError(t, install.Install(userEntry, []install.Target{{
		Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeCopy,
		Path: unexpectedPath,
	}}))
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute(
		[]string{"inventory", "--user", "--project", selectedProject, "--output", "json"},
		&stdout,
		&stderr,
	))
	report = inventoryReport{}
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.NotContains(t, stdout.String(), unexpectedPath)
}

func TestInventoryJSONReportsDeclaredTargetWithoutReceipt(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "declared-project")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", filepath.Join(root, "agent-home"))
	storage := store.Store{Root: store.DefaultRoot(home)}
	skillID := "github.com/example/skills/-/declared"
	entry := commandTestStoreEntry(t, storage, skillID, "v3")
	require.NoError(t, os.MkdirAll(projectRoot, 0o755))

	require.NoError(t, project.Upsert(
		projectRoot,
		"declared",
		project.SkillRequirement{Agents: []string{"test-agent"}, Mode: install.ModeCopy},
		entry.Receipt,
	))

	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute(
		[]string{"inventory", "--project", projectRoot, "--output", "json"},
		&stdout,
		&stderr,
	))
	require.Empty(t, stderr.String())

	var report inventoryReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Len(t, report.Entries, 1)
	require.Equal(t, "hub:"+skillID, report.Entries[0].InventoryKey)
	require.Equal(t, "missing", string(report.Entries[0].Health))
	require.Equal(t, []string{"v3"}, report.Entries[0].Versions)
	require.Len(t, report.Entries[0].Targets, 1)
	target := report.Entries[0].Targets[0]
	require.Equal(t, projectRoot, target.ProjectRoot)
	require.Equal(t, "test-agent", target.Agent)
	require.Equal(t, filepath.Join(projectRoot, ".test-agent", "skills", "demo"), target.Path)
	require.Equal(t, string(install.ModeSymlink), string(target.Mode))
	require.Equal(t, "missing", string(target.Health))
}

func TestInventoryJSONReportsExternalInstallationsWithoutClaimingOrChangingThem(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	selectedProject := filepath.Join(root, "selected")
	unselectedProject := filepath.Join(root, "unselected")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	storage := store.Store{Root: store.DefaultRoot(home)}

	managedEntry := commandTestStoreEntry(t, storage, "github.com/example/skills/-/demo", "v4")
	managedTarget := install.Target{
		Agent: "test-agent", Scope: install.ScopeProject, Mode: install.ModeCopy,
		Path: filepath.Join(selectedProject, ".test-agent", "skills", "demo"),
	}
	require.NoError(t, install.Install(managedEntry, []install.Target{managedTarget}))
	require.NoError(t, project.Upsert(
		selectedProject,
		"demo",
		project.SkillRequirement{Agents: []string{"test-agent"}, Mode: install.ModeCopy},
		managedEntry.Receipt,
	))

	externalPath := filepath.Join(agentHome, "skills", "demo")
	externalSkill := []byte("---\nname: demo\ndescription: unmanaged fixture\n---\n# External\n")
	require.NoError(t, os.MkdirAll(filepath.Join(externalPath, "scripts"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(externalPath, "SKILL.md"), externalSkill, 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(externalPath, "scripts", "run.sh"), []byte("#!/bin/sh\n"), 0o755))

	projectExternalPath := filepath.Join(selectedProject, ".test-agent", "skills", "project-external")
	require.NoError(t, os.MkdirAll(projectExternalPath, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(projectExternalPath, "SKILL.md"), []byte("---\nname: project-external\n---\n# Project external\n"), 0o644))
	hiddenPath := filepath.Join(unselectedProject, ".test-agent", "skills", "hidden")
	require.NoError(t, os.MkdirAll(hiddenPath, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(hiddenPath, "SKILL.md"), []byte("---\nname: hidden\n---\n"), 0o644))
	if runtime.GOOS != "windows" {
		escapedPath := filepath.Join(root, "outside-known-agent-directory")
		require.NoError(t, os.MkdirAll(escapedPath, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(escapedPath, "SKILL.md"), []byte("---\nname: escaped\n---\n"), 0o644))
		require.NoError(t, os.Symlink(escapedPath, filepath.Join(agentHome, "skills", "escaped")))

		manifestLinkPath := filepath.Join(agentHome, "skills", "manifest-link")
		require.NoError(t, os.MkdirAll(manifestLinkPath, 0o755))
		require.NoError(t, os.Symlink(filepath.Join(escapedPath, "SKILL.md"), filepath.Join(manifestLinkPath, "SKILL.md")))
	}

	before, err := os.ReadFile(filepath.Join(externalPath, "SKILL.md"))
	require.NoError(t, err)
	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute(
		[]string{"inventory", "--user", "--project", selectedProject, "--output", "json"},
		&stdout,
		&stderr,
	))
	require.Empty(t, stderr.String())

	var report inventoryReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &report))
	require.Len(t, report.Entries, 3)
	managedIndex, externalIndex, projectExternalIndex := -1, -1, -1
	for index := range report.Entries {
		entry := &report.Entries[index]
		switch {
		case entry.InventoryKey == "hub:"+managedEntry.Receipt.SkillID:
			managedIndex = index
		case entry.Name == "demo" && entry.Provenance == "external":
			externalIndex = index
		case entry.Name == "project-external":
			projectExternalIndex = index
		}
	}
	require.NotEqual(t, -1, managedIndex)
	require.NotEqual(t, -1, externalIndex)
	require.NotEqual(t, -1, projectExternalIndex)
	managed := report.Entries[managedIndex]
	external := report.Entries[externalIndex]
	projectExternal := report.Entries[projectExternalIndex]
	require.NotEqual(t, managed.InventoryKey, external.InventoryKey)
	require.Equal(t, "inventory fixture", managed.Description)
	require.Equal(t, "unmanaged fixture", external.Description)
	require.Contains(t, external.InventoryKey, "external:")
	require.Empty(t, external.SkillID)
	require.Empty(t, external.Versions)
	require.Equal(t, "unknown", string(external.Risk))
	require.Equal(t, "healthy", string(external.Health))
	require.Len(t, external.Targets, 1)
	require.Equal(t, externalPath, external.Targets[0].Path)
	require.Equal(t, "external", string(external.Targets[0].Mode))
	require.Empty(t, external.Targets[0].Version)
	require.Equal(t, selectedProject, projectExternal.Targets[0].ProjectRoot)
	require.NotContains(t, stdout.String(), hiddenPath)
	require.NotContains(t, stdout.String(), "escaped")
	require.NotContains(t, stdout.String(), "manifest-link")

	after, err := os.ReadFile(filepath.Join(externalPath, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, before, after)
}

func commandTestStoreEntry(t *testing.T, storage store.Store, skillID, version string) *store.Entry {
	t.Helper()
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: demo\ndescription: inventory fixture\n---\n",
	})
	entry, err := storage.Put(&hub.Artifact{
		SkillID: skillID,
		Info: hub.Info{
			SchemaVersion: 1, Kind: "Skill", ID: skillID, Name: "demo", Description: "inventory fixture",
			Version: version, Risk: hub.RiskLow, ArchiveSize: int64(len(zipData)),
			Sum: commandTestSum(t, zipData, skillID, version),
		},
		ZIP: zipData,
	})
	require.NoError(t, err)
	return entry
}
