/*
 * [INPUT]: Uses temporary Agent, Store-entry, target, and Workspace fixtures at the public Installation Plan domain seam.
 * [OUTPUT]: Specifies strict target JSON, explicit-cell preservation, shared-path and state-bound conflict resolution, trusted-risk gates, zero-mutation unresolved plans, Workspace Manifest previews, Local Modification protection, resilient per-target progress/results, and receipts.
 * [POS]: Serves as deterministic domain coverage beneath the public CLI command-flow contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package plan

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
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

func TestBuildRejectsPathLikeSkillNames(t *testing.T) {
	for _, name := range []string{".", ".."} {
		_, err := Build(nil, &store.Entry{}, t.TempDir(), Request{Name: name, Targets: []TargetRequest{{}}})
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid Skill name")
	}
}

func TestBuildRejectsNameThatDiffersFromSkillInfo(t *testing.T) {
	root := t.TempDir()
	entry := testEntry(t, filepath.Join(root, "store"))
	catalog := agent.NewCatalog(agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root})
	_, err := Build(catalog, entry, entry.Root, Request{Name: "renamed-demo", Targets: []TargetRequest{{}}})
	require.Error(t, err)
	require.Contains(t, err.Error(), "Skill Info name")
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
	require.True(t, preflight.Targets[1].WorkspaceManifestChange)
	require.Equal(t, filepath.Join(projectRoot, "skillsgo.yaml"), preflight.WorkspaceManifestChanges[0].Path)

	execution, err := Execute(entry, storeRoot, request, preflight)
	require.NoError(t, err)
	require.Equal(t, 2, execution.Summary.Succeeded)
	require.Zero(t, execution.Summary.Failed)
	for _, result := range execution.Results {
		require.Equal(t, OutcomeSucceeded, result.Outcome)
		require.FileExists(t, filepath.Join(result.Target.Path, "SKILL.md"))
	}
	installations, err := declaredInstallations(catalog, storeRoot, request.Targets)
	require.NoError(t, err)
	require.Len(t, installations, 2)
	manifest, err := project.LoadManifest(projectRoot)
	require.NoError(t, err)
	require.Equal(t, []string{"test-agent"}, manifest.Skills[entry.Receipt.SkillID].Agents)
	require.Equal(t, "v1", manifest.Skills[entry.Receipt.SkillID].Ref)

	second, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.Zero(t, second.Summary.Create)
	require.Equal(t, 2, second.Summary.Skip)
	require.Empty(t, second.WorkspaceManifestChanges)
	secondExecution, err := Execute(entry, storeRoot, request, second)
	require.NoError(t, err)
	require.Equal(t, 2, secondExecution.Summary.Skipped)
	require.Zero(t, secondExecution.Summary.Succeeded)
}

func TestRetryReconcilesProjectManifestAfterArtifactWasAlreadyInstalled(t *testing.T) {
	root := t.TempDir()
	projectRoot := filepath.Join(root, "project")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	require.NoError(t, os.MkdirAll(filepath.Join(root, "agent-a"), 0o700))
	require.NoError(t, os.MkdirAll(filepath.Join(root, "agent-b"), 0o700))
	entry := testEntry(t, storeRoot)
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{
			ID: "agent-a", Display: "Agent A", ProjectDir: ".agent-a/skills",
			UserDir: filepath.Join(root, "agent-a", "skills"),
		}),
		agent.WithDefinition(agent.Definition{
			ID: "agent-b", Display: "Agent B", ProjectDir: ".agent-b/skills",
			UserDir: filepath.Join(root, "agent-b", "skills"),
		}),
	)
	requestA := Request{
		Source: entry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{
			Scope: install.ScopeProject, ProjectRoot: projectRoot,
			Agent: "agent-a", Mode: install.ModeCopy,
		}},
	}
	preflightA, err := Build(catalog, entry, storeRoot, requestA)
	require.NoError(t, err)
	_, err = Execute(entry, storeRoot, requestA, preflightA)
	require.NoError(t, err)

	requestB := Request{
		Source: entry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{
			Scope: install.ScopeProject, ProjectRoot: projectRoot,
			Agent: "agent-b", Mode: install.ModeCopy,
		}},
	}
	preflightB, err := Build(catalog, entry, storeRoot, requestB)
	require.NoError(t, err)
	require.Equal(t, ActionCreate, preflightB.Targets[0].Action)
	require.NoError(t, install.Install(entry, []install.Target{installTarget(preflightB.Targets[0].Target)}))

	retry, err := Build(catalog, entry, storeRoot, requestB)
	require.NoError(t, err)
	require.Equal(t, ActionSkip, retry.Targets[0].Action)
	require.True(t, retry.Targets[0].WorkspaceManifestChange)
	execution, err := Execute(entry, storeRoot, requestB, retry)
	require.NoError(t, err)
	require.Equal(t, OutcomeSkipped, execution.Results[0].Outcome)

	manifest, err := project.LoadManifest(projectRoot)
	require.NoError(t, err)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, manifest.Skills[entry.Receipt.SkillID].Agents)
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
	installations, err := declaredInstallations(catalog, storeRoot, request.Targets)
	require.NoError(t, err)
	require.Len(t, installations, 2)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, []string{
		installations[0].Target.Agent,
		installations[1].Target.Agent,
	})
}

func TestExecuteWithProgressRetainsSuccessfulTargetsAfterUnrelatedFailure(t *testing.T) {
	root := t.TempDir()
	goodHome := filepath.Join(root, "good-agent")
	badHome := filepath.Join(root, "bad-agent")
	storeRoot := filepath.Join(root, "store")
	require.NoError(t, os.MkdirAll(goodHome, 0o700))
	require.NoError(t, os.MkdirAll(badHome, 0o700))
	entry := testEntry(t, storeRoot)
	catalog := agent.NewCatalog(
		agent.Paths{Home: root, ConfigHome: filepath.Join(root, "config"), CWD: root},
		agent.WithDefinition(agent.Definition{ID: "good", Display: "Good", UserDir: filepath.Join(goodHome, "skills")}),
		agent.WithDefinition(agent.Definition{ID: "bad", Display: "Bad", UserDir: filepath.Join(badHome, "skills")}),
	)
	request := Request{
		Source: entry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{
			{Scope: install.ScopeUser, Agent: "good", Mode: install.ModeCopy},
			{Scope: install.ScopeUser, Agent: "bad", Mode: install.ModeCopy},
		},
	}
	preflight, err := Build(catalog, entry, storeRoot, request)
	require.NoError(t, err)
	require.NoError(t, os.RemoveAll(badHome))
	require.NoError(t, os.WriteFile(badHome, []byte("blocks directory creation"), 0o600))
	progress := make([]Progress, 0)

	execution, err := ExecuteWithProgress(entry, storeRoot, request, preflight, func(event Progress) {
		progress = append(progress, event)
	})
	require.NoError(t, err)
	require.Equal(t, 1, execution.Summary.Succeeded)
	require.Equal(t, 1, execution.Summary.Failed)
	require.Equal(t, OutcomeSucceeded, execution.Results[0].Outcome)
	require.Equal(t, OutcomeFailed, execution.Results[1].Outcome)
	require.FileExists(t, filepath.Join(preflight.Targets[0].Target.Path, "SKILL.md"))
	require.Len(t, progress, 4)
	require.Equal(t, []ProgressState{ProgressStarted, ProgressFinished, ProgressStarted, ProgressFinished}, []ProgressState{
		progress[0].State, progress[1].State, progress[2].State, progress[3].State,
	})
	require.Equal(t, OutcomeSucceeded, progress[1].Result.Outcome)
	require.Equal(t, OutcomeFailed, progress[3].Result.Outcome)
	for index, event := range progress {
		require.Equal(t, index+1, event.Sequence)
		require.Equal(t, preflight.Artifact, event.Artifact)
	}
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
	require.True(t, conflicted.Targets[0].WorkspaceManifestChange)
	require.Equal(t, "v1", conflicted.WorkspaceManifestChanges[0].FromVersion)
	require.Equal(t, "v2", conflicted.WorkspaceManifestChanges[0].ToVersion)
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
		Source: entry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
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
		Source: oldEntry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeCopy}},
	}
	initial, err := Build(catalog, oldEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(oldEntry, storeRoot, request, initial)
	require.NoError(t, err)
	targetPath := initial.Targets[0].Target.Path

	request.Source = newEntry.Receipt.SkillID
	blocked, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionConflict, blocked.Targets[0].Action)
	require.Equal(t, "skill-id-collision", blocked.Targets[0].ReasonCode)
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
	installations, err := declaredInstallations(catalog, storeRoot, request.Targets)
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.Equal(t, newEntry.Receipt.SkillID, installations[0].SkillID)
}

func TestAutoReplaceOverwritesSameNameSkillWithoutSeparateReview(t *testing.T) {
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
		Source: oldEntry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{{Scope: install.ScopeUser, Agent: "test-agent", Mode: install.ModeCopy}},
	}
	initial, err := Build(catalog, oldEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(oldEntry, storeRoot, request, initial)
	require.NoError(t, err)

	request.Source = newEntry.Receipt.SkillID
	request.AutoReplace = true
	replacement, err := Build(catalog, newEntry, storeRoot, request)
	require.NoError(t, err)
	require.Equal(t, ActionReplace, replacement.Targets[0].Action)
	require.Equal(t, "skill-id-collision", replacement.Targets[0].ReasonCode)
	execution, err := Execute(newEntry, storeRoot, request, replacement)
	require.NoError(t, err)
	require.Equal(t, 1, execution.Summary.Succeeded)
	requireFileContains(t, filepath.Join(agentHome, "skills", "demo", "SKILL.md"), "new identity")
	installations, err := declaredInstallations(catalog, storeRoot, request.Targets)
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.Equal(t, newEntry.Receipt.SkillID, installations[0].SkillID)
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
		Source: oldEntry.Receipt.SkillID, RequestedRef: "main", Name: "demo",
		Targets: []TargetRequest{
			{Scope: install.ScopeProject, ProjectRoot: projectRoot, Agent: "agent-a", Mode: install.ModeCopy},
			{Scope: install.ScopeProject, ProjectRoot: projectRoot, Agent: "agent-b", Mode: install.ModeCopy},
		},
	}
	initial, err := Build(catalog, oldEntry, storeRoot, request)
	require.NoError(t, err)
	_, err = Execute(oldEntry, storeRoot, request, initial)
	require.NoError(t, err)

	request.Source = newEntry.Receipt.SkillID
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
	manifest, err := project.LoadManifest(projectRoot)
	require.NoError(t, err)
	require.ElementsMatch(t, []string{"agent-a", "agent-b"}, manifest.Skills[newEntry.Receipt.SkillID].Agents)
	require.Equal(t, newEntry.Receipt.SkillID, manifest.Skills[newEntry.Receipt.SkillID].Source)
	require.Equal(t, newEntry.Receipt.Version, manifest.Skills[newEntry.Receipt.SkillID].Ref)
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
	entry.Receipt.Name = "danger"
	entry.Receipt.Risk = hub.RiskHigh
	request := Request{
		Source: entry.Receipt.SkillID, RequestedRef: "main", Name: "danger",
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

	entry.Receipt.Risk = hub.RiskCritical
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

func testEntryVersion(t *testing.T, root, skillID, version, content string) *store.Entry {
	t.Helper()
	entryRoot := filepath.Join(root, filepath.FromSlash(skillID+"@"+version))
	artifact := filepath.Join(entryRoot, "artifact")
	require.NoError(t, os.MkdirAll(artifact, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(artifact, "SKILL.md"), []byte("# "+content+"\n"), 0o600))
	contentDigest, err := hub.ContentDirectoryDigest(artifact)
	require.NoError(t, err)
	entry := &store.Entry{
		Root: entryRoot, Artifact: artifact,
		Receipt: store.Receipt{
			SkillID: skillID, Name: "demo", Version: version, SHA256: "sha256-" + version,
			ContentDigest: contentDigest, Risk: hub.RiskLow,
		},
	}
	receipt, err := yaml.Marshal(entry.Receipt)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(entryRoot, "receipt.yaml"), receipt, 0o600))
	return entry
}
