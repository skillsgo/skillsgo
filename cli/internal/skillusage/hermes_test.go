/*
 * [INPUT]: Uses isolated Hermes state.db fixtures containing successful, failed, expanded-command, duplicate, and rolling-window Skill evidence.
 * [OUTPUT]: Specifies conservative Hermes Agent Skill invocation attribution across the default home and profile databases.
 * [POS]: Serves as the executable contract for the Hermes Agent usage-evidence adapter.
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

func TestCollectHermesCountsTrustedSkillLoadsOncePerSession(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HERMES_HOME", filepath.Join(home, ".hermes"))
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	databasePath := filepath.Join(home, ".hermes", "state.db")
	writeHermesUsageFixture(t, databasePath, []hermesFixtureMessage{
		{sessionID: "recent", role: "assistant", toolCalls: hermesToolCalls("call-1", "plugin:readme-i18n"), timestamp: now.Add(-2 * time.Hour)},
		{sessionID: "recent", role: "tool", toolCallID: "call-1", toolName: "skill_view", content: `{"success":true,"name":"readme-i18n"}`, timestamp: now.Add(-2*time.Hour + time.Second)},
		{sessionID: "recent", role: "assistant", toolCalls: hermesToolCalls("call-2", "readme-i18n"), timestamp: now.Add(-time.Hour)},
		{sessionID: "recent", role: "tool", toolCallID: "call-2", toolName: "skill_view", content: `{"success":true,"name":"readme-i18n"}`, timestamp: now.Add(-time.Hour + time.Second)},
		{sessionID: "recent", role: "assistant", toolCalls: hermesToolCalls("call-failed", "ignored"), timestamp: now.Add(-time.Hour)},
		{sessionID: "recent", role: "tool", toolCallID: "call-failed", toolName: "skill_view", content: `{"success":false,"error":"missing"}`, timestamp: now.Add(-time.Hour + time.Second)},
		{sessionID: "slash", role: "user", content: `[IMPORTANT: The user has invoked the "qa" skill, indicating they want you to follow its instructions. The full skill content is loaded below.]`, timestamp: now.Add(-24 * time.Hour)},
	})

	usage, err := CollectHermes(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["qa"])
	require.NotContains(t, usage, "ignored")
}

func TestCollectHermesAggregatesProfileDatabasesAcrossRollingWindows(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HERMES_HOME", filepath.Join(home, ".hermes"))
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	profileDatabase := filepath.Join(home, ".hermes", "profiles", "research", "state.db")
	observedAt := now.AddDate(0, 0, -60)
	writeHermesUsageFixture(t, profileDatabase, []hermesFixtureMessage{
		{sessionID: "old", role: "assistant", toolCalls: hermesToolCalls("call-old", "research"), timestamp: observedAt},
		{sessionID: "old", role: "tool", toolCallID: "call-old", toolName: "skill_view", content: `{"success":true,"name":"research"}`, timestamp: observedAt.Add(time.Second)},
	})

	usage, err := CollectHermes(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])
}

func TestCollectHermesExpandsActiveProfileToTheProfileFamily(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".hermes")
	t.Setenv("HERMES_HOME", filepath.Join(root, "profiles", "active"))
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	writeHermesUsageFixture(t, filepath.Join(root, "state.db"), []hermesFixtureMessage{
		{sessionID: "default", role: "user", content: `[IMPORTANT: The user has invoked the "default-skill" skill, indicating they want you to follow its instructions.]`, timestamp: now},
	})
	writeHermesUsageFixture(t, filepath.Join(root, "profiles", "sibling", "state.db"), []hermesFixtureMessage{
		{sessionID: "sibling", role: "user", content: `[IMPORTANT: The user has invoked the "sibling-skill" skill, indicating they want you to follow its instructions.]`, timestamp: now},
	})

	usage, err := CollectHermes(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["default-skill"])
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["sibling-skill"])
}

func TestHermesDefaultHomeMatchesUpstreamPlatformRules(t *testing.T) {
	home := filepath.Join("users", "freeman")
	require.Equal(t, filepath.Join(home, ".hermes"), hermesDefaultHome(home, "darwin", ""))
	require.Equal(t, filepath.Join("local", "hermes"), hermesDefaultHome(home, "windows", "local"))
	require.Equal(t, filepath.Join(home, "AppData", "Local", "hermes"), hermesDefaultHome(home, "windows", ""))
}

type hermesFixtureMessage struct {
	sessionID  string
	role       string
	content    string
	toolCallID string
	toolCalls  string
	toolName   string
	timestamp  time.Time
}

func hermesToolCalls(callID, name string) string {
	arguments, _ := json.Marshal(map[string]string{"name": name})
	calls, _ := json.Marshal([]map[string]any{{
		"id":       callID,
		"function": map[string]any{"name": "skill_view", "arguments": string(arguments)},
	}})
	return string(calls)
}

func writeHermesUsageFixture(t *testing.T, path string, messages []hermesFixtureMessage) {
	t.Helper()
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, database.Close()) })
	_, err = database.Exec(`CREATE TABLE messages (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		session_id TEXT NOT NULL,
		role TEXT NOT NULL,
		content TEXT,
		tool_call_id TEXT,
		tool_calls TEXT,
		tool_name TEXT,
		timestamp REAL NOT NULL
	)`)
	require.NoError(t, err)
	for _, message := range messages {
		_, err = database.Exec(`INSERT INTO messages
			(session_id, role, content, tool_call_id, tool_calls, tool_name, timestamp)
			VALUES (?, ?, ?, ?, ?, ?, ?)`, message.sessionID, message.role, message.content,
			message.toolCallID, message.toolCalls, message.toolName, float64(message.timestamp.UnixNano())/1e9)
		require.NoError(t, err)
	}
}
