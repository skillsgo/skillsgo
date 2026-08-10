/*
 * [INPUT]: Uses isolated Goose Session SQLite fixtures containing successful, failed, unmatched, duplicate, and millisecond-timestamp `load_skill` evidence.
 * [OUTPUT]: Specifies schema-guarded Goose Skill invocation attribution, configured-root resolution, Session deduplication, and rolling windows.
 * [POS]: Serves as the executable contract for the Goose usage-evidence adapter.
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

func TestCollectGooseCountsOnlyCorrelatedSuccessfulSkillLoadsPerSession(t *testing.T) {
	home := t.TempDir()
	root := t.TempDir()
	t.Setenv("GOOSE_PATH_ROOT", root)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	databasePath := filepath.Join(root, "data", "sessions", "sessions.db")
	database := createGooseUsageDatabase(t, databasePath)
	defer database.Close()
	insertGooseMessage(t, database, "session-one", "assistant", now.Add(-time.Hour).Unix(), []any{
		gooseRequest("ok", "load_skill", map[string]any{"name": "readme-i18n"}),
		gooseRequest("bad", "load_skill", map[string]any{"name": "review"}),
		gooseRequest("other", "developer__read", map[string]any{"name": "ignored"}),
	})
	insertGooseMessage(t, database, "session-one", "user", now.Add(-time.Hour).Unix(), []any{
		gooseResponse("ok", true, false),
		gooseResponse("bad", false, true),
	})
	insertGooseMessage(t, database, "session-one", "assistant", now.UnixMilli(), []any{
		gooseRequest("again", "load_skill", map[string]any{"name": "readme-i18n/reference.md"}),
	})
	insertGooseMessage(t, database, "session-one", "user", now.UnixMilli(), []any{
		gooseResponse("again", true, false),
		gooseResponse("unmatched", true, false),
	})

	usage, err := CollectGoose(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "ignored")
}

func TestCollectGooseUsesRollingWindowsAndRejectsUnknownSchema(t *testing.T) {
	home := t.TempDir()
	root := t.TempDir()
	t.Setenv("GOOSE_PATH_ROOT", root)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	databasePath := filepath.Join(root, "data", "sessions", "sessions.db")
	database := createGooseUsageDatabase(t, databasePath)
	observed := now.AddDate(0, 0, -60).Unix()
	insertGooseMessage(t, database, "session-old", "assistant", observed, []any{
		gooseRequest("old", "load_skill", map[string]any{"name": "research"}),
	})
	insertGooseMessage(t, database, "session-old", "user", observed, []any{gooseResponse("old", true, false)})
	require.NoError(t, database.Close())

	usage, err := CollectGoose(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])

	require.NoError(t, os.Remove(databasePath))
	require.NoError(t, os.MkdirAll(filepath.Dir(databasePath), 0o755))
	invalid, openErr := sql.Open("sqlite", databasePath)
	require.NoError(t, openErr)
	_, execErr := invalid.Exec(`CREATE TABLE messages (session_id TEXT, content_json TEXT)`)
	require.NoError(t, execErr)
	require.NoError(t, invalid.Close())
	_, err = CollectGoose(home, now)
	require.Error(t, err)
}

func createGooseUsageDatabase(t *testing.T, path string) *sql.DB {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	_, err = database.Exec(`CREATE TABLE messages (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		session_id TEXT NOT NULL,
		role TEXT NOT NULL,
		content_json TEXT NOT NULL,
		created_timestamp INTEGER NOT NULL,
		metadata_json TEXT
	)`)
	require.NoError(t, err)
	return database
}

func insertGooseMessage(t *testing.T, database *sql.DB, sessionID, role string, timestamp int64, content []any) {
	t.Helper()
	encoded, err := json.Marshal(content)
	require.NoError(t, err)
	_, err = database.Exec(`INSERT INTO messages(session_id, role, content_json, created_timestamp) VALUES (?, ?, ?, ?)`, sessionID, role, string(encoded), timestamp)
	require.NoError(t, err)
}

func gooseRequest(id, name string, arguments map[string]any) map[string]any {
	return map[string]any{"type": "toolRequest", "id": id, "toolCall": map[string]any{
		"status": "success", "value": map[string]any{"name": name, "arguments": arguments},
	}}
}

func gooseResponse(id string, success, isError bool) map[string]any {
	status := "error"
	result := map[string]any{"status": status, "error": "failed"}
	if success {
		result = map[string]any{"status": "success", "value": map[string]any{"content": []any{}, "isError": isError}}
	}
	return map[string]any{"type": "toolResponse", "id": id, "toolResult": result}
}
