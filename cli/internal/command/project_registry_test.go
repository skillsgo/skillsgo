/*
 * [INPUT]: Uses command.Execute with a temporary platform-shaped user home, real Workspace directories, JSON metadata, and SQLite fixtures.
 * [OUTPUT]: Specifies stable machine add/list/remove journeys plus one-time Agent-session bootstrap from bounded ordinary and oversized structured records into CLI-owned user configuration.
 * [POS]: Serves as executable command-contract coverage for App and terminal project registration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"crypto/md5"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/config"
	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"
)

func TestProjectBootstrapPersistsRecentAgentWorkspaces(t *testing.T) {
	home := t.TempDir()
	claudeWorkspace := filepath.Join(home, "work", "claude-demo")
	codexWorkspace := filepath.Join(home, "work", "codex-demo")
	geminiWorkspace := filepath.Join(home, "work", "gemini-demo")
	kimiWorkspace := filepath.Join(home, "work", "kimi-demo")
	continueWorkspace := filepath.Join(home, "work", "continue-demo")
	vibeWorkspace := filepath.Join(home, "work", "vibe-demo")
	clineWorkspace := filepath.Join(home, "work", "cline-demo")
	rooWorkspace := filepath.Join(home, "work", "roo-demo")
	gooseWorkspace := filepath.Join(home, "work", "goose-demo")
	openCodeWorkspace := filepath.Join(home, "work", "opencode-demo")
	qwenWorkspace := filepath.Join(home, "work", "qwen-demo")
	kiloWorkspace := filepath.Join(home, "work", "kilo-demo")
	for _, workspace := range []string{claudeWorkspace, codexWorkspace, geminiWorkspace, kimiWorkspace, continueWorkspace, vibeWorkspace, clineWorkspace, rooWorkspace, gooseWorkspace, openCodeWorkspace, qwenWorkspace, kiloWorkspace} {
		require.NoError(t, os.MkdirAll(workspace, 0o700))
	}
	claudeSession := filepath.Join(home, ".claude", "projects", "demo", "session.jsonl")
	codexSession := filepath.Join(home, ".codex", "sessions", "2026", "08", "02", "rollout.jsonl")
	require.NoError(t, os.MkdirAll(filepath.Dir(claudeSession), 0o700))
	require.NoError(t, os.MkdirAll(filepath.Dir(codexSession), 0o700))
	require.NoError(t, os.WriteFile(claudeSession, []byte(`{"message":{"cwd":"/wrong-nested-path"}}`+"\n"+`{"cwd":`+quotedJSON(claudeWorkspace)+`}`+"\n"), 0o600))
	oversizedMetadata := `{"type":"session_meta","payload":{"cwd":` + quotedJSON(codexWorkspace) + `,"environment":"` + strings.Repeat("x", 46*1024) + `"}}`
	require.NoError(t, os.WriteFile(codexSession, []byte(oversizedMetadata+"\n"+`{"type":"message","cwd":"/wrong-event-path"}`+"\n"), 0o600))
	writeProjectFixture(t, filepath.Join(home, ".gemini", "projects.json"), `{"projects":{`+quotedJSON(geminiWorkspace)+`:"gemini-demo"}}`)
	writeProjectFixture(t, filepath.Join(home, ".gemini", "tmp", "gemini-demo", "chats", "session.json"), `{}`)
	kimiSessionID := "session-1"
	writeProjectFixture(t, filepath.Join(home, ".kimi", "kimi.json"), `{"work_dirs":[{"path":`+quotedJSON(kimiWorkspace)+`,"kaos":"local","last_session_id":"`+kimiSessionID+`"}]}`)
	kimiHash := fmt.Sprintf("%x", md5.Sum([]byte(kimiWorkspace)))
	writeProjectFixture(t, filepath.Join(home, ".kimi", "sessions", kimiHash, kimiSessionID, "context.jsonl"), `{}`)
	writeProjectFixture(t, filepath.Join(home, ".continue", "sessions", "sessions.json"), `[{"sessionId":"1","dateCreated":"1785628800000","workspaceDirectory":`+quotedJSON(continueWorkspace)+`}]`)
	writeProjectFixture(t, filepath.Join(home, ".vibe", "logs", "session", "session_1", "meta.json"), `{"environment":{"working_directory":`+quotedJSON(vibeWorkspace)+`}}`)
	writeProjectFixture(t, filepath.Join(home, ".cline", "data", "state", "taskHistory.json"), `[{"id":"1","ts":1785628800000,"cwdOnTaskInitialization":`+quotedJSON(clineWorkspace)+`}]`)
	writeProjectFixture(t, rooIndexPath(home), `{"version":1,"updatedAt":1785628800000,"entries":[{"id":"1","ts":1785628800000,"workspace":`+quotedJSON(rooWorkspace)+`}]}`)
	gooseRoot := filepath.Join(home, "goose-root")
	writeGooseFixture(t, filepath.Join(gooseRoot, "data", "sessions", "sessions.db"), gooseWorkspace)
	t.Setenv("GOOSE_PATH_ROOT", gooseRoot)
	openCodeData := filepath.Join(home, "xdg-data")
	openCodeOverride := filepath.Join(openCodeData, "opencode", "custom.db")
	writeOpenCodeFixture(t, openCodeOverride, openCodeWorkspace)
	t.Setenv("OPENCODE_DB", openCodeOverride)
	writeOpenCodeFixture(t, filepath.Join(openCodeData, "kilo", "opencode-dev.db"), kiloWorkspace)
	t.Setenv("XDG_DATA_HOME", openCodeData)
	writeProjectFixture(t, filepath.Join(home, ".qwen", "projects", "project-id", "chats", "session.runtime.json"), `{"schema_version":1,"pid":1,"session_id":"session","work_dir":`+quotedJSON(qwenWorkspace)+`,"hostname":"localhost","started_at":1785628800,"qwen_version":"1"}`)
	t.Setenv("HOME", home)

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "bootstrap", "--output", "json"}, &output, &output), output.String())
	var report projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Equal(t, "project-bootstrap", report.Phase)
	require.Len(t, report.Projects, 12)
	canonicalClaude, err := filepath.EvalSymlinks(claudeWorkspace)
	require.NoError(t, err)
	canonicalCodex, err := filepath.EvalSymlinks(codexWorkspace)
	require.NoError(t, err)
	expectedRoots := []string{canonicalClaude, canonicalCodex}
	for _, workspace := range []string{geminiWorkspace, kimiWorkspace, continueWorkspace, vibeWorkspace, clineWorkspace, rooWorkspace, gooseWorkspace, openCodeWorkspace, qwenWorkspace, kiloWorkspace} {
		canonical, err := filepath.EvalSymlinks(workspace)
		require.NoError(t, err)
		expectedRoots = append(expectedRoots, canonical)
	}
	require.ElementsMatch(t, expectedRoots, projectRoots(report.Projects))
	require.FileExists(t, filepath.Join(home, ".skillsgo", "config.yaml"))
}

func rooIndexPath(home string) string {
	configRoot := filepath.Join(home, ".config")
	if runtime.GOOS == "darwin" {
		configRoot = filepath.Join(home, "Library", "Application Support")
	}
	return filepath.Join(configRoot, "Code", "User", "globalStorage", "rooveterinaryinc.roo-cline", "tasks", "_index.json")
}

func writeOpenCodeFixture(t *testing.T, path, workspace string) {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, database.Close()) })
	_, err = database.Exec(`CREATE TABLE session (id TEXT PRIMARY KEY, directory TEXT NOT NULL, time_updated INTEGER NOT NULL)`)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO session (id, directory, time_updated) VALUES ('1', ?, 1785628800000)`, workspace)
	require.NoError(t, err)
}

func writeGooseFixture(t *testing.T, path, workspace string) {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, database.Close()) })
	_, err = database.Exec(`CREATE TABLE sessions (id TEXT PRIMARY KEY, working_dir TEXT NOT NULL, updated_at TIMESTAMP NOT NULL)`)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO sessions (id, working_dir, updated_at) VALUES ('1', ?, '2026-08-02 00:00:00')`, workspace)
	require.NoError(t, err)
}

func TestProjectBootstrapDiscoversWorkBuddyWorkspace(t *testing.T) {
	home := t.TempDir()
	workspace := filepath.Join(home, "work", "workbuddy-demo")
	require.NoError(t, os.MkdirAll(workspace, 0o700))
	writeWorkBuddyFixture(t, filepath.Join(home, ".workbuddy", "workbuddy.db"), workspace)
	t.Setenv("HOME", home)

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "bootstrap", "--output", "json"}, &output, &output), output.String())
	var report projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	canonical, err := filepath.EvalSymlinks(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{canonical}, projectRoots(report.Projects))
}

func writeWorkBuddyFixture(t *testing.T, path, workspace string) {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, database.Close()) })
	_, err = database.Exec(`CREATE TABLE workspaces (path TEXT PRIMARY KEY, last_opened_at INTEGER NOT NULL)`)
	require.NoError(t, err)
	_, err = database.Exec(`CREATE TABLE sessions (id TEXT PRIMARY KEY, cwd TEXT NOT NULL, deleted_at INTEGER, is_playground INTEGER)`)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO workspaces (path, last_opened_at) VALUES (?, 1785628800000)`, workspace)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO sessions (id, cwd, deleted_at, is_playground) VALUES ('1', ?, NULL, 0)`, workspace)
	require.NoError(t, err)
}

func writeProjectFixture(t *testing.T, path, content string) {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
}

func projectRoots(projects []config.Project) []string {
	roots := make([]string, 0, len(projects))
	for _, project := range projects {
		roots = append(roots, project.Root)
	}
	return roots
}

func TestProjectBootstrapDoesNotExpandExistingRegistry(t *testing.T) {
	home := t.TempDir()
	existing := filepath.Join(home, "work", "existing")
	discovered := filepath.Join(home, "work", "discovered")
	require.NoError(t, os.MkdirAll(existing, 0o700))
	require.NoError(t, os.MkdirAll(discovered, 0o700))
	session := filepath.Join(home, ".claude", "projects", "demo", "session.jsonl")
	require.NoError(t, os.MkdirAll(filepath.Dir(session), 0o700))
	require.NoError(t, os.WriteFile(session, []byte(`{"cwd":`+quotedJSON(discovered)+`}`+"\n"), 0o600))
	t.Setenv("HOME", home)
	canonicalExisting, err := filepath.EvalSymlinks(existing)
	require.NoError(t, err)
	configPath := filepath.Join(home, ".skillsgo", "config.yaml")
	require.NoError(t, os.MkdirAll(filepath.Dir(configPath), 0o700))
	require.NoError(t, os.WriteFile(configPath, []byte("schemaVersion: 1\nprojects:\n  - "+canonicalExisting+"\n"), 0o600))

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "add", existing, "--output", "json"}, &output, &output))
	output.Reset()
	require.NoError(t, Execute([]string{"project", "bootstrap", "--output", "json"}, &output, &output))
	var report projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Equal(t, []config.Project{{Name: "existing", Root: canonicalExisting}}, report.Projects)

	output.Reset()
	require.NoError(t, Execute([]string{"project", "remove", canonicalExisting, "--output", "json"}, &output, &output))
	output.Reset()
	require.NoError(t, Execute([]string{"project", "bootstrap", "--output", "json"}, &output, &output))
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Empty(t, report.Projects)
}

func quotedJSON(value string) string {
	encoded, _ := json.Marshal(value)
	return string(encoded)
}

func TestProjectRegistryCommands(t *testing.T) {
	home, workspace := t.TempDir(), t.TempDir()
	t.Setenv("HOME", home)
	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "add", workspace, "--output", "json"}, &output, &output))
	var added projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &added))
	require.Len(t, added.Projects, 1)
	canonicalWorkspace, err := filepath.EvalSymlinks(workspace)
	require.NoError(t, err)
	require.Equal(t, canonicalWorkspace, added.Projects[0].Root)
	output.Reset()
	require.NoError(t, Execute([]string{"project", "list", "--output", "json"}, &output, &output))
	var listed projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &listed))
	require.Equal(t, added.Projects, listed.Projects)
	output.Reset()
	require.NoError(t, Execute([]string{"project", "remove", added.Projects[0].Root, "--output", "json"}, &output, &output))
	require.DirExists(t, workspace)
	output.Reset()
	require.ErrorContains(t, Execute([]string{"project", "move", workspace, t.TempDir()}, &output, &output), `unknown command "move"`)
}
