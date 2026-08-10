/*
 * [INPUT]: Uses temporary supported-Agent registries, structured Session headers/sidecars, Workspace manifests, and read-only SQLite metadata containing recent projects plus a large complete-window metadata index.
 * [OUTPUT]: Specifies source-backed multi-Agent project discovery and that registry streaming retains a valid final Workspace.
 * [POS]: Serves as completeness and bounded-memory regression coverage for Agent-owned project evidence adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package agent

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestDiscoverRecentProjectsStreamsCompleteRegistry(t *testing.T) {
	home := t.TempDir()
	workspace := filepath.Join(home, "work", "last-entry")
	require.NoError(t, os.MkdirAll(workspace, 0o700))

	var registry strings.Builder
	registry.WriteByte('[')
	for index := 0; index < 20_000; index++ {
		if index > 0 {
			registry.WriteByte(',')
		}
		fmt.Fprintf(&registry, `{"workspaceDirectory":"/missing/%d","dateCreated":"1785628800000"}`, index)
	}
	fmt.Fprintf(&registry, `,{"workspaceDirectory":%q,"dateCreated":"1785628800000"}]`, workspace)
	path := filepath.Join(home, ".continue", "sessions", "sessions.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o700))
	require.NoError(t, os.WriteFile(path, []byte(registry.String()), 0o600))

	canonicalWorkspace, err := filepath.EvalSymlinks(workspace)
	require.NoError(t, err)
	require.Equal(t, []string{canonicalWorkspace}, DiscoverRecentProjects(home, time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC)))
}

func TestDiscoverRecentProjectsReadsStructuredPiCrushReasonixOpenClawCopilotAndHermesEvidence(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	workspaces := map[string]string{}
	for _, name := range []string{"pi", "crush", "reasonix", "openclaw", "copilot", "hermes"} {
		path := filepath.Join(home, "work", name)
		require.NoError(t, os.MkdirAll(path, 0o700))
		canonical, err := filepath.EvalSymlinks(path)
		require.NoError(t, err)
		workspaces[name] = canonical
	}

	piSession := filepath.Join(home, ".pi", "agent", "sessions", "--pi--", "session.jsonl")
	require.NoError(t, os.MkdirAll(filepath.Dir(piSession), 0o700))
	require.NoError(t, os.WriteFile(piSession, []byte(fmt.Sprintf(`{"kind":"header","version":4,"id":"pi","createdAt":1,"cwd":%q}`+"\n", workspaces["pi"])), 0o600))

	crushRegistry := crushProjectsRegistry(home)
	require.NoError(t, os.MkdirAll(filepath.Dir(crushRegistry), 0o700))
	crushBody, err := json.Marshal(map[string]any{"projects": []map[string]any{{"path": workspaces["crush"], "data_dir": filepath.Join(home, "crush-data"), "last_accessed": now}}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(crushRegistry, crushBody, 0o600))

	reasonixRoot := filepath.Join(home, ".reasonix", "sessions")
	require.NoError(t, os.MkdirAll(reasonixRoot, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(reasonixRoot, "task.jsonl"), []byte("{}\n"), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(reasonixRoot, "task.meta.json"), []byte(fmt.Sprintf(`{"workspace":%q}`, workspaces["reasonix"])), 0o600))

	openClawSession := filepath.Join(home, ".openclaw", "agents", "main", "sessions", "session.jsonl")
	require.NoError(t, os.MkdirAll(filepath.Dir(openClawSession), 0o700))
	require.NoError(t, os.WriteFile(openClawSession, []byte(fmt.Sprintf(`{"type":"session","id":"openclaw","cwd":%q}`+"\n", workspaces["openclaw"])), 0o600))

	copilotRoot := filepath.Join(home, ".copilot", "session-state", "session")
	require.NoError(t, os.MkdirAll(copilotRoot, 0o700))
	require.NoError(t, os.WriteFile(filepath.Join(copilotRoot, "workspace.yaml"), []byte("cwd: "+workspaces["copilot"]+"\n"), 0o600))

	hermesPath := filepath.Join(home, ".hermes", "state.db")
	require.NoError(t, os.MkdirAll(filepath.Dir(hermesPath), 0o700))
	database, err := sql.Open("sqlite", hermesPath)
	require.NoError(t, err)
	_, err = database.Exec(`CREATE TABLE sessions (cwd TEXT, started_at REAL, ended_at REAL, last_activity_at REAL)`)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO sessions(cwd, started_at, last_activity_at) VALUES (?, ?, ?)`, workspaces["hermes"], float64(now.Add(-time.Hour).Unix()), float64(now.Unix()))
	require.NoError(t, err)
	require.NoError(t, database.Close())

	for _, path := range []string{piSession, filepath.Join(reasonixRoot, "task.jsonl"), openClawSession, filepath.Join(copilotRoot, "workspace.yaml")} {
		require.NoError(t, os.Chtimes(path, now, now))
	}

	require.ElementsMatch(t, []string{
		workspaces["pi"], workspaces["crush"], workspaces["reasonix"],
		workspaces["openclaw"], workspaces["copilot"], workspaces["hermes"],
	}, DiscoverRecentProjects(home, now))
}

func TestProjectDiscoveryResolvesCrushAndHermesPlatformRoots(t *testing.T) {
	home := filepath.Join(string(filepath.Separator), "Users", "test")
	local := filepath.Join(string(filepath.Separator), "LocalData")
	xdg := filepath.Join(string(filepath.Separator), "xdg-data")
	require.Equal(t, filepath.Join(home, ".local", "share", "crush", "projects.json"), crushProjectsRegistryForOS(home, "darwin", "", "", ""))
	require.Equal(t, filepath.Join(xdg, "crush", "projects.json"), crushProjectsRegistryForOS(home, "linux", "", xdg, ""))
	require.Equal(t, filepath.Join(local, "crush", "projects.json"), crushProjectsRegistryForOS(home, "windows", local, "", ""))
	require.Equal(t, filepath.Join(home, ".hermes"), hermesProjectRootForOS(home, "darwin", "", ""))
	require.Equal(t, filepath.Join(local, "hermes"), hermesProjectRootForOS(home, "windows", local, ""))
	require.Equal(t, filepath.Join(home, ".hermes"), hermesProjectRootForOS(home, "linux", "", "~/.hermes"))
}
