/*
 * [INPUT]: Uses temporary Agent, Store-entry, target, and Workspace fixtures at the public Installation Plan domain seam.
 * [OUTPUT]: Specifies strict target JSON, explicit-cell preservation, Workspace Lock previews, identical-target skips, receipts, and target-specific results.
 * [POS]: Serves as deterministic domain coverage beneath the public CLI command-flow contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package plan

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

func TestDecodeTargetsIsStrictAndPreservesHostilePaths(t *testing.T) {
	path := `/tmp/project ;$(touch never)`
	targets, err := DecodeTargets([]string{
		`{"scope":"project","projectRoot":"` + path + `","agent":"test-agent","mode":"copy"}`,
	})
	require.NoError(t, err)
	require.Equal(t, path, targets[0].ProjectRoot)
	require.Equal(t, install.ModeCopy, targets[0].Mode)

	_, err = DecodeTargets([]string{`{"scope":"user","agent":"test-agent","mode":"copy","extra":true}`})
	require.Error(t, err)
	_, err = DecodeTargets([]string{`{"scope":"user","agent":"test-agent","mode":"copy"} {}`})
	require.Error(t, err)
}

func TestBuildAndExecuteExplicitTargetsThenSkipIdenticalTargets(t *testing.T) {
	root := t.TempDir()
	agentHome := filepath.Join(root, "agent home")
	projectRoot := filepath.Join(root, "project")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	entry := testEntry(t, storeRoot)
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "test-agent", Display: "Test Agent",
			ProjectDir: ".test-agent/skills", UserDir: filepath.Join(agentHome, "skills"),
		}),
	)
	request := Request{
		Source: "github.com/example/skills/-/demo", RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{
			{Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeSymlink},
			{Scope: install.ScopeProject, ProjectRoot: projectRoot, Agent: "test-agent", Mode: install.ModeSymlink},
		},
	}

	preflight, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, 2, preflight.Summary.Create)
	require.Zero(t, preflight.Summary.Skip)
	require.Len(t, preflight.Targets, 2)
	require.Equal(t, install.ScopeUser, preflight.Targets[0].Target.Scope)
	require.Equal(t, projectRoot, preflight.Targets[1].Target.ProjectRoot)
	require.True(t, preflight.Targets[1].WorkspaceLockChange)
	require.Equal(t, filepath.Join(projectRoot, "skillsgo-lock.yaml"), preflight.WorkspaceLockChanges[0].Path)

	execution := Execute(entry, request, preflight)
	require.Equal(t, 2, execution.Summary.Succeeded)
	require.Zero(t, execution.Summary.Failed)
	for _, result := range execution.Results {
		require.Equal(t, OutcomeSucceeded, result.Outcome)
		require.FileExists(t, filepath.Join(result.Target.Path, "SKILL.md"))
	}
	installations, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 2)
	manifest, lockfile, err := project.Load(projectRoot)
	require.NoError(t, err)
	require.Equal(t, []string{"test-agent"}, manifest.Skills["demo"].Agents)
	require.Equal(t, "v1", lockfile.Skills["demo"].Version)

	second, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Zero(t, second.Summary.Create)
	require.Equal(t, 2, second.Summary.Skip)
	require.Empty(t, second.WorkspaceLockChanges)
	secondExecution := Execute(entry, request, second)
	require.Equal(t, 2, secondExecution.Summary.Skipped)
	require.Zero(t, secondExecution.Summary.Succeeded)
}

func TestExecuteRecordsEveryAgentWhenTargetsShareOnePhysicalCopy(t *testing.T) {
	root := t.TempDir()
	agentHome := filepath.Join(root, "shared-agent-home")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	entry := testEntry(t, storeRoot)
	definition := func(id string) agent.Definition {
		return agent.Definition{
			ID: id, Display: id, ProjectDir: ".agents/skills",
			UserDir: filepath.Join(agentHome, "skills"),
		}
	}
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(definition("agent-a")),
		agent.WithDefinition(definition("agent-b")),
	)
	request := Request{
		Source: "github.com/example/skills/-/demo", RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{
			{Scope: install.ScopeUser, Agent: "agent-a", Mode: install.ModeCopy},
			{Scope: install.ScopeUser, Agent: "agent-b", Mode: install.ModeCopy},
		},
	}

	preflight, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, preflight.Targets[0].Target.Path, preflight.Targets[1].Target.Path)
	execution := Execute(entry, request, preflight)
	require.Equal(t, 2, execution.Summary.Succeeded)
	installations, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 2)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, []string{
		installations[0].Target.Agent,
		installations[1].Target.Agent,
	})
}

func testEntry(t *testing.T, root string) *store.Entry {
	t.Helper()
	entryRoot := filepath.Join(root, "github.com", "example", "skills", "-", "demo@v1")
	artifact := filepath.Join(entryRoot, "artifact")
	require.NoError(t, os.MkdirAll(artifact, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("# Demo\n"), 0o600))
	entry := &store.Entry{
		Root: entryRoot, Artifact: artifact,
		Receipt: store.Receipt{
			Coordinate: "github.com/example/skills/-/demo", Version: "v1", SHA256: "sha256-demo",
		},
	}
	receipt, err := yaml.Marshal(entry.Receipt)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(entryRoot, "receipt.yaml"), receipt, 0o600))
	return entry
}
