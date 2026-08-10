/*
 * [INPUT]: Uses isolated Crush project registries and Session SQLite fixtures containing correlated successful and failed View tool results with structured Skill metadata plus second/millisecond timestamps.
 * [OUTPUT]: Specifies schema-guarded Crush Skill invocation attribution, configured registry resolution, timestamp compatibility, Session deduplication, and rolling windows.
 * [POS]: Serves as the executable contract for the Crush usage-evidence adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"
)

func TestCollectCrushCountsOnlyCorrelatedSuccessfulSkillViewsPerSession(t *testing.T) {
	home := t.TempDir()
	globalData := t.TempDir()
	t.Setenv("CRUSH_GLOBAL_DATA", globalData)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	dataDir := filepath.Join(t.TempDir(), ".crush")
	writeCrushProjects(t, globalData, dataDir)
	database := createCrushUsageDatabase(t, filepath.Join(dataDir, "crush.db"))
	defer database.Close()

	insertCrushMessage(t, database, "session-one", "assistant", now.Add(-time.Hour), []any{
		crushToolCall("ok", "view", map[string]any{"file_path": "/skills/readme-i18n/SKILL.md"}),
		crushToolCall("bad", "view", map[string]any{"file_path": "/skills/review/SKILL.md"}),
		crushToolCall("ordinary", "view", map[string]any{"file_path": "/repo/SKILL.md"}),
	})
	insertCrushMessage(t, database, "session-one", "tool", now.Add(-time.Hour), []any{
		crushToolResult("ok", "view", false, map[string]any{"resource_type": "skill", "resource_name": "readme-i18n"}),
		crushToolResult("bad", "view", true, map[string]any{"resource_type": "skill", "resource_name": "review"}),
		crushToolResult("ordinary", "view", false, map[string]any{"file_path": "/repo/SKILL.md"}),
	})
	insertCrushMessage(t, database, "session-one", "assistant", now, []any{
		crushToolCall("again", "view", map[string]any{"file_path": "/skills/readme-i18n/SKILL.md"}),
	})
	insertCrushMessage(t, database, "session-one", "tool", now, []any{
		crushToolResult("again", "view", false, map[string]any{"resource_type": "skill", "resource_name": "readme-i18n"}),
		crushToolResult("unmatched", "view", false, map[string]any{"resource_type": "skill", "resource_name": "ignored"}),
	})

	usage, err := CollectCrush(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "ignored")
}

func TestCollectCrushUsesRollingWindowsAndRejectsUnknownSchema(t *testing.T) {
	home := t.TempDir()
	globalData := t.TempDir()
	t.Setenv("CRUSH_GLOBAL_DATA", globalData)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	dataDir := filepath.Join(t.TempDir(), ".crush")
	writeCrushProjects(t, globalData, dataDir)
	databasePath := filepath.Join(dataDir, "crush.db")
	database := createCrushUsageDatabase(t, databasePath)
	observed := now.AddDate(0, 0, -60)
	insertCrushMessage(t, database, "session-old", "assistant", observed, []any{
		crushToolCall("old", "view", map[string]any{"file_path": "crush://skills/research/SKILL.md"}),
	})
	insertCrushMessage(t, database, "session-old", "tool", observed, []any{
		crushToolResult("old", "view", false, map[string]any{"resource_type": "skill", "resource_name": "research"}),
	})
	_, err := database.Exec(`UPDATE messages SET created_at = ?, updated_at = ?, finished_at = ?`, observed.Unix(), observed.Unix(), observed.Unix())
	require.NoError(t, err)
	require.NoError(t, database.Close())

	usage, err := CollectCrush(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])

	require.NoError(t, os.Remove(databasePath))
	invalid, openErr := sql.Open("sqlite", databasePath)
	require.NoError(t, openErr)
	_, execErr := invalid.Exec(`CREATE TABLE messages (session_id TEXT, parts TEXT)`)
	require.NoError(t, execErr)
	require.NoError(t, invalid.Close())
	_, err = CollectCrush(home, now)
	require.Error(t, err)
}

func writeCrushProjects(t *testing.T, globalData, dataDir string) {
	t.Helper()
	encoded, err := json.Marshal(map[string]any{"projects": []any{map[string]any{
		"path": "/workspace/example", "data_dir": dataDir, "last_accessed": "2026-08-10T00:00:00Z",
	}}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(globalData, "projects.json"), encoded, 0o600))
}

func createCrushUsageDatabase(t *testing.T, path string) *sql.DB {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	_, err = database.Exec(`CREATE TABLE messages (
		id TEXT PRIMARY KEY,
		session_id TEXT NOT NULL,
		role TEXT NOT NULL,
		parts TEXT NOT NULL,
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL,
		finished_at INTEGER
	)`)
	require.NoError(t, err)
	return database
}

func insertCrushMessage(t *testing.T, database *sql.DB, sessionID, role string, observed time.Time, parts []any) {
	t.Helper()
	encoded, err := json.Marshal(parts)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO messages(id, session_id, role, parts, created_at, updated_at, finished_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		sessionID+role+observed.String(), sessionID, role, string(encoded), observed.UnixMilli(), observed.UnixMilli(), observed.UnixMilli())
	require.NoError(t, err)
}

func crushToolCall(id, name string, input map[string]any) map[string]any {
	encoded, _ := json.Marshal(input)
	return map[string]any{"type": "tool_call", "data": map[string]any{
		"id": id, "name": name, "input": string(encoded), "finished": true,
	}}
}

func crushToolResult(id, name string, isError bool, metadata map[string]any) map[string]any {
	encoded, _ := json.Marshal(metadata)
	return map[string]any{"type": "tool_result", "data": map[string]any{
		"tool_call_id": id, "name": name, "content": "result", "metadata": string(encoded), "is_error": isError,
	}}
}
