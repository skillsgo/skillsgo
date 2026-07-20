/*
 * [INPUT]: Uses command.Execute with an isolated HOME, the current skills.sh user lock, and one externally copied Skill under the test Agent root.
 * [OUTPUT]: Specifies non-authoritative-write preflight, exact location counts, complete lock-identity and target-state revalidation, bounded and validated plans, scope-isolated lock-authoritative Batch Takeover, named partial results, content-preserving Store capture, normal declaration/receipt state, managed inventory, captured repair, and alias-safe removal through the public CLI seam.
 * [POS]: Serves as the executable contract for the lock-backed Batch Takeover journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/managementplan"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func executeTakeover(t *testing.T, stdout, stderr *bytes.Buffer, scopeArgs ...string) error {
	t.Helper()
	preflightArgs := append([]string{"takeover", "--preflight"}, scopeArgs...)
	preflightArgs = append(preflightArgs, "--output", "json")
	if err := Execute(preflightArgs, stdout, stderr); err != nil {
		return err
	}
	var preview takeoverPreflightReport
	if err := json.Unmarshal(stdout.Bytes(), &preview); err != nil {
		return err
	}
	stdout.Reset()
	executionArgs := append([]string{"takeover", "--plan", preview.PlanID}, scopeArgs...)
	executionArgs = append(executionArgs, "--yes", "--output", "json")
	return Execute(executionArgs, stdout, stderr)
}

func TestBatchTakeoverRegistersCurrentUserLockCopyWithoutChangingIt(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)

	target := filepath.Join(agentHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(filepath.Join(target, "scripts"), 0o755))
	require.NoError(t, os.WriteFile(
		filepath.Join(target, "SKILL.md"),
		[]byte("---\nname: demo\ndescription: existing user copy\n---\n# Demo\n"),
		0o644,
	))
	require.NoError(t, os.WriteFile(filepath.Join(target, "scripts", "run.sh"), []byte("#!/bin/sh\necho demo\n"), 0o755))
	beforeDigest, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)

	lockRoot := filepath.Join(home, ".agents")
	require.NoError(t, os.MkdirAll(lockRoot, 0o700))
	lock := map[string]any{
		"version": 3,
		"skills": map[string]any{
			"demo": map[string]any{
				"source":          "acme/skills",
				"sourceType":      "github",
				"sourceUrl":       "https://github.com/acme/skills.git",
				"ref":             "main",
				"skillPath":       "skills/demo/SKILL.md",
				"skillFolderHash": "tree-demo",
				"installedAt":     "2026-01-01T00:00:00Z",
				"updatedAt":       "2026-01-01T00:00:00Z",
			},
		},
	}
	lockBytes, err := json.Marshal(lock)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(lockRoot, ".skill-lock.json"), lockBytes, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	require.Empty(t, stderr.String())

	var result struct {
		SchemaVersion int `json:"schemaVersion"`
		Summary       struct {
			TakenOver int `json:"takenOver"`
			Skipped   int `json:"skipped"`
		} `json:"summary"`
		Results []struct {
			Name            string `json:"name"`
			SkillID         string `json:"skillId"`
			ArtifactSkillID string `json:"artifactSkillId"`
			Version         string `json:"version"`
			Status          string `json:"status"`
			Target          struct {
				Agent string        `json:"agent"`
				Scope install.Scope `json:"scope"`
				Mode  install.Mode  `json:"mode"`
				Path  string        `json:"path"`
			} `json:"target"`
		} `json:"results"`
	}
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, takeoverSchemaVersion, result.SchemaVersion)
	require.Equal(t, 1, result.Summary.TakenOver)
	require.Zero(t, result.Summary.Skipped)
	require.Len(t, result.Results, 1)
	require.Equal(t, "demo", result.Results[0].Name)
	require.Equal(t, "taken-over", result.Results[0].Status)
	require.Equal(t, "github.com/acme/skills/-/skills/demo", result.Results[0].SkillID)
	require.Equal(t, "test-agent", result.Results[0].Target.Agent)
	require.Equal(t, install.ScopeUser, result.Results[0].Target.Scope)
	require.Equal(t, install.ModeCopy, result.Results[0].Target.Mode)
	require.Equal(t, target, result.Results[0].Target.Path)

	afterDigest, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)
	require.Equal(t, beforeDigest, afterDigest)

	manifest, err := project.LoadManifest(project.UserRoot(home))
	require.NoError(t, err)
	require.Contains(t, manifest.Skills, result.Results[0].ArtifactSkillID)
	require.Equal(t, result.Results[0].Version, manifest.Skills[result.Results[0].ArtifactSkillID].Ref)
	require.Equal(t, []string{"test-agent"}, manifest.Skills[result.Results[0].ArtifactSkillID].Agents)

	entry, err := (store.Store{Root: store.DefaultRoot(home)}).Get(result.Results[0].ArtifactSkillID, result.Results[0].Version)
	require.NoError(t, err)
	require.Equal(t, beforeDigest, entry.Receipt.ContentDigest)
	require.Equal(t, result.Results[0].SkillID, entry.Receipt.SourceSkillID)
	require.Equal(t, store.Provenance("captured"), entry.Receipt.EffectiveProvenance())
	receipts, err := project.LoadInstallationReceipts(project.UserRoot(home))
	require.NoError(t, err)
	require.Len(t, receipts, 1)
	require.Equal(t, target, receipts[0].Path)
	require.Equal(t, install.ModeCopy, receipts[0].Mode)
	sum, err := project.LoadWorkspaceSum(project.UserRoot(home))
	require.NoError(t, err)
	checksum, err := project.ContentH1(beforeDigest)
	require.NoError(t, err)
	require.NoError(t, sum.Verify(project.SumEntry{
		Path: result.Results[0].ArtifactSkillID, Version: result.Results[0].Version,
		Checksum: checksum,
	}))

	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute([]string{"inventory", "--user", "--output", "json"}, &stdout, &stderr))
	var inventory inventoryReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &inventory))
	require.Len(t, inventory.Entries, 1)
	require.Equal(t, "hub:"+result.Results[0].SkillID, inventory.Entries[0].InventoryKey)
	require.Equal(t, result.Results[0].SkillID, inventory.Entries[0].SkillID)
	require.Equal(t, "healthy", string(inventory.Entries[0].Health))
	require.Len(t, inventory.Entries[0].Targets, 1)
	require.Equal(t, string(install.ModeCopy), string(inventory.Entries[0].Targets[0].Mode))

	stdout.Reset()
	stderr.Reset()
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	var repeated takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &repeated))
	require.Zero(t, repeated.Summary.TakenOver)
	require.Zero(t, repeated.Summary.Skipped)

	require.NoError(t, os.WriteFile(filepath.Join(target, "scripts", "run.sh"), []byte("modified"), 0o755))
	executeTakenOverTarget(t, home, result.Results[0].SkillID, result.Results[0].Version, "test-agent", install.ModeCopy, target, managementplan.ActionRepair)
	repairedDigest, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)
	require.Equal(t, beforeDigest, repairedDigest)
}

func TestBatchTakeoverReadsCurrentWorkspaceLock(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	workspace := filepath.Join(root, "workspace")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	require.NoError(t, os.MkdirAll(agentHome, 0o755))
	userTarget := filepath.Join(agentHome, "skills", "user-demo")
	require.NoError(t, os.MkdirAll(userTarget, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(userTarget, "SKILL.md"), []byte("---\nname: user-demo\ndescription: user copy\n---\n"), 0o644))
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	userLock, err := json.Marshal(map[string]any{
		"version": 3,
		"skills": map[string]any{
			"user-demo": map[string]any{
				"source": "acme/user-skills", "sourceType": "github",
				"sourceUrl": "https://github.com/acme/user-skills.git",
				"ref":       "main", "skillPath": "skills/user-demo/SKILL.md",
			},
		},
	})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), userLock, 0o600))
	target := filepath.Join(workspace, ".test-agent", "skills", "project-demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: project-demo\ndescription: workspace copy\n---\n"), 0o644))
	before, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)
	lock := map[string]any{
		"version": 1,
		"skills": map[string]any{
			"project-demo": map[string]any{
				"source": "acme/workspace-skills", "sourceType": "github",
				"sourceUrl": "https://github.com/acme/workspace-skills.git",
				"ref":       "release", "skillPath": "skills/project-demo/SKILL.md",
				"computedHash": "skills-sh-content-hash",
			},
		},
	}
	data, err := json.Marshal(lock)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(workspace, "skills-lock.json"), data, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--project", workspace))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 1, result.Summary.TakenOver)
	require.Zero(t, result.Summary.Skipped)
	require.Len(t, result.Results, 1)
	require.Equal(t, install.ScopeProject, result.Results[0].Target.Scope)
	require.Equal(t, "github.com/acme/workspace-skills/-/skills/project-demo", result.Results[0].SkillID)
	after, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)
	require.Equal(t, before, after)
	manifest, err := project.LoadManifest(workspace)
	require.NoError(t, err)
	require.Contains(t, manifest.Skills, result.Results[0].ArtifactSkillID)
	receipts, err := project.LoadInstallationReceipts(workspace)
	require.NoError(t, err)
	require.Len(t, receipts, 1)
	require.Equal(t, target, receipts[0].Path)
	_, err = project.LoadManifest(project.UserRoot(home))
	require.ErrorIs(t, err, os.ErrNotExist)
}

func TestBatchTakeoverKeepsDivergentCopiesIndependentAndDeduplicatesIdenticalBaselines(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	testAgentHome := filepath.Join(root, "test-agent")
	codexHome := filepath.Join(root, "codex")
	stateHome := filepath.Join(root, "state")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", testAgentHome)
	t.Setenv("CODEX_HOME", codexHome)
	t.Setenv("XDG_STATE_HOME", stateHome)
	writeCopy := func(path, body string) {
		require.NoError(t, os.MkdirAll(path, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), []byte("---\nname: demo\ndescription: copy\n---\n"+body), 0o644))
	}
	first := filepath.Join(testAgentHome, "skills", "demo")
	second := filepath.Join(codexHome, "skills", "demo")
	writeCopy(first, "first\n")
	writeCopy(second, "second\n")
	require.NoError(t, os.MkdirAll(filepath.Join(stateHome, "skills"), 0o700))
	lock := map[string]any{"version": 3, "skills": map[string]any{"demo": map[string]any{
		"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git",
		"skillPath": "skills/demo/SKILL.md", "skillFolderHash": "tree-demo",
	}}}
	data, err := json.Marshal(lock)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(stateHome, "skills", ".skill-lock.json"), data, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 2, result.Summary.TakenOver)
	require.Zero(t, result.Summary.Skipped)
	require.Len(t, result.Results, 2)
	require.NotEqual(t, result.Results[0].ArtifactSkillID, result.Results[1].ArtifactSkillID)

	manifest, err := project.LoadManifest(project.UserRoot(home))
	require.NoError(t, err)
	require.Len(t, manifest.Skills, 2)
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute([]string{"inventory", "--user", "--output", "json"}, &stdout, &stderr))
	var inventory inventoryReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &inventory))
	require.Len(t, inventory.Entries, 1)
	require.Equal(t, "github.com/acme/skills/-/skills/demo", inventory.Entries[0].SkillID)
	require.True(t, inventory.Entries[0].VersionDivergence)
	require.Len(t, inventory.Entries[0].Targets, 2)
	for _, target := range inventory.Entries[0].Targets {
		require.Equal(t, "healthy", string(target.Health))
	}

	// Once both targets contain the same complete content, a clean isolated
	// takeover stores one captured artifact and merges the Agent bindings.
	root2 := t.TempDir()
	home2 := filepath.Join(root2, "home")
	testAgentHome2 := filepath.Join(root2, "test-agent")
	codexHome2 := filepath.Join(root2, "codex")
	stateHome2 := filepath.Join(root2, "state")
	t.Setenv("HOME", home2)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", testAgentHome2)
	t.Setenv("CODEX_HOME", codexHome2)
	t.Setenv("XDG_STATE_HOME", stateHome2)
	writeCopy(filepath.Join(testAgentHome2, "skills", "demo"), "same\n")
	writeCopy(filepath.Join(codexHome2, "skills", "demo"), "same\n")
	require.NoError(t, os.MkdirAll(filepath.Join(stateHome2, "skills"), 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(stateHome2, "skills", ".skill-lock.json"), data, 0o600))
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 2, result.Summary.TakenOver)
	require.Len(t, result.Results, 2)
	require.Equal(t, result.Results[0].ArtifactSkillID, result.Results[1].ArtifactSkillID)
	manifest, err = project.LoadManifest(project.UserRoot(home2))
	require.NoError(t, err)
	require.Len(t, manifest.Skills, 1)
}

func TestBatchTakeoverGroupsSymlinkAliasesByPhysicalDirectory(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	testAgentHome := filepath.Join(root, "test-agent")
	codexHome := filepath.Join(root, "codex")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", testAgentHome)
	t.Setenv("CODEX_HOME", codexHome)
	physical := filepath.Join(testAgentHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(physical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(physical, "SKILL.md"), []byte("---\nname: demo\ndescription: alias\n---\n"), 0o644))
	alias := filepath.Join(codexHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(filepath.Dir(alias), 0o755))
	require.NoError(t, os.Symlink(physical, alias))
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	lock := map[string]any{"version": 3, "skills": map[string]any{"demo": map[string]any{
		"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git",
		"skillPath": "skills/demo/SKILL.md", "skillFolderHash": "tree-demo",
	}}}
	data, err := json.Marshal(lock)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), data, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 1, result.Summary.TakenOver)
	require.Zero(t, result.Summary.Skipped)
	require.Len(t, result.Results, 1)
	require.Len(t, result.Results[0].Targets, 2)
	receipts, err := project.LoadInstallationReceipts(project.UserRoot(home))
	require.NoError(t, err)
	require.Len(t, receipts, 2)
	modes := map[install.Mode]bool{}
	for _, receipt := range receipts {
		modes[receipt.Mode] = true
		require.Equal(t, "latest", receipt.SourceRef)
	}
	require.True(t, modes[install.ModeCopy])
	require.True(t, modes[install.ModeSymlink])
	link, err := os.Readlink(alias)
	require.NoError(t, err)
	require.Equal(t, physical, link)
	executeTakenOverTarget(t, home, result.Results[0].SkillID, result.Results[0].Version, "test-agent", install.ModeCopy, physical, managementplan.ActionRemove)
	require.FileExists(t, filepath.Join(alias, "SKILL.md"))
	receipts, err = project.LoadInstallationReceipts(project.UserRoot(home))
	require.NoError(t, err)
	require.Len(t, receipts, 1)
	require.Equal(t, alias, receipts[0].Path)
}

func executeTakenOverTarget(
	t *testing.T,
	home, skillID, version, agentID string,
	mode install.Mode,
	path string,
	action managementplan.Action,
) {
	t.Helper()
	paths, err := agent.DefaultPaths()
	require.NoError(t, err)
	catalog := agent.NewCatalog(paths, testAgentOption())
	storage := store.Store{Root: store.DefaultRoot(home)}
	request := managementplan.TargetRequest{
		Scope: install.ScopeUser, Agent: agentID, Mode: mode, Path: path,
		SkillID: skillID, Version: version,
	}
	preview, err := managementplan.Build(catalog, storage, []managementplan.TargetRequest{request})
	require.NoError(t, err)
	require.Len(t, preview.Targets, 1)
	request.Action = action
	request.StateToken = preview.Targets[0].StateToken
	selected, err := managementplan.Build(catalog, storage, []managementplan.TargetRequest{request})
	require.NoError(t, err)
	execution := managementplan.Execute(storage, selected, nil)
	require.Zero(t, execution.Summary.Failed, "%#v", execution.Results)
}

func TestBatchTakeoverScansKnownAgentDiscoveryRoots(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	codexHome := filepath.Join(root, "codex")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", "")
	t.Setenv("CODEX_HOME", codexHome)
	require.NoError(t, os.MkdirAll(codexHome, 0o755))
	target := filepath.Join(home, ".agents", "skills", "demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: demo\ndescription: shared discovery root\n---\n"), 0o644))
	lock := map[string]any{"version": 3, "skills": map[string]any{"demo": map[string]any{
		"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git",
		"skillPath": "skills/demo/SKILL.md", "skillFolderHash": "tree-demo",
	}}}
	data, err := json.Marshal(lock)
	require.NoError(t, err)
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), data, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 1, result.Summary.TakenOver)
	require.Len(t, result.Results, 1)
	require.Equal(t, target, result.Results[0].Target.Path)
	stdout.Reset()
	stderr.Reset()
	require.NoError(t, Execute([]string{"inventory", "--user", "--output", "json"}, &stdout, &stderr))
	var inventory inventoryReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &inventory))
	require.Len(t, inventory.Entries, 1)
	require.Equal(t, "healthy", string(inventory.Entries[0].Health))
}

func TestBatchTakeoverSkipsInvalidMissingAndLockExternalTargetsIndependently(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	writeSkill := func(name string) string {
		path := filepath.Join(agentHome, "skills", name)
		require.NoError(t, os.MkdirAll(path, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(path, "SKILL.md"), []byte("---\nname: "+name+"\ndescription: preserved\n---\n"+name+"\n"), 0o644))
		return path
	}
	validPath := writeSkill("valid")
	invalidPath := writeSkill("invalid")
	externalPath := writeSkill("external")
	beforeInvalid, err := hub.ContentDirectoryDigest(invalidPath)
	require.NoError(t, err)
	beforeExternal, err := hub.ContentDirectoryDigest(externalPath)
	require.NoError(t, err)
	lock := map[string]any{"version": 3, "skills": map[string]any{
		"valid":   map[string]any{"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git", "skillPath": "skills/valid/SKILL.md", "skillFolderHash": "valid"},
		"invalid": map[string]any{"source": "../evil", "sourceType": "github", "sourceUrl": "file:///tmp/evil", "skillPath": "../SKILL.md", "skillFolderHash": "invalid"},
		"missing": map[string]any{"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git", "skillPath": "skills/missing/SKILL.md", "skillFolderHash": "missing"},
	}}
	data, err := json.Marshal(lock)
	require.NoError(t, err)
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), data, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 1, result.Summary.TakenOver)
	require.Equal(t, 3, result.Summary.Skipped)
	reasons := map[string]int{}
	for _, item := range result.Results {
		reasons[item.Reason]++
	}
	require.Equal(t, 1, reasons["invalid-lock-entry"])
	require.Equal(t, 1, reasons["missing-target"])
	require.Equal(t, 1, reasons["not-in-supported-lock"])
	_, err = os.Stat(validPath)
	require.NoError(t, err)
	afterInvalid, err := hub.ContentDirectoryDigest(invalidPath)
	require.NoError(t, err)
	afterExternal, err := hub.ContentDirectoryDigest(externalPath)
	require.NoError(t, err)
	require.Equal(t, beforeInvalid, afterInvalid)
	require.Equal(t, beforeExternal, afterExternal)
	receipts, err := project.LoadInstallationReceipts(project.UserRoot(home))
	require.NoError(t, err)
	require.Len(t, receipts, 1)
}

func TestBatchTakeoverPreflightReportsExactLocationCountsWithoutManagementWrites(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	workspace := filepath.Join(root, "workspace")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	userTarget := filepath.Join(agentHome, "skills", "user-demo")
	projectTarget := filepath.Join(workspace, ".test-agent", "skills", "project-demo")
	for target, name := range map[string]string{userTarget: "user-demo", projectTarget: "project-demo"} {
		require.NoError(t, os.MkdirAll(target, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: "+name+"\ndescription: existing\n---\n"), 0o644))
	}
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	userLock, err := json.Marshal(map[string]any{"version": 3, "skills": map[string]any{
		"user-demo": map[string]any{"source": "acme/user", "sourceType": "github", "sourceUrl": "https://github.com/acme/user.git", "skillPath": "skills/user-demo/SKILL.md"},
	}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), userLock, 0o600))
	projectLock, err := json.Marshal(map[string]any{"version": 1, "skills": map[string]any{
		"project-demo": map[string]any{"source": "acme/project", "sourceType": "github", "sourceUrl": "https://github.com/acme/project.git", "skillPath": "skills/project-demo/SKILL.md"},
	}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(workspace, "skills-lock.json"), projectLock, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"takeover", "--preflight", "--user", "--project", workspace, "--output", "json"}, &stdout, &stderr))
	var preview takeoverPreflightReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &preview))
	require.Equal(t, takeoverSchemaVersion, preview.SchemaVersion)
	require.Len(t, preview.PlanID, 64)
	require.Equal(t, 2, preview.Summary.Eligible)
	require.Equal(t, 1, preview.Scopes.User.Eligible)
	require.Equal(t, []takeoverProjectCount{{ProjectRoot: workspace, Eligible: 1}}, preview.Scopes.Projects)
	require.ElementsMatch(t, []takeoverPreview{
		{Name: "user-demo", SkillID: "github.com/acme/user/-/skills/user-demo", Scope: install.ScopeUser},
		{Name: "project-demo", SkillID: "github.com/acme/project/-/skills/project-demo", Scope: install.ScopeProject, ProjectRoot: workspace},
	}, preview.Previews)
	require.NoDirExists(t, store.DefaultRoot(home))
	require.NoDirExists(t, filepath.Join(project.UserRoot(home), "receipts"))
	require.NoFileExists(t, filepath.Join(project.UserRoot(home), "skillsgo.sum"))
	_, err = project.LoadManifest(project.UserRoot(home))
	require.ErrorIs(t, err, os.ErrNotExist)
	require.NoDirExists(t, filepath.Join(workspace, ".skillsgo", "receipts"))
	require.NoFileExists(t, filepath.Join(workspace, "skillsgo.sum"))
	_, err = project.LoadManifest(workspace)
	require.ErrorIs(t, err, os.ErrNotExist)
}

func TestBatchTakeoverCountsDeclarationScopeGroupsInSameUnitAsExecution(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	workspace := filepath.Join(root, "workspace")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	physical := filepath.Join(agentHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(physical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(physical, "SKILL.md"), []byte("---\nname: demo\ndescription: shared\n---\n"), 0o644))
	projectTarget := filepath.Join(workspace, ".test-agent", "skills", "demo")
	require.NoError(t, os.MkdirAll(projectTarget, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(projectTarget, "SKILL.md"), []byte("---\nname: demo\ndescription: project copy\n---\n"), 0o644))
	record := map[string]any{
		"source": "acme/skills", "sourceType": "github",
		"sourceUrl": "https://github.com/acme/skills.git", "skillPath": "skills/demo/SKILL.md",
	}
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	userLock, err := json.Marshal(map[string]any{"version": 3, "skills": map[string]any{"demo": record}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), userLock, 0o600))
	projectLock, err := json.Marshal(map[string]any{"version": 1, "skills": map[string]any{"demo": record}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(workspace, "skills-lock.json"), projectLock, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"takeover", "--preflight", "--user", "--project", workspace, "--output", "json"}, &stdout, &stderr))
	var plan takeoverPreflightReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &plan))
	require.Equal(t, 2, plan.Summary.Eligible)
	require.Equal(t, 1, plan.Scopes.User.Eligible)
	require.Equal(t, 1, plan.Scopes.Projects[0].Eligible)

	stdout.Reset()
	require.NoError(t, Execute([]string{"takeover", "--plan", plan.PlanID, "--user", "--project", workspace, "--yes", "--output", "json"}, &stdout, &stderr))
	var execution takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &execution))
	require.Equal(t, plan.Summary.Eligible, execution.Summary.TakenOver)
}

func TestBatchTakeoverExecutionSkipsOnlyCandidateChangedAfterPreflight(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	for _, name := range []string{"changed", "stable"} {
		target := filepath.Join(agentHome, "skills", name)
		require.NoError(t, os.MkdirAll(target, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: "+name+"\ndescription: existing\n---\n"), 0o644))
	}
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	lock, err := json.Marshal(map[string]any{"version": 3, "skills": map[string]any{
		"changed": map[string]any{"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git", "skillPath": "skills/changed/SKILL.md"},
		"stable":  map[string]any{"source": "acme/skills", "sourceType": "github", "sourceUrl": "https://github.com/acme/skills.git", "skillPath": "skills/stable/SKILL.md"},
	}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), lock, 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"takeover", "--preflight", "--user", "--output", "json"}, &stdout, &stderr))
	var preview takeoverPreflightReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &preview))
	require.Equal(t, 2, preview.Summary.Eligible)
	require.NoError(t, os.WriteFile(filepath.Join(agentHome, "skills", "changed", "SKILL.md"), []byte("changed after authorization"), 0o644))

	stdout.Reset()
	require.NoError(t, Execute([]string{"takeover", "--plan", preview.PlanID, "--user", "--yes", "--output", "json"}, &stdout, &stderr))
	var execution takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &execution))
	require.Equal(t, 1, execution.Summary.TakenOver)
	require.Equal(t, 1, execution.Summary.Skipped)
	require.Equal(t, "target-changed", execution.Results[0].Reason)
	receipts, err := project.LoadInstallationReceipts(project.UserRoot(home))
	require.NoError(t, err)
	require.Len(t, receipts, 1)
	require.Equal(t, filepath.Join(agentHome, "skills", "stable"), receipts[0].Path)
}

func TestBatchTakeoverExecutionRejectsLockRefChangedAfterPreflight(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: demo\ndescription: existing\n---\n"), 0o644))
	lockPath := filepath.Join(home, ".agents", ".skill-lock.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(lockPath), 0o700))
	writeLock := func(ref string) {
		data, err := json.Marshal(map[string]any{"version": 3, "skills": map[string]any{
			"demo": map[string]any{
				"source": "acme/skills", "sourceType": "github",
				"sourceUrl": "https://github.com/acme/skills.git",
				"skillPath": "skills/demo/SKILL.md", "ref": ref,
			},
		}})
		require.NoError(t, err)
		require.NoError(t, os.WriteFile(lockPath, data, 0o600))
	}
	writeLock("main")

	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"takeover", "--preflight", "--user", "--output", "json"}, &stdout, &stderr))
	var preview takeoverPreflightReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &preview))
	require.Equal(t, 1, preview.Summary.Eligible)
	writeLock("release")

	stdout.Reset()
	require.NoError(t, Execute([]string{"takeover", "--plan", preview.PlanID, "--user", "--yes", "--output", "json"}, &stdout, &stderr))
	var execution takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &execution))
	require.Zero(t, execution.Summary.TakenOver)
	require.Equal(t, 1, execution.Summary.Skipped)
	require.Equal(t, "target-changed", execution.Results[0].Reason)
	receipts, err := project.LoadInstallationReceipts(project.UserRoot(home))
	require.NoError(t, err)
	require.Empty(t, receipts)
}

func TestBatchTakeoverRejectsInvalidPlanIdentifier(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	var stdout, stderr bytes.Buffer
	err := Execute([]string{"takeover", "--plan", "../escape", "--user", "--yes", "--output", "json"}, &stdout, &stderr)
	require.EqualError(t, err, "Batch Takeover plan is missing or invalid")
}

func TestBatchTakeoverRejectsMalformedCachedPlan(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	planID := strings.Repeat("a", 64)
	require.NoError(t, saveTakeoverPlan(home, takeoverPlan{
		SchemaVersion: takeoverPlanSchemaVersion,
		PlanID:        planID,
		IncludeUser:   true,
		Candidates:    []takeoverCandidate{{Name: "demo"}},
	}))

	var stdout, stderr bytes.Buffer
	err := Execute([]string{"takeover", "--plan", planID, "--user", "--yes", "--output", "json"}, &stdout, &stderr)
	require.EqualError(t, err, "Batch Takeover plan is missing or invalid")
}

func TestBatchTakeoverPrunesExpiredAndBoundsEphemeralPlans(t *testing.T) {
	home := t.TempDir()
	now := time.Now()
	for index := 0; index < 40; index++ {
		planID := fmt.Sprintf("%064x", index+1)
		require.NoError(t, saveTakeoverPlan(home, takeoverPlan{PlanID: planID}))
	}
	expiredPath := takeoverPlanPath(home, fmt.Sprintf("%064x", 1))
	expiredAt := now.Add(-takeoverPlanTTL - time.Minute)
	require.NoError(t, os.Chtimes(expiredPath, expiredAt, expiredAt))

	require.NoError(t, pruneTakeoverPlans(home, now))
	entries, err := os.ReadDir(takeoverPlansRoot(home))
	require.NoError(t, err)
	require.Len(t, entries, takeoverPlansBeforeNewPlan)
	require.NoFileExists(t, expiredPath)
}

func TestReadSkillsShLockKeepsValidRecordsWhenOneRecordIsMalformed(t *testing.T) {
	lockPath := filepath.Join(t.TempDir(), ".skill-lock.json")
	require.NoError(t, os.WriteFile(lockPath, []byte(`{
  "version": 3,
  "skills": {
    "valid": {"source":"acme/skills","sourceType":"github"},
    "malformed": {"source":123,"sourceType":"github"}
  }
}`), 0o600))
	records, supported, err := readSkillsShLock(lockPath, 3)
	require.NoError(t, err)
	require.True(t, supported)
	require.False(t, records["valid"].Invalid)
	require.True(t, records["malformed"].Invalid)
	_, err = lockRecordSkillID(records["valid"])
	require.NoError(t, err)
	_, err = lockRecordSkillID(records["malformed"])
	require.Error(t, err)
}

func TestLockRecordSkillIDUsesProviderSemantics(t *testing.T) {
	gitID, err := lockRecordSkillID(skillsShUserLockRecord{
		Source: "display-label", SourceType: "git", SourceURL: "https://git.example.com/team/repo.git",
	})
	require.NoError(t, err)
	require.Equal(t, "git.example.com/team/repo", gitID)

	_, err = lockRecordSkillID(skillsShUserLockRecord{
		Source: "acme/local", SourceType: "local", SourceURL: "/tmp/local",
	})
	require.Error(t, err)

	_, err = lockRecordSkillID(skillsShUserLockRecord{
		Source: "huggingface/hf-skills/demo", SourceType: "huggingface",
		SourceURL: "https://huggingface.co/hf-skills/demo/blob/main/SKILL.md",
	})
	require.Error(t, err)
}

func TestBatchTakeoverHelpAndValidationAreLocalized(t *testing.T) {
	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"--lang", "zh-CN", "takeover", "--help"}, &stdout, &stderr))
	require.Contains(t, stdout.String(), "登记受支持的现有 skills.sh 安装")
	require.Contains(t, stdout.String(), "确认批量接管")
	require.Contains(t, stdout.String(), "包含用户级安装范围")

	stdout.Reset()
	stderr.Reset()
	err := Execute([]string{"--lang", "zh-CN", "takeover", "--output", "json"}, &stdout, &stderr)
	require.EqualError(t, err, "批量接管需要使用 --yes 明确确认")

	stdout.Reset()
	stderr.Reset()
	err = Execute([]string{"--lang", "zh-CN", "takeover", "--yes", "--output", "json"}, &stdout, &stderr)
	require.EqualError(t, err, "批量接管需要使用 --user 或至少一个 --project 指定范围")
}

func TestBatchTakeoverDoesNotAcceptLegacyLockSchemas(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	agentHome := filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := filepath.Join(agentHome, "skills", "demo")
	require.NoError(t, os.MkdirAll(target, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), []byte("---\nname: demo\ndescription: legacy\n---\n"), 0o644))
	before, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), []byte(`{"version":2,"skills":{"demo":{"source":"acme/skills"}}}`), 0o600))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Zero(t, result.Summary.TakenOver)
	require.Equal(t, 1, result.Summary.Skipped)
	require.Equal(t, "unsupported-lock", result.Results[0].Reason)
	after, err := hub.ContentDirectoryDigest(target)
	require.NoError(t, err)
	require.Equal(t, before, after)
	_, err = project.LoadManifest(project.UserRoot(home))
	require.ErrorIs(t, err, os.ErrNotExist)
}
