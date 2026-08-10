/*
 * [INPUT]: Uses isolated OpenCode SQLite fixtures containing completed, failed, duplicate, and older-window Skill tool parts.
 * [OUTPUT]: Specifies content-free OpenCode Skill usage queries, Session deduplication, configured database resolution, and rolling-window aggregation.
 * [POS]: Serves as the executable contract for the OpenCode usage-evidence adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"
)

func TestCollectOpenCodeCountsCompletedSkillToolsOncePerSession(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "opencode.db")
	t.Setenv("OPENCODE_DB", path)
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	database, err := sql.Open("sqlite", path)
	require.NoError(t, err)
	_, err = database.Exec(`CREATE TABLE part (id text PRIMARY KEY, message_id text NOT NULL, session_id text NOT NULL, time_created integer NOT NULL, time_updated integer NOT NULL, data text NOT NULL)`)
	require.NoError(t, err)
	insert := func(id, session, name, status string, observed time.Time) {
		data := fmt.Sprintf(`{"type":"tool","tool":"skill","state":{"status":%q,"input":{"name":%q}}}`, status, name)
		_, insertErr := database.Exec(`INSERT INTO part VALUES (?, 'message', ?, ?, ?, ?)`, id, session, observed.UnixMilli(), observed.UnixMilli(), data)
		require.NoError(t, insertErr)
	}
	insert("one", "session-a", "review", "completed", now)
	insert("duplicate", "session-a", "review", "completed", now)
	insert("two", "session-b", "review", "completed", now.AddDate(0, 0, -60))
	insert("failed", "session-c", "ignored", "error", now)
	insert("future", "session-d", "future", "completed", now.Add(time.Minute))
	require.NoError(t, database.Close())

	usage, err := CollectOpenCode(root, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 2}, usage["review"])
	require.NotContains(t, usage, "ignored")
	require.NotContains(t, usage, "future")
}

func TestCollectOpenCodeIgnoresMissingDatabase(t *testing.T) {
	home := t.TempDir()
	t.Setenv("OPENCODE_DB", filepath.Join(home, "missing.db"))
	usage, err := CollectOpenCode(home, time.Now())
	require.NoError(t, err)
	require.Empty(t, usage)
}
