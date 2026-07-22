/*
 * [INPUT]: Uses command.Execute, an exact root Repository Proxy fixture, a complete Repository Artifact, and temporary Workspace/Agent roots.
 * [OUTPUT]: Specifies the public exact-version add journey and checksum-failure atomicity through skillsgo.yaml, skillsgo.lock, Workspace Vendor, and selected ordinary-file Agent Projections.
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
	require.NoError(t, Execute([]string{"add", repositoryID + "@" + version, "--skill", "skills/design", "--agent", "codex", "--hub", server.URL, "--output", "json"}, &output, &output))

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
		Vendor string `json:"vendor"`
	}
	require.NoError(t, json.Unmarshal(output.Bytes(), &response))
	expectedInfo, err := os.Stat(vendor)
	require.NoError(t, err)
	responseInfo, err := os.Stat(response.Vendor)
	require.NoError(t, err)
	require.True(t, os.SameFile(expectedInfo, responseInfo))
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
