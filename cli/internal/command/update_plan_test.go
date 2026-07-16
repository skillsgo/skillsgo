/*
 * [INPUT]: Uses command.Execute with explicit managed target identities, temporary Store receipts, and a fixture Hub.
 * [OUTPUT]: Specifies per-target source resolution, pinned-commit exclusion, exact-target update execution, shared Workspace binding rules, Workspace Lock reconciliation, and structured progress/results.
 * [POS]: Serves as the public CLI contract coverage for App-driven Update Plans.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/stretchr/testify/require"
)

func TestExplicitUpdatePlanResolvesOwnReferencesAndUpdatesOnlySelectedTarget(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	t.Setenv("HOME", home)
	skillID := "github.com/example/skills/-/skills/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "feature", "old-feature")
	fixedCommit := strings.Repeat("a", 40)
	fixedEntry := updatePlanTestStoreEntry(t, storage, skillID, "v-fixed", fixedCommit, fixedCommit)
	selectedTarget := install.Target{
		Agent: "test-agent", Scope: install.ScopeUser, Mode: install.ModeCopy,
		Path: filepath.Join(root, "selected", "demo"),
	}
	unselectedTarget := install.Target{
		Agent: "codex", Scope: install.ScopeUser, Mode: install.ModeCopy,
		Path: filepath.Join(root, "unselected", "demo"),
	}
	require.NoError(t, install.Install(oldEntry, []install.Target{selectedTarget}))
	require.NoError(t, install.Install(fixedEntry, []install.Target{unselectedTarget}))

	newZIP := commandTestZIP(t, skillID+"@v2/", map[string]string{"SKILL.md": "new-main"})
	newDigest := commandTestContentDigest(t, newZIP, skillID, "v2")
	var resolvedPaths []string
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		resolvedPaths = append(resolvedPaths, request.URL.Path)
		switch {
		case strings.HasSuffix(request.URL.Path, "/feature.info"), strings.HasSuffix(request.URL.Path, "/v2.info"):
			fmt.Fprintf(writer, `{"Version":"v2","Time":"2026-07-15T00:00:00Z","Risk":"low","ContentDigest":%q,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"refs/heads/feature","CommitSHA":"new-feature","TreeSHA":"new-tree"}}`, newDigest)
		case strings.HasSuffix(request.URL.Path, "/v2.manifest"):
			fmt.Fprint(writer, "name: demo\ndescription: update test\n")
		case strings.HasSuffix(request.URL.Path, "/v2.zip"):
			_, _ = writer.Write(newZIP)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	targetJSON := func(target install.Target, version string) string {
		body, err := json.Marshal(map[string]any{
			"scope": target.Scope, "agent": target.Agent, "mode": target.Mode,
			"path": target.Path, "skillId": skillID, "version": version,
		})
		require.NoError(t, err)
		return string(body)
	}
	var output bytes.Buffer
	require.NoError(t, Execute([]string{
		"update",
		"--target", targetJSON(selectedTarget, "v1"),
		"--target", targetJSON(unselectedTarget, "v-fixed"),
		"--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var preflight struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		Targets       []struct {
			Action     string `json:"action"`
			SourceRef  string `json:"sourceRef"`
			ToVersion  string `json:"toVersion"`
			StateToken string `json:"stateToken"`
			ReasonCode string `json:"reasonCode"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Equal(t, 1, preflight.SchemaVersion)
	require.Equal(t, "update-preflight", preflight.Phase)
	require.Len(t, preflight.Targets, 2)
	require.Equal(t, "update", preflight.Targets[0].Action)
	require.Equal(t, "feature", preflight.Targets[0].SourceRef)
	require.Equal(t, "v2", preflight.Targets[0].ToVersion)
	require.NotEmpty(t, preflight.Targets[0].StateToken)
	require.Equal(t, "pinned", preflight.Targets[1].Action)
	require.Equal(t, "fixed-commit", preflight.Targets[1].ReasonCode)
	require.Len(t, resolvedPaths, 1)

	selectedExecution, err := json.Marshal(map[string]any{
		"scope": selectedTarget.Scope, "agent": selectedTarget.Agent, "mode": selectedTarget.Mode,
		"path": selectedTarget.Path, "skillId": skillID, "version": "v1",
		"toVersion": preflight.Targets[0].ToVersion, "stateToken": preflight.Targets[0].StateToken,
	})
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{
		"update", "--target", string(selectedExecution),
		"--output", "ndjson", "--hub", server.URL,
	}, &output, &output))
	lines := strings.Split(strings.TrimSpace(output.String()), "\n")
	require.Len(t, lines, 3)
	require.Contains(t, lines[0], `"phase":"update-progress"`)
	require.Contains(t, lines[2], `"phase":"update-execution"`)
	var execution struct {
		Results []struct {
			Outcome    string `json:"outcome"`
			Diagnostic string `json:"diagnostic"`
		} `json:"results"`
	}
	require.NoError(t, json.Unmarshal([]byte(lines[2]), &execution))
	require.Equal(t, "succeeded", execution.Results[0].Outcome, execution.Results[0].Diagnostic)

	installations, err := install.ListInstallations(storage.Root, install.InventoryFilter{})
	require.NoError(t, err)
	versions := map[string]string{}
	for _, installation := range installations {
		versions[installation.Target.Path] = installation.Version
	}
	require.Equal(t, "v2", versions[selectedTarget.Path])
	require.Equal(t, "v-fixed", versions[unselectedTarget.Path])
}

func TestExplicitUpdatePlanRetainsSuccessAndUpdatesWorkspaceLockOnlyAfterTargetSuccess(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "project")
	t.Setenv("HOME", home)
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	skillID := "github.com/example/skills/-/skills/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old-main")
	userTarget := install.Target{
		Agent: "user-agent", Scope: install.ScopeUser, Mode: install.ModeCopy,
		Path: filepath.Join(root, "user", "demo"),
	}
	projectTarget := install.Target{
		Agent: "project-agent", Scope: install.ScopeProject, Mode: install.ModeCopy,
		Path: filepath.Join(projectRoot, ".project-agent", "skills", "demo"),
	}
	require.NoError(t, install.Install(oldEntry, []install.Target{userTarget, projectTarget}))
	require.NoError(t, project.Upsert(
		projectRoot,
		"demo",
		project.SkillRequirement{
			Source: skillID, Ref: "main", Agents: []string{"project-agent"}, Mode: install.ModeCopy,
		},
		oldEntry.Receipt,
	))

	newZIP := commandTestZIP(t, skillID+"@v2/", map[string]string{"SKILL.md": "new"})
	newDigest := commandTestContentDigest(t, newZIP, skillID, "v2")
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/main.info"), strings.HasSuffix(request.URL.Path, "/v2.info"):
			fmt.Fprintf(writer, `{"Version":"v2","Time":"2026-07-15T00:00:00Z","Risk":"low","ContentDigest":%q,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"refs/heads/main","CommitSHA":"new","TreeSHA":"new-tree"}}`, newDigest)
		case strings.HasSuffix(request.URL.Path, "/v2.manifest"):
			fmt.Fprint(writer, "name: demo\n")
		case strings.HasSuffix(request.URL.Path, "/v2.zip"):
			_, _ = writer.Write(newZIP)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	requestJSON := func(target install.Target, projectRoot, toVersion, stateToken string) string {
		body, err := json.Marshal(map[string]any{
			"scope": target.Scope, "projectRoot": projectRoot,
			"agent": target.Agent, "mode": target.Mode, "path": target.Path,
			"skillId": skillID, "version": "v1",
			"toVersion": toVersion, "stateToken": stateToken,
		})
		require.NoError(t, err)
		return string(body)
	}
	baseRequests := []string{
		requestJSON(userTarget, "", "", ""),
		requestJSON(projectTarget, projectRoot, "", ""),
	}
	var output bytes.Buffer
	require.NoError(t, Execute([]string{
		"update", "--target", baseRequests[0], "--target", baseRequests[1],
		"--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var preflight struct {
		Targets []struct {
			ToVersion  string `json:"toVersion"`
			StateToken string `json:"stateToken"`
		} `json:"targets"`
		WorkspaceLockChanges []map[string]any `json:"workspaceLockChanges"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Len(t, preflight.WorkspaceLockChanges, 1)
	require.Equal(t, projectRoot, preflight.WorkspaceLockChanges[0]["projectRoot"])

	backup := projectTarget.Path + ".skillsgo-backup"
	require.NoError(t, os.MkdirAll(backup, 0o700))
	output.Reset()
	require.NoError(t, Execute([]string{
		"update",
		"--target", requestJSON(userTarget, "", preflight.Targets[0].ToVersion, preflight.Targets[0].StateToken),
		"--target", requestJSON(projectTarget, projectRoot, preflight.Targets[1].ToVersion, preflight.Targets[1].StateToken),
		"--output", "ndjson", "--hub", server.URL,
	}, &output, &output))
	lines := strings.Split(strings.TrimSpace(output.String()), "\n")
	require.Len(t, lines, 5)
	var execution struct {
		Summary struct {
			Succeeded int `json:"succeeded"`
			Failed    int `json:"failed"`
		} `json:"summary"`
	}
	require.NoError(t, json.Unmarshal([]byte(lines[4]), &execution))
	require.Equal(t, 1, execution.Summary.Succeeded)
	require.Equal(t, 1, execution.Summary.Failed)
	_, lockfile, err := project.Load(projectRoot)
	require.NoError(t, err)
	require.Equal(t, "v1", lockfile.Skills["demo"].Version)

	require.NoError(t, os.RemoveAll(backup))
	output.Reset()
	require.NoError(t, Execute([]string{
		"update", "--target", baseRequests[1],
		"--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	preflight.Targets = nil
	preflight.WorkspaceLockChanges = nil
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Len(t, preflight.Targets, 1)
	output.Reset()
	require.NoError(t, Execute([]string{
		"update",
		"--target", requestJSON(projectTarget, projectRoot, preflight.Targets[0].ToVersion, preflight.Targets[0].StateToken),
		"--output", "ndjson", "--hub", server.URL,
	}, &output, &output))
	_, lockfile, err = project.Load(projectRoot)
	require.NoError(t, err)
	require.Equal(t, "v2", lockfile.Skills["demo"].Version)
}

func TestExplicitUpdatePlanRequiresAndSwitchesEverySharedBinding(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	t.Setenv("HOME", home)
	skillID := "github.com/example/skills/-/skills/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
	sharedPath := filepath.Join(root, "shared", "demo")
	targets := []install.Target{
		{Agent: "agent-a", Scope: install.ScopeUser, Mode: install.ModeCopy, Path: sharedPath},
		{Agent: "agent-b", Scope: install.ScopeUser, Mode: install.ModeCopy, Path: sharedPath},
	}
	require.NoError(t, install.Install(oldEntry, targets))
	requestJSON := func(target install.Target, toVersion, stateToken string) string {
		body, err := json.Marshal(map[string]any{
			"scope": target.Scope, "agent": target.Agent, "mode": target.Mode,
			"path": target.Path, "skillId": skillID, "version": "v1",
			"toVersion": toVersion, "stateToken": stateToken,
		})
		require.NoError(t, err)
		return string(body)
	}
	var output bytes.Buffer
	err := Execute([]string{
		"update", "--target", requestJSON(targets[0], "", ""),
		"--preflight", "--output", "json", "--hub", "http://127.0.0.1:1",
	}, &output, &output)
	require.ErrorContains(t, err, "requires every affected Agent binding")

	newZIP := commandTestZIP(t, skillID+"@v2/", map[string]string{"SKILL.md": "new"})
	newDigest := commandTestContentDigest(t, newZIP, skillID, "v2")
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch {
		case strings.HasSuffix(request.URL.Path, "/main.info"), strings.HasSuffix(request.URL.Path, "/v2.info"):
			fmt.Fprintf(writer, `{"Version":"v2","Time":"2026-07-15T00:00:00Z","Risk":"low","ContentDigest":%q,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"refs/heads/main","CommitSHA":"new","TreeSHA":"new-tree"}}`, newDigest)
		case strings.HasSuffix(request.URL.Path, "/v2.manifest"):
			fmt.Fprint(writer, "name: demo\n")
		case strings.HasSuffix(request.URL.Path, "/v2.zip"):
			_, _ = writer.Write(newZIP)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()
	output.Reset()
	require.NoError(t, Execute([]string{
		"update",
		"--target", requestJSON(targets[0], "", ""),
		"--target", requestJSON(targets[1], "", ""),
		"--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var preflight struct {
		Targets []struct {
			ToVersion  string `json:"toVersion"`
			StateToken string `json:"stateToken"`
		} `json:"targets"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	output.Reset()
	require.NoError(t, Execute([]string{
		"update",
		"--target", requestJSON(targets[0], preflight.Targets[0].ToVersion, preflight.Targets[0].StateToken),
		"--target", requestJSON(targets[1], preflight.Targets[1].ToVersion, preflight.Targets[1].StateToken),
		"--output", "ndjson", "--hub", server.URL,
	}, &output, &output))
	installations, err := install.ListInstallations(storage.Root, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 2)
	for _, installation := range installations {
		require.Equal(t, "v2", installation.Version)
	}
}

func TestExplicitUpdatePlanRequiresEveryAgentDeclaredByWorkspaceLock(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "project")
	t.Setenv("HOME", home)
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	skillID := "github.com/example/skills/-/skills/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
	targets := []install.Target{
		{
			Agent: "agent-a", Scope: install.ScopeProject, Mode: install.ModeCopy,
			Path: filepath.Join(projectRoot, ".agent-a", "skills", "demo"),
		},
		{
			Agent: "agent-b", Scope: install.ScopeProject, Mode: install.ModeCopy,
			Path: filepath.Join(projectRoot, ".agent-b", "skills", "demo"),
		},
	}
	require.NoError(t, install.Install(oldEntry, targets))
	require.NoError(t, project.Upsert(
		projectRoot,
		"demo",
		project.SkillRequirement{
			Source: skillID, Ref: "main", Agents: []string{"agent-a", "agent-b"}, Mode: install.ModeCopy,
		},
		oldEntry.Receipt,
	))
	requestJSON := func(target install.Target) string {
		body, err := json.Marshal(map[string]any{
			"scope": target.Scope, "projectRoot": projectRoot,
			"agent": target.Agent, "mode": target.Mode, "path": target.Path,
			"skillId": skillID, "version": "v1",
		})
		require.NoError(t, err)
		return string(body)
	}
	var output bytes.Buffer
	err := Execute([]string{
		"update", "--target", requestJSON(targets[0]),
		"--preflight", "--output", "json", "--hub", "http://127.0.0.1:1",
	}, &output, &output)
	require.ErrorContains(t, err, "requires every declared Agent target")

	newZIP := commandTestZIP(t, skillID+"@v2/", map[string]string{"SKILL.md": "new"})
	newDigest := commandTestContentDigest(t, newZIP, skillID, "v2")
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if strings.HasSuffix(request.URL.Path, "/main.info") {
			fmt.Fprintf(writer, `{"Version":"v2","Time":"2026-07-15T00:00:00Z","Risk":"low","ContentDigest":%q,"Origin":{"VCS":"git","URL":"https://github.com/example/skills","Subdir":"skills/demo","Ref":"refs/heads/main","CommitSHA":"new","TreeSHA":"new-tree"}}`, newDigest)
			return
		}
		http.NotFound(writer, request)
	}))
	defer server.Close()
	output.Reset()
	require.NoError(t, Execute([]string{
		"update",
		"--target", requestJSON(targets[0]),
		"--target", requestJSON(targets[1]),
		"--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var preflight struct {
		Targets []struct {
			AffectedBindings []map[string]any `json:"affectedBindings"`
		} `json:"targets"`
		WorkspaceLockChanges []map[string]any `json:"workspaceLockChanges"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Len(t, preflight.Targets, 2)
	require.Len(t, preflight.Targets[0].AffectedBindings, 2)
	require.Len(t, preflight.Targets[1].AffectedBindings, 2)
	require.Len(t, preflight.WorkspaceLockChanges, 1)
}

func TestExplicitUpdatePlanReconcilesWorkspaceLockAfterTargetAlreadySwitched(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	projectRoot := filepath.Join(root, "project")
	t.Setenv("HOME", home)
	require.NoError(t, os.MkdirAll(projectRoot, 0o700))
	skillID := "github.com/example/skills/-/skills/demo"
	storage := store.Store{Root: store.DefaultRoot(home)}
	oldEntry := updatePlanTestStoreEntry(t, storage, skillID, "v1", "main", "old")
	newEntry := updatePlanTestStoreEntry(t, storage, skillID, "v2", "main", "new")
	target := install.Target{
		Agent: "project-agent", Scope: install.ScopeProject, Mode: install.ModeCopy,
		Path: filepath.Join(projectRoot, ".project-agent", "skills", "demo"),
	}
	require.NoError(t, install.Install(oldEntry, []install.Target{target}))
	require.NoError(t, project.Upsert(
		projectRoot,
		"demo",
		project.SkillRequirement{
			Source: skillID, Ref: "main", Agents: []string{"project-agent"}, Mode: install.ModeCopy,
		},
		oldEntry.Receipt,
	))
	installations, err := install.ListInstallations(storage.Root, install.InventoryFilter{})
	require.NoError(t, err)
	require.Len(t, installations, 1)
	require.NoError(t, install.Replace(newEntry, installations, []install.Target{target}))

	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if strings.HasSuffix(request.URL.Path, "/main.info") {
			payload, marshalErr := json.Marshal(hub.Info{
				Version:       newEntry.Receipt.Version,
				Risk:          newEntry.Receipt.Risk,
				ContentDigest: newEntry.Receipt.ContentDigest,
				Origin:        newEntry.Receipt.Origin,
			})
			require.NoError(t, marshalErr)
			_, _ = writer.Write(payload)
			return
		}
		http.NotFound(writer, request)
	}))
	defer server.Close()
	requestJSON := func(toVersion, stateToken string) string {
		body, marshalErr := json.Marshal(map[string]any{
			"scope": target.Scope, "projectRoot": projectRoot,
			"agent": target.Agent, "mode": target.Mode, "path": target.Path,
			"skillId": skillID, "version": "v2",
			"toVersion": toVersion, "stateToken": stateToken,
		})
		require.NoError(t, marshalErr)
		return string(body)
	}

	var output bytes.Buffer
	require.NoError(t, Execute([]string{
		"update", "--target", requestJSON("", ""),
		"--preflight", "--output", "json", "--hub", server.URL,
	}, &output, &output))
	var preflight struct {
		Targets []struct {
			Action      string `json:"action"`
			ReasonCode  string `json:"reasonCode"`
			FromVersion string `json:"fromVersion"`
			ToVersion   string `json:"toVersion"`
			StateToken  string `json:"stateToken"`
		} `json:"targets"`
		WorkspaceLockChanges []struct {
			FromVersion string `json:"fromVersion"`
			ToVersion   string `json:"toVersion"`
		} `json:"workspaceLockChanges"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Len(t, preflight.Targets, 1)
	require.Equal(t, "update", preflight.Targets[0].Action)
	require.Equal(t, "workspace-lock-reconcile", preflight.Targets[0].ReasonCode)
	require.Equal(t, "v2", preflight.Targets[0].FromVersion)
	require.Equal(t, "v2", preflight.Targets[0].ToVersion)
	require.Equal(t, "v1", preflight.WorkspaceLockChanges[0].FromVersion)
	require.Equal(t, "v2", preflight.WorkspaceLockChanges[0].ToVersion)

	output.Reset()
	require.NoError(t, Execute([]string{
		"update", "--target", requestJSON(preflight.Targets[0].ToVersion, preflight.Targets[0].StateToken),
		"--output", "ndjson", "--hub", server.URL,
	}, &output, &output))
	_, lockfile, err := project.Load(projectRoot)
	require.NoError(t, err)
	require.Equal(t, "v2", lockfile.Skills["demo"].Version)
	installations, err = install.ListInstallations(storage.Root, install.InventoryFilter{})
	require.NoError(t, err)
	require.Equal(t, "v2", installations[0].Version)
}

func updatePlanTestStoreEntry(
	t *testing.T,
	storage store.Store,
	skillID,
	version,
	requestedRef,
	commitSHA string,
) *store.Entry {
	t.Helper()
	zipData := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{"SKILL.md": version})
	entry, err := storage.Put(&hub.Artifact{
		SkillID: skillID,
		Info: hub.Info{
			Version: version, Risk: hub.RiskLow,
			ContentDigest: commandTestContentDigest(t, zipData, skillID, version),
			Origin: hub.Origin{
				VCS: "git", URL: "https://github.com/example/skills", Subdir: "skills/demo",
				Ref: "refs/heads/" + requestedRef, CommitSHA: commitSHA, TreeSHA: "tree-" + commitSHA,
			},
		},
		Manifest: []byte("name: demo\n"),
		ZIP:      zipData,
	})
	require.NoError(t, err)
	return entry
}
