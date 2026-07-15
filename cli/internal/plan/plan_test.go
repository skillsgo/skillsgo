/*
 * [INPUT]: Uses temporary Agent, Store-entry, target, and Workspace fixtures at the public Installation Plan domain seam.
 * [OUTPUT]: Specifies strict target JSON, explicit-cell preservation, shared-path and state-bound conflict resolution, trusted-risk gates, zero-mutation unresolved plans, Workspace Lock previews, Local Modification protection, receipts, and target-specific results.
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
	"github.com/skillsgo/skillsgo/cli/internal/registry"
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

func TestBuildRejectsPathLikeSkillNames(t *testing.T) {
	for _, name := range []string{".", ".."} {
		_, err := Build(nil, &store.Entry{}, t.TempDir(), Request{Name: name, Targets: []TargetRequest{{}}})
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid Skill name")
	}
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

	execution, err := Execute(entry, storeRoot, request, preflight)
	require.NoError(t, err)
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
	secondExecution, err := Execute(entry, storeRoot, request, second)
	require.NoError(t, err)
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
	execution, err := Execute(entry, storeRoot, request, preflight)
	require.NoError(t, err)
	require.Equal(t, 2, execution.Summary.Succeeded)
	installations, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 2)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, []string{
		installations[0].Target.Agent,
		installations[1].Target.Agent,
	})
}

func TestSharedPhysicalCreateRequiresEveryInstalledAgentCell(t *testing.T) {
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
		Targets: []TargetRequest{{Scope: install.ScopeUser, Agent: "agent-a", Mode: install.ModeCopy}},
	}

	preflight, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, preflight.Targets[0].Action)
	require.Equal(t, "shared-target-conflict", preflight.Targets[0].ReasonCode)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, []string{
		preflight.Targets[0].AffectedBindings[0].Agent,
		preflight.Targets[0].AffectedBindings[1].Agent,
	})
	_, err = Execute(entry, storeRoot, request, preflight)
	require.Error(t, err)
	require.NoFileExists(t, filepath.Join(agentHome, "skills", "demo", "SKILL.md"))
}

func TestVersionConflictRequiresExplicitReplacementBeforeAnyMutation(t *testing.T) {
	root := t.TempDir()
	agentHome := filepath.Join(root, "agent-home")
	projectRoot := filepath.Join(root, "project")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "test-agent", Display: "Test Agent",
			UserDir: filepath.Join(agentHome, "skills"), ProjectDir: ".agent/skills",
		}),
	)
	oldEntry := testEntryVersion(t, storeRoot, "github.com/example/skills/-/demo", "v1", "old")
	newEntry := testEntryVersion(t, storeRoot, "github.com/example/skills/-/demo", "v2", "new")
	request := Request{
		Source: "github.com/example/skills/-/demo", RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{Scope: install.ScopeProject, ProjectRoot: projectRoot, Agent: "test-agent", Mode: install.ModeCopy}},
	}
	initial, err := Build(catalog, oldEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(oldEntry, storeRoot, request, initial)
	require.NoError(t, err)
	targetPath := initial.Targets[0].Target.Path
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "old")
	request.Targets = append(request.Targets, TargetRequest{
		Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeCopy,
	})

	conflicted, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, conflicted.Targets[0].Action)
	require.Equal(t, "version-conflict", conflicted.Targets[0].ReasonCode)
	require.True(t, conflicted.Targets[0].WorkspaceLockChange)
	require.Equal(t, "v1", conflicted.WorkspaceLockChanges[0].FromVersion)
	require.Equal(t, "v2", conflicted.WorkspaceLockChanges[0].ToVersion)
	require.Equal(t, ActionCreate, conflicted.Targets[1].Action)
	_, err = Execute(newEntry, storeRoot, request, conflicted)
	require.Error(t, err)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "old")
	require.NoFileExists(t, conflicted.Targets[1].Target.Path)

	authorizeReplacement(&request.Targets[0], conflicted.Targets[0])
	replacement, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionReplace, replacement.Targets[0].Action)
	execution, err := Execute(newEntry, storeRoot, request, replacement)
	require.NoError(t, err)
	require.Equal(t, 2, execution.Summary.Succeeded)
	require.Equal(t, OutcomeSucceeded, execution.Results[0].Outcome)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "new")
}

func TestLocalModificationBlocksSilentReplacement(t *testing.T) {
	root := t.TempDir()
	agentHome := filepath.Join(root, "agent-home")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "test-agent", Display: "Test Agent",
			UserDir: filepath.Join(agentHome, "skills"), ProjectDir: ".agent/skills",
		}),
	)
	entry := testEntryVersion(t, storeRoot, "github.com/example/skills/-/demo", "v1", "original")
	updatedEntry := testEntryVersion(t, storeRoot, "github.com/example/skills/-/demo", "v2", "updated")
	request := Request{
		Source: entry.Receipt.Coordinate, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeCopy}},
	}
	initial, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(entry, storeRoot, request, initial)
	require.NoError(t, err)
	targetPath := initial.Targets[0].Target.Path
	require.NoError(t, os.WriteFile(filepath.Join(targetPath, "SKILL.md"), []byte("# locally edited\n"), 0o600))

	blocked, err := Build(catalog, updatedEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, blocked.Targets[0].Action)
	require.Equal(t, "local-modification", blocked.Targets[0].ReasonCode)
	_, err = Execute(updatedEntry, storeRoot, request, blocked)
	require.Error(t, err)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "locally edited")

	authorizeReplacement(&request.Targets[0], blocked.Targets[0])
	replacement, err := Build(catalog, updatedEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionReplace, replacement.Targets[0].Action)
	require.NoError(t, os.WriteFile(filepath.Join(targetPath, "SKILL.md"), []byte("# edited after review\n"), 0o600))
	_, err = Execute(updatedEntry, storeRoot, request, replacement)
	require.Error(t, err)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "edited after review")

	changed, err := Build(catalog, updatedEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, changed.Targets[0].Action)
	require.Equal(t, "local-modification", changed.Targets[0].ReasonCode)
	authorizeReplacement(&request.Targets[0], changed.Targets[0])
	replacement, err = Build(catalog, updatedEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(updatedEntry, storeRoot, request, replacement)
	require.NoError(t, err)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "updated")
}

func TestDifferentIdentityNeverMergesWithoutExplicitReplacement(t *testing.T) {
	root := t.TempDir()
	agentHome := filepath.Join(root, "agent-home")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "test-agent", Display: "Test Agent",
			UserDir: filepath.Join(agentHome, "skills"), ProjectDir: ".agent/skills",
		}),
	)
	oldEntry := testEntryVersion(t, storeRoot, "github.com/old/skills/-/demo", "v1", "old identity")
	newEntry := testEntryVersion(t, storeRoot, "github.com/new/skills/-/demo", "v1", "new identity")
	request := Request{
		Source: oldEntry.Receipt.Coordinate, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeCopy}},
	}
	initial, err := Build(catalog, oldEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(oldEntry, storeRoot, request, initial)
	require.NoError(t, err)
	targetPath := initial.Targets[0].Target.Path

	request.Source = newEntry.Receipt.Coordinate
	blocked, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, blocked.Targets[0].Action)
	require.Equal(t, "identity-collision", blocked.Targets[0].ReasonCode)
	_, err = Execute(newEntry, storeRoot, request, blocked)
	require.Error(t, err)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "old identity")

	authorizeReplacement(&request.Targets[0], blocked.Targets[0])
	replacement, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionReplace, replacement.Targets[0].Action)
	_, err = Execute(newEntry, storeRoot, request, replacement)
	require.NoError(t, err)
	requireFileContains(t, filepath.Join(targetPath, "SKILL.md"), "new identity")
	installations, err := install.ListInstallations(storeRoot, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.Equal(t, newEntry.Receipt.Coordinate, installations[0].Coordinate)
}

func TestIdentityReplacementPreservesAllExplicitProjectAgents(t *testing.T) {
	root := t.TempDir()
	projectRoot := filepath.Join(root, "project")
	storeRoot := filepath.Join(root, "store")
	agentAHome := filepath.Join(root, "agent-a")
	agentBHome := filepath.Join(root, "agent-b")
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	require.NoError(t, os.MkdirAll(agentAHome, 0o700))
	require.NoError(t, os.MkdirAll(agentBHome, 0o700))
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "agent-a", Display: "Agent A", UserDir: agentAHome, ProjectDir: ".agents/skills",
		}),
		agent.WithDefinition(agent.Definition{
			ID: "agent-b", Display: "Agent B", UserDir: agentBHome, ProjectDir: ".agents/skills",
		}),
	)
	oldEntry := testEntryVersion(t, storeRoot, "github.com/old/skills/-/demo", "v1", "old identity")
	newEntry := testEntryVersion(t, storeRoot, "github.com/new/skills/-/demo", "v1", "new identity")
	request := Request{
		Source: oldEntry.Receipt.Coordinate, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{
			{Scope: install.ScopeProject, ProjectRoot: projectRoot, Agent: "agent-a", Mode: install.ModeCopy},
			{Scope: install.ScopeProject, ProjectRoot: projectRoot, Agent: "agent-b", Mode: install.ModeCopy},
		},
	}
	initial, err := Build(catalog, oldEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(oldEntry, storeRoot, request, initial)
	require.NoError(t, err)

	request.Source = newEntry.Receipt.Coordinate
	singleTargetRequest := request
	singleTargetRequest.Targets = append([]TargetRequest(nil), request.Targets[:1]...)
	shared, err := Build(catalog, newEntry, storeRoot, singleTargetRequest)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, shared.Targets[0].Action)
	require.Equal(t, "shared-target-conflict", shared.Targets[0].ReasonCode)
	require.Len(t, shared.Targets[0].AffectedBindings, 2)
	_, err = Execute(newEntry, storeRoot, singleTargetRequest, shared)
	require.Error(t, err)
	requireFileContains(t, filepath.Join(shared.Targets[0].Target.Path, "SKILL.md"), "old identity")

	reviewed, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, 2, reviewed.Summary.Conflict)
	authorizeReplacement(&request.Targets[0], reviewed.Targets[0])
	authorizeReplacement(&request.Targets[1], reviewed.Targets[1])
	replacement, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	result, err := Execute(newEntry, storeRoot, request, replacement)
	require.NoError(t, err)
	require.Equal(t, 2, result.Summary.Succeeded)
	manifest, lockfile, err := project.Load(projectRoot)
	require.NoError(t, err)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, manifest.Skills["demo"].Agents)
	require.Equal(t, newEntry.Receipt.Coordinate, manifest.Skills["demo"].Source)
	require.Equal(t, newEntry.Receipt.Coordinate, lockfile.Skills["demo"].Coordinate)
}

func TestRiskPolicyBlocksMutationUntilExplicitConfirmation(t *testing.T) {
	root := t.TempDir()
	agentHome := filepath.Join(root, "agent-home")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(agentHome, 0o700))
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "test-agent", Display: "Test Agent",
			UserDir: filepath.Join(agentHome, "skills"), ProjectDir: ".agent/skills",
		}),
	)
	entry := testEntryVersion(t, storeRoot, "github.com/example/skills/-/danger", "v1", "danger")
	entry.Receipt.Risk = registry.RiskHigh
	request := Request{
		Source: entry.Receipt.Coordinate, RequestedRef: "main", Name: "danger",
		Targets: []TargetRequest{{Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeSymlink}},
	}

	high, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionRisk, high.Targets[0].Action)
	require.Equal(t, "high-risk", high.Targets[0].ReasonCode)
	_, err = Execute(entry, storeRoot, request, high)
	require.Error(t, err)
	require.NoFileExists(t, high.Targets[0].Target.Path)

	request.RiskConfirmed = true
	confirmed, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionCreate, confirmed.Targets[0].Action)

	entry.Receipt.Risk = registry.RiskCritical
	critical, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionRisk, critical.Targets[0].Action)
	require.Equal(t, "critical-risk", critical.Targets[0].ReasonCode)
	_, err = Execute(entry, storeRoot, request, critical)
	require.Error(t, err)
	require.NoFileExists(t, critical.Targets[0].Target.Path)

	request.AllowCritical = true
	overridden, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionCreate, overridden.Targets[0].Action)
	_, err = Execute(entry, storeRoot, request, overridden)
	require.NoError(t, err)
	require.FileExists(t, filepath.Join(overridden.Targets[0].Target.Path, "SKILL.md"))
}

func requireFileContains(t *testing.T, path, expected string) {
	t.Helper()
	contents, err := os.ReadFile(path)
	require.NoError(t, err)
	require.Contains(t, string(contents), expected)
}

func authorizeReplacement(request *TargetRequest, item Item) {
	request.Resolution = ResolutionReplace
	request.ExpectedReason = item.ReasonCode
	request.ExpectedState = item.StateToken
}

func testEntry(t *testing.T, root string) *store.Entry {
	t.Helper()
	return testEntryVersion(t, root, "github.com/example/skills/-/demo", "v1", "Demo")
}

func testEntryVersion(t *testing.T, root, coordinate, version, content string) *store.Entry {
	t.Helper()
	entryRoot := filepath.Join(root, filepath.FromSlash(coordinate+"@"+version))
	artifact := filepath.Join(entryRoot, "artifact")
	require.NoError(t, os.MkdirAll(artifact, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("# "+content+"\n"), 0o600))
	entry := &store.Entry{
		Root: entryRoot, Artifact: artifact,
		Receipt: store.Receipt{
			Coordinate: coordinate, Version: version, SHA256: "sha256-" + version,
			ContentDigest: "sha256:content-" + version, Risk: registry.RiskLow,
		},
	}
	receipt, err := yaml.Marshal(entry.Receipt)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(entryRoot, "receipt.yaml"), receipt, 0o600))
	return entry
}
