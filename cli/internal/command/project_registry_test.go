/*
 * [INPUT]: Uses command.Execute with a temporary user home and real Workspace directories.
 * [OUTPUT]: Specifies stable machine add/list/remove journeys plus one-time Agent-session bootstrap over the projects section of CLI-owned user configuration.
 * [POS]: Serves as executable command-contract coverage for App and terminal project registration.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/config"
	"github.com/stretchr/testify/require"
)

func TestProjectBootstrapPersistsRecentAgentWorkspaces(t *testing.T) {
	home := t.TempDir()
	claudeWorkspace := filepath.Join(home, "work", "claude-demo")
	codexWorkspace := filepath.Join(home, "work", "codex-demo")
	require.NoError(t, os.MkdirAll(claudeWorkspace, 0o700))
	require.NoError(t, os.MkdirAll(codexWorkspace, 0o700))
	claudeSession := filepath.Join(home, ".claude", "projects", "demo", "session.jsonl")
	codexSession := filepath.Join(home, ".codex", "sessions", "2026", "08", "02", "rollout.jsonl")
	require.NoError(t, os.MkdirAll(filepath.Dir(claudeSession), 0o700))
	require.NoError(t, os.MkdirAll(filepath.Dir(codexSession), 0o700))
	require.NoError(t, os.WriteFile(claudeSession, []byte(`{"cwd":`+quotedJSON(claudeWorkspace)+`}`+"\n"), 0o600))
	require.NoError(t, os.WriteFile(codexSession, []byte(`{"type":"session_meta","payload":{"cwd":`+quotedJSON(codexWorkspace)+`}}`+"\n"), 0o600))
	t.Setenv("HOME", home)

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "bootstrap", "--output", "json"}, &output, &output), output.String())
	var report projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	require.Equal(t, "project-bootstrap", report.Phase)
	canonicalClaude, err := filepath.EvalSymlinks(claudeWorkspace)
	require.NoError(t, err)
	canonicalCodex, err := filepath.EvalSymlinks(codexWorkspace)
	require.NoError(t, err)
	require.ElementsMatch(t, []string{canonicalClaude, canonicalCodex}, []string{report.Projects[0].Root, report.Projects[1].Root})
	require.FileExists(t, filepath.Join(home, ".skillsgo", "config.yaml"))
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

	var output bytes.Buffer
	require.NoError(t, Execute([]string{"project", "add", existing, "--output", "json"}, &output, &output))
	output.Reset()
	require.NoError(t, Execute([]string{"project", "bootstrap", "--output", "json"}, &output, &output))
	var report projectRegistryReport
	require.NoError(t, json.Unmarshal(output.Bytes(), &report))
	canonicalExisting, err := filepath.EvalSymlinks(existing)
	require.NoError(t, err)
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
