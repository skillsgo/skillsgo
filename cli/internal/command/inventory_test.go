/*
 * [INPUT]: Uses command.Execute with temporary Store receipts, explicit project roots, Workspace files, and the test Agent.
 * [OUTPUT]: Specifies the versioned managed-inventory JSON contract, target reconciliation, aggregation, and explicit-root privacy boundary.
 * [POS]: Serves as executable contract coverage for the App-facing unified Library inventory.
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
	"github.com/skillsgo/skillsgo/cli/internal/registry"
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
	coordinate := "github.com/example/skills/-/demo"

	userEntry := commandTestStoreEntry(t, storage, coordinate, "v1")
	require.NoError(t, install.Install(userEntry, []install.Target{{
		Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeSymlink,
		Path: filepath.Join(userAgentHome, "skills", "demo"),
	}}))

	projectEntry := commandTestStoreEntry(t, storage, coordinate, "v2")
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
		Path: filepath.Join(unselectedProject, ".test-agent", "skills", "secret"),
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
	require.Equal(t, inventorySchemaVersion, report.SchemaVersion)
	require.Len(t, report.Entries, 1)
	entry := report.Entries[0]
	require.Equal(t, "registry:"+coordinate, entry.Identity)
	require.Equal(t, coordinate, entry.Coordinate)
	require.Equal(t, "demo", entry.Name)
	require.Equal(t, "registry", string(entry.Provenance))
	require.Equal(t, "unknown", string(entry.Risk))
	require.Equal(t, []string{"test-agent"}, entry.Agents)
	require.Equal(t, []string{selectedProject}, entry.Projects)
	require.Equal(t, []string{"v1", "v2"}, entry.Versions)
	require.True(t, entry.VersionDivergence)
	require.Equal(t, "healthy", string(entry.Health))
	require.Len(t, entry.Targets, 2)
	require.Equal(t, "present", string(entry.Targets[0].ReceiptState))
	require.Equal(t, "healthy", string(entry.Targets[0].Health))
	require.Empty(t, entry.Targets[0].ProjectRoot)
	require.Equal(t, selectedProject, entry.Targets[1].ProjectRoot)
	require.Equal(t, install.ModeCopy, entry.Targets[1].Mode)
	require.Equal(t, "v2", entry.Targets[1].Version)
	require.NotContains(t, stdout.String(), unselectedProject)
	require.NotContains(t, stdout.String(), "secret")

	lockPath := filepath.Join(selectedProject, "skillsgo-lock.yaml")
	lockBytes, err := os.ReadFile(lockPath)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(
		lockPath,
		bytes.ReplaceAll(lockBytes, []byte("v2"), []byte("v999")),
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
	require.Equal(t, "lock-mismatch", string(report.Entries[0].Health))
	require.Equal(t, "lock-mismatch", string(report.Entries[0].Targets[1].Health))

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
	require.Len(t, report.Entries[0].Targets, 2)
	require.Equal(t, "missing", string(report.Entries[0].Targets[1].Health))

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
	var unexpectedFound bool
	for _, target := range report.Entries[0].Targets {
		if target.Path == unexpectedPath {
			unexpectedFound = true
			require.Equal(t, "unexpected-path", string(target.Health))
		}
	}
	require.True(t, unexpectedFound)
}

func TestInventoryJSONReportsDeclaredTargetWithoutReceipt(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "declared-project")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", filepath.Join(root, "agent-home"))
	storage := store.Store{Root: store.DefaultRoot(home)}
	coordinate := "github.com/example/skills/-/declared"
	entry := commandTestStoreEntry(t, storage, coordinate, "v3")
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
	require.Equal(t, "registry:"+coordinate, report.Entries[0].Identity)
	require.Equal(t, "receipt-missing", string(report.Entries[0].Health))
	require.Equal(t, []string{"v3"}, report.Entries[0].Versions)
	require.Len(t, report.Entries[0].Targets, 1)
	target := report.Entries[0].Targets[0]
	require.Equal(t, projectRoot, target.ProjectRoot)
	require.Equal(t, "test-agent", target.Agent)
	require.Equal(t, filepath.Join(projectRoot, ".test-agent", "skills", "declared"), target.Path)
	require.Equal(t, install.ModeCopy, target.Mode)
	require.Equal(t, "missing", string(target.ReceiptState))
	require.Equal(t, "receipt-missing", string(target.Health))
}

func commandTestStoreEntry(t *testing.T, storage store.Store, coordinate, version string) *store.Entry {
	t.Helper()
	entry, err := storage.Put(&registry.Artifact{
		Coordinate: coordinate,
		Info:       registry.Info{Version: version},
		Manifest:   []byte("name: demo\ndescription: inventory fixture\n"),
		ZIP: commandTestZIP(t, coordinate+"@"+version+"/", map[string]string{
			"SKILL.md": "---\nname: demo\ndescription: inventory fixture\n---\n",
		}),
	})
	require.NoError(t, err)
	return entry
}
