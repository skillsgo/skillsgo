/*
 * [INPUT]: Uses command.Execute, exact Repository version metadata/ZIP fixtures, a complete Repository Artifact, and temporary Workspace/Agent roots.
 * [OUTPUT]: Specifies exact-path add and inventory, Repository-level update, explicitly confirmed selective multi-Agent member/Agent removal, healthy zero-rewrite install, offline projection restoration, Local Modification preservation, Global Module Store restoration, and checksum-failure atomicity.
 * [POS]: Serves as the CLI command-seam acceptance test for Repository Module Store installation.
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
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/modulestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestAddExactRepositoryVersionCreatesWorkspaceModuleStoreAndSelectedProjection(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
		{Path: "README.md", Contents: []byte("shared"), Mode: 0o644},
		{Path: "SKILL.md", Contents: []byte("---\nname: root\ndescription: Root.\n---\n# Root\n"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("---\nname: review\ndescription: Review.\n---\n# Review\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info := protocolapi.ModuleInfo{
		SchemaVersion: 1, Kind: protocolapi.KindModule, ModulePath: modulePath, Version: version,
		Time: now, Sum: sum, ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.ModuleSkill{
			{Name: "root", Path: "."},
			{Name: "design", Path: "skills/design"},
			{Name: "review", Path: "skills/review"},
		},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + modulePath + "/versions/" + version:
			_, _ = writer.Write(infoBytes)
		case "/api/v1/" + modulePath + "/versions/" + version + ".zip":
			writer.Header().Set("Content-Length", fmt.Sprint(len(archive)))
			_, _ = writer.Write(archive)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	require.NoError(t, os.MkdirAll(home, 0o700))
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	t.Setenv("HOME", home)
	previous, err := os.Getwd()
	require.NoError(t, err)
	require.NoError(t, os.Chdir(workspace))
	t.Cleanup(func() { _ = os.Chdir(previous) })
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"add", modulePath + "@" + version, "--project", workspace, "--skill-path", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

	manifest, err := project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"skills/design"}, manifest.Dependencies[modulePath].Skills)
	require.Equal(t, []string{"codex"}, manifest.Dependencies[modulePath].Agents)
	lock, err := project.LoadDependencyLock(workspace)
	require.NoError(t, err)
	require.Equal(t, sum, lock.Dependencies[modulePath].Sum)
	moduleDir := modulestore.CoordinatePath(filepath.Join(workspace, ".skillsgo", "modules"), modulePath, version)
	require.FileExists(t, filepath.Join(moduleDir, "skills", "review", "SKILL.md"))
	projection := modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, version)
	require.FileExists(t, filepath.Join(projection, "README.md"))
	require.FileExists(t, filepath.Join(projection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "skills", "review", "SKILL.md"))
	var response struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		ModulePath    string `json:"modulePath"`
		ModuleDir     string `json:"moduleDir"`
		Projections   []struct {
			Agents []string `json:"agents"`
			Path   string   `json:"path"`
		} `json:"projections"`
		Workspace struct {
			Manifest string `json:"manifest"`
			Lock     string `json:"lock"`
		} `json:"workspace"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &response))
	require.Equal(t, 1, response.SchemaVersion)
	require.Equal(t, "module-install", response.Phase)
	require.Equal(t, modulePath, response.ModulePath)
	require.Equal(t, []string{"codex"}, response.Projections[0].Agents)
	expectedProjectionInfo, err := os.Stat(projection)
	require.NoError(t, err)
	responseProjectionInfo, err := os.Stat(response.Projections[0].Path)
	require.NoError(t, err)
	require.True(t, os.SameFile(expectedProjectionInfo, responseProjectionInfo))
	for expected, actual := range map[string]string{
		filepath.Join(workspace, project.WorkspaceManifestName): response.Workspace.Manifest,
		filepath.Join(workspace, project.DependencyLockName):    response.Workspace.Lock,
	} {
		expectedFile, statErr := os.Stat(expected)
		require.NoError(t, statErr)
		actualFile, statErr := os.Stat(actual)
		require.NoError(t, statErr)
		require.True(t, os.SameFile(expectedFile, actualFile))
	}
	expectedInfo, err := os.Stat(moduleDir)
	require.NoError(t, err)
	responseInfo, err := os.Stat(response.ModuleDir)
	require.NoError(t, err)
	require.True(t, os.SameFile(expectedInfo, responseInfo))
	output.Reset()
	require.NoError(t, Execute([]string{"list", "--project", workspace, "--output", "json"}, &output, &output))
	var inventory inventoryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &inventory))
	require.Len(t, inventory.Entries, 1)
	require.Equal(t, modulePath, inventory.Entries[0].ModulePath)
	require.Equal(t, []string{version}, inventory.Entries[0].Versions)
	require.Equal(t, filepath.Join(projection, "skills", "design"), inventory.Entries[0].Targets[0].Path)
	require.Equal(t, "healthy", string(inventory.Entries[0].Health))

	output.Reset()
	require.NoError(t, Execute([]string{"add", modulePath + "@" + version, "--skill", "root", "--agent", "goose", "--hub", server.URL, "--output", "json"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root", "skills/design"}, manifest.Dependencies[modulePath].Skills)
	require.Equal(t, []string{"codex", "goose"}, manifest.Dependencies[modulePath].Agents)
	for _, agentID := range []string{"codex", "goose"} {
		projectionRoot := modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, version)
		if agentID == "goose" {
			projectionRoot = modulestore.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), modulePath, version)
		}
		require.FileExists(t, filepath.Join(projectionRoot, "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "skills", "design", "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projectionRoot, "skills", "review", "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "README.md"))
	}

	output.Reset()
	err = Execute([]string{"remove", "skills/design", "--project", workspace, "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "--yes")
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root", "skills/design"}, manifest.Dependencies[modulePath].Skills)

	output.Reset()
	require.NoError(t, Execute([]string{"remove", "skills/design", "--project", workspace, "--yes", "--output", "json"}, &output, &output))
	var removal struct {
		SchemaVersion int      `json:"schemaVersion"`
		Phase         string   `json:"phase"`
		Skills        []string `json:"skills"`
		Scope         string   `json:"scope"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &removal))
	require.Equal(t, 1, removal.SchemaVersion)
	require.Equal(t, "module-remove", removal.Phase)
	require.Equal(t, []string{"skills/design"}, removal.Skills)
	require.Equal(t, "project", removal.Scope)
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root"}, manifest.Dependencies[modulePath].Skills)
	for _, projectionRoot := range []string{
		modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, version),
		modulestore.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), modulePath, version),
	} {
		require.FileExists(t, filepath.Join(projectionRoot, "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projectionRoot, "skills", "design", "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "README.md"))
	}
	require.FileExists(t, filepath.Join(moduleDir, "skills", "design", "SKILL.md"))

	output.Reset()
	require.NoError(t, Execute([]string{"remove", "root", "--agent", "goose", "--yes"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"codex"}, manifest.Dependencies[modulePath].Agents)
	require.FileExists(t, filepath.Join(modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, version), "SKILL.md"))
	require.NoDirExists(t, modulestore.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), modulePath, version))
	require.FileExists(t, filepath.Join(moduleDir, "SKILL.md"))

	codexProjection := modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, version)
	rootManifest := filepath.Join(codexProjection, "SKILL.md")
	beforeHealthy, err := os.Stat(rootManifest)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	afterHealthy, err := os.Stat(rootManifest)
	require.NoError(t, err)
	require.Equal(t, beforeHealthy.ModTime(), afterHealthy.ModTime())
	require.Contains(t, output.String(), `"status": "healthy"`)

	require.NoError(t, os.RemoveAll(moduleDir))
	require.NoError(t, os.RemoveAll(codexProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", server.URL, "--output", "json"}, &output, &output))
	require.FileExists(t, filepath.Join(moduleDir, "skills", "review", "SKILL.md"))
	require.FileExists(t, rootManifest)
	require.Contains(t, output.String(), `"status": "restored"`)

	require.NoError(t, os.RemoveAll(codexProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	require.FileExists(t, rootManifest)
	require.NoFileExists(t, filepath.Join(codexProjection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(codexProjection, "skills", "review", "SKILL.md"))
	require.Contains(t, output.String(), `"status": "restored"`)
	require.NoError(t, os.WriteFile(filepath.Join(codexProjection, "README.md"), []byte("user modification"), 0o644))
	output.Reset()
	err = Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "Repository installation group")
	require.Contains(t, output.String(), "Local Modification")
	modified, err := os.ReadFile(filepath.Join(codexProjection, "README.md"))
	require.NoError(t, err)
	require.Equal(t, "user modification", string(modified))

	output.Reset()
	require.NoError(t, Execute([]string{"add", modulePath + "@" + version, "--global", "--skill", "design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))
	userRoot := project.GlobalDeclarationRoot(home)
	require.FileExists(t, filepath.Join(userRoot, project.WorkspaceManifestName))
	require.FileExists(t, filepath.Join(userRoot, project.DependencyLockName))
	userModule := modulestore.CoordinatePath(filepath.Join(project.GlobalStateRoot(home), "modules"), modulePath, version)
	require.FileExists(t, filepath.Join(userModule, "skills", "review", "SKILL.md"))
	userProjection := modulestore.CoordinatePath(filepath.Join(home, ".codex", "skills"), modulePath, version)
	require.NoError(t, os.RemoveAll(userProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--global", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	require.FileExists(t, filepath.Join(userProjection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(userProjection, "skills", "review", "SKILL.md"))
}

func TestAddModuleSumMismatchLeavesNoWorkspaceState(t *testing.T) {
	modulePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info := protocolapi.ModuleInfo{
		SchemaVersion: 1, Kind: protocolapi.KindModule, ModulePath: modulePath, Version: version,
		Time: now,
		Sum:  "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.ModuleSkill{
			{Name: "design", Path: "skills/design"},
		},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + modulePath + "/versions/" + version:
			_, _ = writer.Write(infoBytes)
		case "/api/v1/" + modulePath + "/versions/" + version + ".zip":
			writer.Header().Set("Content-Length", fmt.Sprint(len(archive)))
			_, _ = writer.Write(archive)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	require.NoError(t, os.MkdirAll(home, 0o700))
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	t.Setenv("HOME", home)
	previous, err := os.Getwd()
	require.NoError(t, err)
	require.NoError(t, os.Chdir(workspace))
	t.Cleanup(func() { _ = os.Chdir(previous) })
	var output bytes.Buffer
	err = Execute([]string{"add", modulePath + "@" + version, "--skill", "design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "Repository Sum mismatch")

	require.NoFileExists(t, filepath.Join(workspace, project.WorkspaceManifestName))
	require.NoFileExists(t, filepath.Join(workspace, project.DependencyLockName))
	require.NoDirExists(t, filepath.Join(workspace, ".skillsgo", "modules", "github.com"))
	require.NoDirExists(t, filepath.Join(workspace, ".agents", "skills", "github.com"))
}

func TestUpdateRepositoryReplacesCoordinateAndPreservesSelections(t *testing.T) {
	modulePath := "github.com/example/skills"
	oldVersion, newVersion := "v1.2.0", "v1.3.0"
	type release struct {
		archive []byte
		info    []byte
		sum     string
	}
	releases := map[string]release{}
	for _, version := range []string{oldVersion, newVersion} {
		archive, err := protocolartifact.BuildModule(modulePath, version, []protocolartifact.Entry{
			{Path: "README.md", Contents: []byte("repository " + version), Mode: 0o644},
			{Path: "skills/alpha/SKILL.md", Contents: []byte("---\nname: alpha\ndescription: Alpha.\n---\n# " + version + "\n"), Mode: 0o644},
			{Path: "skills/beta/SKILL.md", Contents: []byte("---\nname: beta\ndescription: Beta.\n---\n# " + version + "\n"), Mode: 0o644},
		})
		require.NoError(t, err)
		sum, err := protocolartifact.ModuleSum(archive, modulePath, version)
		require.NoError(t, err)
		now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
		info, err := json.Marshal(protocolapi.ModuleInfo{SchemaVersion: 1, Kind: protocolapi.KindModule, ModulePath: modulePath, Version: version,
			Time: now, Sum: sum, ArchiveSize: int64(len(archive)),
			Skills: []protocolapi.ModuleSkill{
				{Name: "alpha", Path: "skills/alpha"},
				{Name: "beta", Path: "skills/beta"},
			}})
		require.NoError(t, err)
		releases[version] = release{archive: archive, info: info, sum: sum}
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		for version, item := range releases {
			switch request.URL.Path {
			case "/api/v1/" + modulePath + "/versions/" + version:
				_, _ = writer.Write(item.info)
				return
			case "/api/v1/" + modulePath + "/versions/" + version + ".zip":
				writer.Header().Set("Content-Length", fmt.Sprint(len(item.archive)))
				_, _ = writer.Write(item.archive)
				return
			}
		}
		http.NotFound(writer, request)
	}))
	defer server.Close()

	root := t.TempDir()
	home, workspace := filepath.Join(root, "home"), filepath.Join(root, "workspace")
	require.NoError(t, os.MkdirAll(home, 0o700))
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	t.Setenv("HOME", home)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"add", modulePath + "@" + oldVersion, "--project", workspace, "--skill", "alpha", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

	output.Reset()
	require.NoError(t, Execute([]string{"update", modulePath + "@" + newVersion, "--project", workspace, "--preflight", "--hub", server.URL, "--output", "json"}, &output, &output))
	var preflight moduleUpdateReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Equal(t, "module-update-preflight", preflight.Phase)
	require.Equal(t, oldVersion, preflight.FromVersion)
	require.Equal(t, newVersion, preflight.ToVersion)
	require.Equal(t, []string{"alpha"}, preflight.Skills)
	require.Equal(t, []string{"codex"}, preflight.Agents)

	oldModule := modulestore.CoordinatePath(filepath.Join(workspace, ".skillsgo", "modules"), modulePath, oldVersion)
	newModule := modulestore.CoordinatePath(filepath.Join(workspace, ".skillsgo", "modules"), modulePath, newVersion)
	oldProjection := modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, oldVersion)
	newProjection := modulestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), modulePath, newVersion)
	require.NoError(t, os.WriteFile(filepath.Join(oldProjection, "README.md"), []byte("local edit"), 0o644))
	output.Reset()
	updateErr := Execute([]string{"update", modulePath + "@" + newVersion, "--project", workspace, "--state-token", preflight.StateToken, "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, updateErr, "Local Modification")
	require.DirExists(t, oldModule)
	require.DirExists(t, oldProjection)
	require.NoDirExists(t, newModule)
	require.NoDirExists(t, newProjection)
	require.NoError(t, os.WriteFile(filepath.Join(oldProjection, "README.md"), []byte("repository "+oldVersion), 0o644))

	output.Reset()
	require.NoError(t, Execute([]string{"update", modulePath + "@" + newVersion, "--project", workspace, "--state-token", preflight.StateToken, "--hub", server.URL, "--output", "json"}, &output, &output))
	manifest, err := project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, newVersion, manifest.Dependencies[modulePath].Version)
	require.Equal(t, []string{"alpha"}, manifest.Dependencies[modulePath].Skills)
	lock, err := project.LoadDependencyLock(workspace)
	require.NoError(t, err)
	require.Equal(t, releases[newVersion].sum, lock.Dependencies[modulePath].Sum)
	require.NoDirExists(t, oldModule)
	require.NoDirExists(t, oldProjection)
	require.FileExists(t, filepath.Join(newModule, "skills", "beta", "SKILL.md"))
	require.FileExists(t, filepath.Join(newProjection, "skills", "alpha", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(newProjection, "skills", "beta", "SKILL.md"))
	contents, err := os.ReadFile(filepath.Join(newProjection, "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(contents), newVersion)
}
