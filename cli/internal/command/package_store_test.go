/*
 * [INPUT]: Uses command.Execute, exact Repository version metadata/ZIP fixtures, a complete Repository Artifact, and temporary Workspace/Agent roots.
 * [OUTPUT]: Specifies exact-path add and inventory, Repository-level update, explicitly confirmed selective multi-Agent member/Agent removal, healthy zero-rewrite install, offline projection restoration, Local Modification preservation, Global Package Store restoration, and checksum-failure atomicity.
 * [POS]: Serves as the CLI command-seam acceptance test for Repository Package Store installation.
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

	"github.com/skillsgo/skillsgo/cli/internal/packagestore"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestAddExactRepositoryVersionCreatesWorkspacePackageStoreAndSelectedProjection(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "README.md", Contents: []byte("shared"), Mode: 0o644},
		{Path: "SKILL.md", Contents: []byte("---\nname: root\ndescription: Root.\n---\n# Root\n"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("---\nname: review\ndescription: Review.\n---\n# Review\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.PackageSum(archive, packagePath, version)
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info := protocolapi.PackageInfo{
		SchemaVersion: 1, Kind: protocolapi.KindPackage, PackagePath: packagePath, Version: version,
		Time: now, Sum: sum, ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.PackageSkill{
			{Name: "root", Path: "."},
			{Name: "design", Path: "skills/design"},
			{Name: "review", Path: "skills/review"},
		},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + packagePath + "/versions/" + version:
			_, _ = writer.Write(infoBytes)
		case "/api/v1/" + packagePath + "/versions/" + version + ".zip":
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
	require.NoError(t, Execute([]string{"add", packagePath + "@" + version, "--project", workspace, "--skill-path", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

	manifest, err := project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"skills/design"}, manifest.Dependencies[packagePath].Skills)
	require.Equal(t, []string{"codex"}, manifest.Dependencies[packagePath].Agents)
	lock, err := project.LoadDependencyLock(workspace)
	require.NoError(t, err)
	require.Equal(t, sum, lock.Dependencies[packagePath].Sum)
	packageDir := packagestore.CoordinatePath(filepath.Join(workspace, ".skillsgo", "packages"), packagePath, version)
	require.FileExists(t, filepath.Join(packageDir, "skills", "review", "SKILL.md"))
	projection := packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, version)
	require.FileExists(t, filepath.Join(projection, "README.md"))
	require.FileExists(t, filepath.Join(projection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "skills", "review", "SKILL.md"))
	var response struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		PackagePath   string `json:"packagePath"`
		PackageDir    string `json:"packageDir"`
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
	require.Equal(t, "package-install", response.Phase)
	require.Equal(t, packagePath, response.PackagePath)
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
	expectedInfo, err := os.Stat(packageDir)
	require.NoError(t, err)
	responseInfo, err := os.Stat(response.PackageDir)
	require.NoError(t, err)
	require.True(t, os.SameFile(expectedInfo, responseInfo))
	output.Reset()
	require.NoError(t, Execute([]string{"list", "--project", workspace, "--output", "json"}, &output, &output))
	var inventory listReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &inventory))
	require.Len(t, inventory.Entries, 1)
	require.Equal(t, packagePath, inventory.Entries[0].PackagePath)
	require.Equal(t, []string{version}, inventory.Entries[0].Versions)
	require.Equal(t, filepath.Join(projection, "skills", "design"), inventory.Entries[0].Targets[0].Path)
	require.Equal(t, "healthy", string(inventory.Entries[0].Health))

	output.Reset()
	require.NoError(t, Execute([]string{"add", packagePath + "@" + version, "--skill", "root", "--agent", "goose", "--hub", server.URL, "--output", "json"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root", "skills/design"}, manifest.Dependencies[packagePath].Skills)
	require.Equal(t, []string{"codex", "goose"}, manifest.Dependencies[packagePath].Agents)
	for _, agentID := range []string{"codex", "goose"} {
		projectionRoot := packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, version)
		if agentID == "goose" {
			projectionRoot = packagestore.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), packagePath, version)
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
	require.Equal(t, []string{"root", "skills/design"}, manifest.Dependencies[packagePath].Skills)

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
	require.Equal(t, "package-remove", removal.Phase)
	require.Equal(t, []string{"skills/design"}, removal.Skills)
	require.Equal(t, "project", removal.Scope)
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root"}, manifest.Dependencies[packagePath].Skills)
	for _, projectionRoot := range []string{
		packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, version),
		packagestore.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), packagePath, version),
	} {
		require.FileExists(t, filepath.Join(projectionRoot, "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projectionRoot, "skills", "design", "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "README.md"))
	}
	require.FileExists(t, filepath.Join(packageDir, "skills", "design", "SKILL.md"))

	output.Reset()
	require.NoError(t, Execute([]string{"remove", "root", "--agent", "goose", "--yes"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"codex"}, manifest.Dependencies[packagePath].Agents)
	require.FileExists(t, filepath.Join(packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, version), "SKILL.md"))
	require.NoDirExists(t, packagestore.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), packagePath, version))
	require.FileExists(t, filepath.Join(packageDir, "SKILL.md"))

	codexProjection := packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, version)
	rootManifest := filepath.Join(codexProjection, "SKILL.md")
	beforeHealthy, err := os.Stat(rootManifest)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	afterHealthy, err := os.Stat(rootManifest)
	require.NoError(t, err)
	require.Equal(t, beforeHealthy.ModTime(), afterHealthy.ModTime())
	require.Contains(t, output.String(), `"status": "healthy"`)

	require.NoError(t, os.RemoveAll(packageDir))
	require.NoError(t, os.RemoveAll(codexProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", server.URL, "--output", "json"}, &output, &output))
	require.FileExists(t, filepath.Join(packageDir, "skills", "review", "SKILL.md"))
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
	require.NoError(t, Execute([]string{"add", packagePath + "@" + version, "--global", "--skill", "design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))
	userRoot := project.GlobalDeclarationRoot(home)
	require.FileExists(t, filepath.Join(userRoot, project.WorkspaceManifestName))
	require.FileExists(t, filepath.Join(userRoot, project.DependencyLockName))
	userPackage := packagestore.CoordinatePath(filepath.Join(project.GlobalStateRoot(home), "packages"), packagePath, version)
	require.FileExists(t, filepath.Join(userPackage, "skills", "review", "SKILL.md"))
	userProjection := packagestore.CoordinatePath(filepath.Join(home, ".codex", "skills"), packagePath, version)
	require.NoError(t, os.RemoveAll(userProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--global", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	require.FileExists(t, filepath.Join(userProjection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(userProjection, "skills", "review", "SKILL.md"))
}

func TestAddPackageSumMismatchLeavesNoWorkspaceState(t *testing.T) {
	packagePath, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info := protocolapi.PackageInfo{
		SchemaVersion: 1, Kind: protocolapi.KindPackage, PackagePath: packagePath, Version: version,
		Time: now,
		Sum:  "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.PackageSkill{
			{Name: "design", Path: "skills/design"},
		},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/api/v1/" + packagePath + "/versions/" + version:
			_, _ = writer.Write(infoBytes)
		case "/api/v1/" + packagePath + "/versions/" + version + ".zip":
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
	err = Execute([]string{"add", packagePath + "@" + version, "--skill", "design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "Repository Sum mismatch")

	require.NoFileExists(t, filepath.Join(workspace, project.WorkspaceManifestName))
	require.NoFileExists(t, filepath.Join(workspace, project.DependencyLockName))
	require.NoDirExists(t, filepath.Join(workspace, ".skillsgo", "packages", "github.com"))
	require.NoDirExists(t, filepath.Join(workspace, ".agents", "skills", "github.com"))
}

func TestUpdateRepositoryReplacesCoordinateAndPreservesSelections(t *testing.T) {
	packagePath := "github.com/example/skills"
	oldVersion, newVersion := "v1.2.0", "v1.3.0"
	type release struct {
		archive []byte
		info    []byte
		sum     string
	}
	releases := map[string]release{}
	for _, version := range []string{oldVersion, newVersion} {
		archive, err := protocolartifact.BuildPackage(packagePath, version, []protocolartifact.Entry{
			{Path: "README.md", Contents: []byte("repository " + version), Mode: 0o644},
			{Path: "skills/alpha/SKILL.md", Contents: []byte("---\nname: alpha\ndescription: Alpha.\n---\n# " + version + "\n"), Mode: 0o644},
			{Path: "skills/beta/SKILL.md", Contents: []byte("---\nname: beta\ndescription: Beta.\n---\n# " + version + "\n"), Mode: 0o644},
		})
		require.NoError(t, err)
		sum, err := protocolartifact.PackageSum(archive, packagePath, version)
		require.NoError(t, err)
		now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
		info, err := json.Marshal(protocolapi.PackageInfo{SchemaVersion: 1, Kind: protocolapi.KindPackage, PackagePath: packagePath, Version: version,
			Time: now, Sum: sum, ArchiveSize: int64(len(archive)),
			Skills: []protocolapi.PackageSkill{
				{Name: "alpha", Path: "skills/alpha"},
				{Name: "beta", Path: "skills/beta"},
			}})
		require.NoError(t, err)
		releases[version] = release{archive: archive, info: info, sum: sum}
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		for version, item := range releases {
			switch request.URL.Path {
			case "/api/v1/" + packagePath + "/versions/" + version:
				_, _ = writer.Write(item.info)
				return
			case "/api/v1/" + packagePath + "/versions/" + version + ".zip":
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
	require.NoError(t, Execute([]string{"add", packagePath + "@" + oldVersion, "--project", workspace, "--skill", "alpha", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

	oldPackage := packagestore.CoordinatePath(filepath.Join(workspace, ".skillsgo", "packages"), packagePath, oldVersion)
	newPackage := packagestore.CoordinatePath(filepath.Join(workspace, ".skillsgo", "packages"), packagePath, newVersion)
	oldProjection := packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, oldVersion)
	newProjection := packagestore.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), packagePath, newVersion)
	require.NoError(t, os.WriteFile(filepath.Join(oldProjection, "README.md"), []byte("local edit"), 0o644))
	output.Reset()
	updateErr := Execute([]string{"update", packagePath + "@" + newVersion, "--project", workspace, "--yes", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, updateErr, "Local Modification")
	require.DirExists(t, oldPackage)
	require.DirExists(t, oldProjection)
	require.NoDirExists(t, newPackage)
	require.NoDirExists(t, newProjection)
	require.NoError(t, os.WriteFile(filepath.Join(oldProjection, "README.md"), []byte("repository "+oldVersion), 0o644))

	output.Reset()
	require.NoError(t, Execute([]string{"update", packagePath + "@" + newVersion, "--project", workspace, "--yes", "--hub", server.URL, "--output", "json"}, &output, &output))
	var report moduleUpdateReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Equal(t, "package-update", report.Phase)
	require.Equal(t, oldVersion, report.FromVersion)
	require.Equal(t, newVersion, report.ToVersion)
	require.Equal(t, []string{"alpha"}, report.Skills)
	require.Equal(t, []string{"codex"}, report.Agents)
	manifest, err := project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, newVersion, manifest.Dependencies[packagePath].Version)
	require.Equal(t, []string{"alpha"}, manifest.Dependencies[packagePath].Skills)
	lock, err := project.LoadDependencyLock(workspace)
	require.NoError(t, err)
	require.Equal(t, releases[newVersion].sum, lock.Dependencies[packagePath].Sum)
	require.NoDirExists(t, oldPackage)
	require.NoDirExists(t, oldProjection)
	require.FileExists(t, filepath.Join(newPackage, "skills", "beta", "SKILL.md"))
	require.FileExists(t, filepath.Join(newProjection, "skills", "alpha", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(newProjection, "skills", "beta", "SKILL.md"))
	contents, err := os.ReadFile(filepath.Join(newProjection, "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(contents), newVersion)
}

func TestRepositoryUpdatePublicArguments(t *testing.T) {
	var output bytes.Buffer

	err := Execute([]string{"upgrade", "owner/repository", "--yes"}, &output, &output)
	require.ErrorContains(t, err, "unknown command \"upgrade\"")
	output.Reset()

	err = Execute([]string{"update", "owner/repository", "--preflight"}, &output, &output)
	require.ErrorContains(t, err, "unknown flag: --preflight")
	output.Reset()

	err = Execute([]string{"update", "owner/repository", "--state-token", "state"}, &output, &output)
	require.ErrorContains(t, err, "unknown flag: --state-token")
	output.Reset()

	err = Execute([]string{"update", "owner/repository", "--all", "--yes"}, &output, &output)
	require.ErrorContains(t, err, "specify one Package or --all")
	output.Reset()

	err = Execute([]string{"update", "owner/repository", "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "--output json requires --yes")
}
