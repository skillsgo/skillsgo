/*
 * [INPUT]: Uses command.Execute with isolated User/Agent roots, current skills.sh locks, and exact Repository Proxy fixtures.
 * [OUTPUT]: Specifies state-bound exact-path Repository adoption, byte-identity rejection, current lock parsing, provider identity, plan validation, and localized public behavior without Store or Receipt compatibility.
 * [POS]: Serves as the executable contract for the lock-backed Batch Takeover journey on Repository Vendor architecture.
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

func executeTakeover(t *testing.T, stdout, stderr *bytes.Buffer, hubURL string, scopeArgs ...string) error {
	t.Helper()
	preflightArgs := append([]string{"takeover", "--preflight"}, scopeArgs...)
	preflightArgs = append(preflightArgs, "--hub", hubURL, "--output", "json")
	if err := Execute(preflightArgs, stdout, stderr); err != nil {
		return err
	}
	var preview takeoverPreflightReport
	if err := json.Unmarshal(stdout.Bytes(), &preview); err != nil {
		return err
	}
	stdout.Reset()
	executionArgs := append([]string{"takeover", "--plan", preview.PlanID}, scopeArgs...)
	executionArgs = append(executionArgs, "--hub", hubURL, "--yes", "--output", "json")
	return Execute(executionArgs, stdout, stderr)
}

func takeoverRepositoryFixture(t *testing.T) (string, string, []byte, []byte, *httptest.Server) {
	t.Helper()
	repositoryID, version := "github.com/example/skills", "v1.2.3"
	skill := []byte("---\nname: alpha\ndescription: Existing Alpha.\n---\n# Alpha\n")
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "README.md", Contents: []byte("shared"), Mode: 0o644},
		{Path: "skills/alpha/SKILL.md", Contents: skill, Mode: 0o644},
		{Path: "skills/alpha/references/guide.md", Contents: []byte("guide"), Mode: 0o644},
		{Path: "skills/beta/SKILL.md", Contents: []byte("---\nname: beta\ndescription: Beta.\n---\n"), Mode: 0o644},
	})
	require.NoError(t, err)
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	now := time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)
	info, err := json.Marshal(protocolapi.RepositoryInfo{SchemaVersion: 1, Kind: protocolapi.KindRepository, ID: repositoryID, Version: version,
		Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "tree", Sum: sum, ArchiveSize: int64(len(archive)),
		Skills: []protocolapi.SkillInfo{
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/alpha", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "alpha", Name: "alpha", Description: "Existing Alpha."},
			{SchemaVersion: 1, Kind: protocolapi.KindSkill, RepositoryID: repositoryID, SkillPath: "skills/beta", Version: version, Time: now, Ref: "refs/tags/" + version, CommitSHA: "commit", TreeSHA: "beta", Name: "beta", Description: "Beta."},
		}})
	require.NoError(t, err)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write(info)
		case "/" + repositoryID + "/@v/" + version + ".zip":
			writer.Header().Set("Content-Length", fmt.Sprint(len(archive)))
			_, _ = writer.Write(archive)
		default:
			http.NotFound(writer, request)
		}
	}))
	return repositoryID, version, skill, []byte("guide"), server
}

func writeTakeoverUserFixture(t *testing.T, home, agentHome, repositoryID, version string, skill, guide []byte) string {
	t.Helper()
	target := filepath.Join(agentHome, "skills", "alpha")
	require.NoError(t, os.MkdirAll(filepath.Join(target, "references"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), skill, 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(target, "references", "guide.md"), guide, 0o644))
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".agents"), 0o700))
	lock, err := json.Marshal(map[string]any{"version": 3, "skills": map[string]any{"alpha": map[string]any{
		"source": "example/skills", "sourceType": "github", "sourceUrl": "https://github.com/example/skills.git",
		"ref": version, "skillPath": "skills/alpha/SKILL.md",
	}}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(home, ".agents", ".skill-lock.json"), lock, 0o600))
	return target
}

func TestBatchTakeoverAdoptsExactRepositoryMemberIntoUserVendor(t *testing.T) {
	repositoryID, version, skill, guide, server := takeoverRepositoryFixture(t)
	defer server.Close()
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := writeTakeoverUserFixture(t, home, agentHome, repositoryID, version, skill, guide)

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, server.URL, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Equal(t, 1, result.Summary.TakenOver)
	require.Zero(t, result.Summary.Skipped)
	require.NoDirExists(t, target)
	userRoot := project.UserRoot(home)
	manifest, err := project.LoadWorkspaceManifest(userRoot)
	require.NoError(t, err)
	require.Equal(t, version, manifest.Dependencies[repositoryID].Version)
	require.Equal(t, []string{"skills/alpha"}, manifest.Dependencies[repositoryID].Skills)
	require.Equal(t, []string{"test-agent"}, manifest.Dependencies[repositoryID].Agents)
	require.NoError(t, project.ValidateWorkspaceState(manifest, mustLoadTakeoverLock(t, userRoot)))
	vendor := scopevendor.CoordinatePath(filepath.Join(userRoot, "vendor"), repositoryID, version)
	projection := scopevendor.CoordinatePath(filepath.Join(agentHome, "skills"), repositoryID, version)
	require.FileExists(t, filepath.Join(vendor, "skills", "beta", "SKILL.md"))
	require.FileExists(t, filepath.Join(projection, "skills", "alpha", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(projection, "skills", "beta", "SKILL.md"))
	require.Equal(t, skill, mustReadTakeoverFile(t, filepath.Join(projection, "skills", "alpha", "SKILL.md")))
	require.NoDirExists(t, filepath.Join(userRoot, "store"))
	require.NoDirExists(t, filepath.Join(userRoot, "receipts"))
}

func TestBatchTakeoverRejectsDifferentBytesWithoutWritingState(t *testing.T) {
	repositoryID, version, skill, guide, server := takeoverRepositoryFixture(t)
	defer server.Close()
	root := t.TempDir()
	home, agentHome := filepath.Join(root, "home"), filepath.Join(root, "test-agent")
	t.Setenv("HOME", home)
	t.Setenv("SKILLSGO_TEST_AGENT_HOME", agentHome)
	target := writeTakeoverUserFixture(t, home, agentHome, repositoryID, version, skill, guide)
	require.NoError(t, os.WriteFile(filepath.Join(target, "SKILL.md"), append(skill, []byte("local edit\n")...), 0o644))

	var stdout, stderr bytes.Buffer
	require.NoError(t, executeTakeover(t, &stdout, &stderr, server.URL, "--user"))
	var result takeoverReport
	require.NoError(t, json.Unmarshal(stdout.Bytes(), &result))
	require.Zero(t, result.Summary.TakenOver)
	require.Equal(t, 1, result.Summary.Skipped)
	require.Equal(t, "content-mismatch", result.Results[0].Reason)
	require.DirExists(t, target)
	require.NoFileExists(t, filepath.Join(project.UserRoot(home), project.WorkspaceManifestName))
	require.NoDirExists(t, filepath.Join(project.UserRoot(home), "vendor"))
}

func mustLoadTakeoverLock(t *testing.T, root string) project.DependencyLock {
	t.Helper()
	lock, err := project.LoadDependencyLock(root)
	require.NoError(t, err)
	return lock
}

func mustReadTakeoverFile(t *testing.T, path string) []byte {
	t.Helper()
	contents, err := os.ReadFile(path)
	require.NoError(t, err)
	return contents
}

func TestReadSkillsShLockKeepsValidRecordsWhenOneRecordIsMalformed(t *testing.T) {
	lockPath := filepath.Join(t.TempDir(), ".skill-lock.json")
	require.NoError(t, os.WriteFile(lockPath, []byte(`{"version":3,"skills":{"valid":{"source":"example/skills","sourceType":"github"},"malformed":{"source":123,"sourceType":"github"}}}`), 0o600))
	records, supported, err := readSkillsShLock(lockPath, 3)
	require.NoError(t, err)
	require.True(t, supported)
	require.False(t, records["valid"].Invalid)
	require.True(t, records["malformed"].Invalid)
}

func TestLockRecordSkillIDUsesProviderSemantics(t *testing.T) {
	gitID, err := lockRecordSkillID(skillsShUserLockRecord{Source: "display-label", SourceType: "git", SourceURL: "https://git.example.com/team/repo.git"})
	require.NoError(t, err)
	require.Equal(t, "git.example.com/team/repo", gitID)
	_, err = lockRecordSkillID(skillsShUserLockRecord{Source: "acme/local", SourceType: "local", SourceURL: "/tmp/local"})
	require.Error(t, err)
}

func TestBatchTakeoverHelpAndValidationAreLocalized(t *testing.T) {
	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"--lang", "zh-CN", "takeover", "--help"}, &stdout, &stderr))
	require.Contains(t, stdout.String(), "登记受支持的现有 skills.sh 安装")
	err := Execute([]string{"--lang", "zh-CN", "takeover", "--output", "json"}, &stdout, &stderr)
	require.EqualError(t, err, "批量接管需要使用 --yes 明确确认")
}
