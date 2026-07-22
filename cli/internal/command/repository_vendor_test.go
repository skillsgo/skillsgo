/*
 * [INPUT]: Uses command.Execute, an exact root Repository Proxy fixture, a complete Repository Artifact, and temporary Workspace/Agent roots.
 * [OUTPUT]: Specifies exact add, selective multi-Agent projection, member/Agent removal, healthy zero-rewrite install, offline projection restoration, Local Modification preservation, User Vendor restoration, and checksum-failure atomicity.
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
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, ID: repositoryID, RepositoryID: repositoryID, Path: ".", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-root", Name: "root", Description: "Root."},
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, ID: repositoryID + "/-/skills/design", RepositoryID: repositoryID, Path: "skills/design", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-design", Name: "design", Description: "Design."},
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, ID: repositoryID + "/-/skills/review", RepositoryID: repositoryID, Path: "skills/review", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-review", Name: "review", Description: "Review."},
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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--project", workspace, "--skill", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--skill", ".", "--agent", "goose", "--hub", server.URL, "--output", "json"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{".", "skills/design"}, manifest.Dependencies[repositoryID].Skills)
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
	require.NoError(t, Execute([]string{"remove", "skills/design"}, &output, &output))
	manifest, err = project.LoadWorkspaceManifest(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{"."}, manifest.Dependencies[repositoryID].Skills)
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
	require.NoError(t, Execute([]string{"remove", ".", "--agent", "goose"}, &output, &output))
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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--global", "--skill", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))
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
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, ID: repositoryID + "/-/skills/design", RepositoryID: repositoryID, Path: "skills/design", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree-design", Name: "design", Description: "Design."},
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
	err = Execute([]string{"add", repositoryID + "@" + version, "--skill", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output)
	require.ErrorContains(t, err, "Repository Sum mismatch")

	require.NoFileExists(t, filepath.Join(workspace, project.WorkspaceManifestName))
	require.NoFileExists(t, filepath.Join(workspace, project.DependencyLockName))
	require.NoDirExists(t, filepath.Join(workspace, ".skillsgo", "vendor", "github.com"))
	require.NoDirExists(t, filepath.Join(workspace, ".agents", "skills", "github.com"))
}
