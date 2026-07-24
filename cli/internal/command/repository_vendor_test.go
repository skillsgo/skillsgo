/*
 * [INPUT]: Uses command.Execute, an exact root Repository Proxy fixture, a complete Repository Artifact, and temporary Workspace/Agent roots.
 * [OUTPUT]: Specifies exact-path add and inventory, Repository-level update, selective multi-Agent projection, member/Agent removal, healthy zero-rewrite install, offline projection restoration, Local Modification preservation, User Vendor restoration, and checksum-failure atomicity.
 * [POS]: Serves as the CLI command-seam acceptance test for Repository Vendor installation.
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

	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/scopevendor"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestAddExactRepositoryVersionCreatesWorkspaceVendorAndSelectedProjection(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "README.md", Contents: []byte("shared"), Mode: 0o644},
		{Path: "SKILL.md", Contents: []byte("---\nname: root\ndescription: Root.\n---\n# Root\n"), Mode: 0o644},
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
		{Path: "skills/review/SKILL.md", Contents: []byte("---\nname: review\ndescription: Review.\n---\n# Review\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info := protocolapi.RepositoryInfo{
		SchemaVersion: 1, Kind: protocolapi.KindRepository, ID: repositoryID, Version: version,
		Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "repository-tree", Sum: sum, ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.SkillInfo{
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: ".", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-root", Name: "root", Description: "Root."},
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/design", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-design", Name: "design", Description: "Design."},
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/review", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-review", Name: "review", Description: "Review."},
		},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write(infoBytes)
		case "/" + repositoryID + "/@v/" + version + ".zip":
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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--project", workspace, "--skill-path", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

	manifest, err := project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"skills/design"}, manifest.Dependencies[repositoryID].Skills)
	require.Equal(t, []string{"codex"}, manifest.Dependencies[repositoryID].Agents)
	lock, err := project.LoadDependencyLock(workspace)
	require.NoError(t, err)
	require.Equal(t, sum, lock.Dependencies[repositoryID].Sum)
	vendor := scopevendor.CoordinatePath(filepath.Join(workspace, ".skillsgo", "vendor"), repositoryID, version)
	require.FileExists(t, filepath.Join(vendor, "skills", "review", "SKILL.md"))
	projection := scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, version)
	require.FileExists(t, filepath.Join(projection, "README.md"))
	require.FileExists(t, filepath.Join(projection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "skills", "review", "SKILL.md"))
	var response struct {
		SchemaVersion int    `json:"schemaVersion"`
		Phase         string `json:"phase"`
		Repository    string `json:"repository"`
		Vendor        string `json:"vendor"`
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
	require.Equal(t, "repository-install", response.Phase)
	require.Equal(t, repositoryID, response.Repository)
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
	expectedInfo, err := os.Stat(vendor)
	require.NoError(t, err)
	responseInfo, err := os.Stat(response.Vendor)
	require.NoError(t, err)
	require.True(t, os.SameFile(expectedInfo, responseInfo))
	output.Reset()
	require.NoError(t, Execute([]string{"inventory", "--project", workspace, "--output", "json"}, &output, &output))
	var inventory inventoryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &inventory))
	require.Len(t, inventory.Entries, 1)
	require.Equal(t, repositoryID, inventory.Entries[0].RepositoryID)
	require.Equal(t, []string{version}, inventory.Entries[0].Versions)
	require.Equal(t, filepath.Join(projection, "skills", "design"), inventory.Entries[0].Targets[0].Path)
	require.Equal(t, "healthy", string(inventory.Entries[0].Health))

	output.Reset()
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--skill", "root", "--agent", "goose", "--hub", server.URL, "--output", "json"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root", "skills/design"}, manifest.Dependencies[repositoryID].Skills)
	require.Equal(t, []string{"codex", "goose"}, manifest.Dependencies[repositoryID].Agents)
	for _, agentID := range []string{"codex", "goose"} {
		projectionRoot := scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, version)
		if agentID == "goose" {
			projectionRoot = scopevendor.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), repositoryID, version)
		}
		require.FileExists(t, filepath.Join(projectionRoot, "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "skills", "design", "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projectionRoot, "skills", "review", "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "README.md"))
	}

	output.Reset()
	require.NoError(t, Execute([]string{"remove", "skills/design", "--project", workspace, "--output", "json"}, &output, &output))
	var removal struct {
		SchemaVersion int      `json:"schemaVersion"`
		Phase         string   `json:"phase"`
		Skills        []string `json:"skills"`
		Scope         string   `json:"scope"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &removal))
	require.Equal(t, 1, removal.SchemaVersion)
	require.Equal(t, "repository-remove", removal.Phase)
	require.Equal(t, []string{"skills/design"}, removal.Skills)
	require.Equal(t, "project", removal.Scope)
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"root"}, manifest.Dependencies[repositoryID].Skills)
	for _, projectionRoot := range []string{
		scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, version),
		scopevendor.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), repositoryID, version),
	} {
		require.FileExists(t, filepath.Join(projectionRoot, "SKILL.md"))
		require.NoFileExists(t, filepath.Join(projectionRoot, "skills", "design", "SKILL.md"))
		require.FileExists(t, filepath.Join(projectionRoot, "README.md"))
	}
	require.FileExists(t, filepath.Join(vendor, "skills", "design", "SKILL.md"))

	output.Reset()
	require.NoError(t, Execute([]string{"remove", "root", "--agent", "goose"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"codex"}, manifest.Dependencies[repositoryID].Agents)
	require.FileExists(t, filepath.Join(scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, version), "SKILL.md"))
	require.NoDirExists(t, scopevendor.CoordinatePath(filepath.Join(workspace, ".goose", "skills"), repositoryID, version))
	require.FileExists(t, filepath.Join(vendor, "SKILL.md"))

	codexProjection := scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, version)
	rootManifest := filepath.Join(codexProjection, "SKILL.md")
	beforeHealthy, err := os.Stat(rootManifest)
	require.NoError(t, err)
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	afterHealthy, err := os.Stat(rootManifest)
	require.NoError(t, err)
	require.Equal(t, beforeHealthy.ModTime(), afterHealthy.ModTime())
	require.Contains(t, output.String(), `"status": "healthy"`)

	require.NoError(t, os.RemoveAll(vendor))
	require.NoError(t, os.RemoveAll(codexProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--hub", server.URL, "--output", "json"}, &output, &output))
	require.FileExists(t, filepath.Join(vendor, "skills", "review", "SKILL.md"))
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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--global", "--skill", "design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))
	userRoot := project.UserRoot(home)
	require.FileExists(t, filepath.Join(userRoot, project.WorkspaceManifestName))
	require.FileExists(t, filepath.Join(userRoot, project.DependencyLockName))
	userVendor := scopevendor.CoordinatePath(filepath.Join(userRoot, "vendor"), repositoryID, version)
	require.FileExists(t, filepath.Join(userVendor, "skills", "review", "SKILL.md"))
	userProjection := scopevendor.CoordinatePath(filepath.Join(home, ".codex", "skills"), repositoryID, version)
	require.NoError(t, os.RemoveAll(userProjection))
	output.Reset()
	require.NoError(t, Execute([]string{"install", "--global", "--hub", "http://127.0.0.1:1", "--output", "json"}, &output, &output))
	require.FileExists(t, filepath.Join(userProjection, "skills", "design", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(userProjection, "skills", "review", "SKILL.md"))
}

func TestAddRepositorySumMismatchLeavesNoWorkspaceState(t *testing.T) {
	repositoryID, version := "github.com/example/skills", "v1.2.3"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "skills/design/SKILL.md", Contents: []byte("---\nname: design\ndescription: Design.\n---\n# Design\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info := protocolapi.RepositoryInfo{
		SchemaVersion: 1, Kind: protocolapi.KindRepository, ID: repositoryID, Version: version,
		Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "repository-tree",
		Sum: "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.SkillInfo{
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/design", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-design", Name: "design", Description: "Design."},
		},
	}
	infoBytes, err := json.Marshal(info)
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write(infoBytes)
		case "/" + repositoryID + "/@v/" + version + ".zip":
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
	err = Execute([]string{"add", repositoryID + "@" + version, "--skill", "design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "Repository Sum mismatch")

	require.NoFileExists(t, filepath.Join(workspace, project.WorkspaceManifestName))
	require.NoFileExists(t, filepath.Join(workspace, project.DependencyLockName))
	require.NoDirExists(t, filepath.Join(workspace, ".skillsgo", "vendor", "github.com"))
	require.NoDirExists(t, filepath.Join(workspace, ".agents", "skills", "github.com"))
}

func TestUpdateRepositoryReplacesCoordinateAndPreservesSelections(t *testing.T) {
	repositoryID := "github.com/example/skills"
	oldVersion, newVersion := "v1.2.0", "v1.3.0"
	type release struct {
		archive []byte
		info    []byte
		sum     string
	}
	releases := map[string]release{}
	for _, version := range []string{oldVersion, newVersion} {
		archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
			{Path: "README.md", Contents: []byte("repository " + version), Mode: 0o644},
			{Path: "skills/alpha/SKILL.md", Contents: []byte("---\nname: alpha\ndescription: Alpha.\n---\n# " + version + "\n"), Mode: 0o644},
			{Path: "skills/beta/SKILL.md", Contents: []byte("---\nname: beta\ndescription: Beta.\n---\n# " + version + "\n"), Mode: 0o644},
		})
		require.NoError(t, err)
		sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
		require.NoError(t, err)
		now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
		info, err := json.Marshal(protocolapi.RepositoryInfo{SchemaVersion: 1, Kind: protocolapi.KindRepository, ID: repositoryID, Version: version,
			Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit-" + version, TreeSHA: "tree-" + version, Sum: sum, ArchiveSize: int64(len(archive)),
			Skills: []protocolapi.SkillInfo{
				{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/alpha", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit-" + version, TreeSHA: "alpha-" + version, Name: "alpha", Description: "Alpha."},
				{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/beta", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit-" + version, TreeSHA: "beta-" + version, Name: "beta", Description: "Beta."},
			}})
		require.NoError(t, err)
		releases[version] = release{archive: archive, info: info, sum: sum}
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		for version, item := range releases {
			switch request.URL.Path {
			case "/" + repositoryID + "/@v/" + version + ".info":
				_, _ = writer.Write(item.info)
				return
			case "/" + repositoryID + "/@v/" + version + ".zip":
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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + oldVersion, "--project", workspace, "--skill", "alpha", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

	output.Reset()
	require.NoError(t, Execute([]string{"update", repositoryID + "@" + newVersion, "--project", workspace, "--preflight", "--hub", server.URL, "--output", "json"}, &output, &output))
	var preflight repositoryUpdateReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &preflight))
	require.Equal(t, "repository-update-preflight", preflight.Phase)
	require.Equal(t, oldVersion, preflight.FromVersion)
	require.Equal(t, newVersion, preflight.ToVersion)
	require.Equal(t, []string{"alpha"}, preflight.Skills)
	require.Equal(t, []string{"codex"}, preflight.Agents)

	oldVendor := scopevendor.CoordinatePath(filepath.Join(workspace, ".skillsgo", "vendor"), repositoryID, oldVersion)
	newVendor := scopevendor.CoordinatePath(filepath.Join(workspace, ".skillsgo", "vendor"), repositoryID, newVersion)
	oldProjection := scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, oldVersion)
	newProjection := scopevendor.CoordinatePath(filepath.Join(workspace, ".agents", "skills"), repositoryID, newVersion)
	require.NoError(t, os.WriteFile(filepath.Join(oldProjection, "README.md"), []byte("local edit"), 0o644))
	output.Reset()
	updateErr := Execute([]string{"update", repositoryID + "@" + newVersion, "--project", workspace, "--state-token", preflight.StateToken, "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, updateErr, "Local Modification")
	require.DirExists(t, oldVendor)
	require.DirExists(t, oldProjection)
	require.NoDirExists(t, newVendor)
	require.NoDirExists(t, newProjection)
	require.NoError(t, os.WriteFile(filepath.Join(oldProjection, "README.md"), []byte("repository "+oldVersion), 0o644))

	output.Reset()
	require.NoError(t, Execute([]string{"update", repositoryID + "@" + newVersion, "--project", workspace, "--state-token", preflight.StateToken, "--hub", server.URL, "--output", "json"}, &output, &output))
	manifest, err := project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, newVersion, manifest.Dependencies[repositoryID].Version)
	require.Equal(t, []string{"alpha"}, manifest.Dependencies[repositoryID].Skills)
	lock, err := project.LoadDependencyLock(workspace)
	require.NoError(t, err)
	require.Equal(t, releases[newVersion].sum, lock.Dependencies[repositoryID].Sum)
	require.NoDirExists(t, oldVendor)
	require.NoDirExists(t, oldProjection)
	require.FileExists(t, filepath.Join(newVendor, "skills", "beta", "SKILL.md"))
	require.FileExists(t, filepath.Join(newProjection, "skills", "alpha", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(newProjection, "skills", "beta", "SKILL.md"))
	contents, err := os.ReadFile(filepath.Join(newProjection, "skills", "alpha", "SKILL.md"))
	require.NoError(t, err)
	require.Contains(t, string(contents), newVersion)
}
