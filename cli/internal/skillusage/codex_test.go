/*
 * [INPUT]: Uses isolated Codex rollout files and disposable SkillsGo cache directories with controlled timestamps.
 * [OUTPUT]: Specifies Codex session deduplication, 45/90-day boundaries, persisted daily buckets, cache refresh, and stale-session removal.
 * [POS]: Serves as the executable contract for the Codex Skill usage adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCollectCodexAggregatesSessionsAcrossRollingWindows(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	writeRollout(t, home, "recent.jsonl", now.AddDate(0, 0, -10), "pdf", "pdf", "browser")
	writeRollout(t, home, "older.jsonl", now.AddDate(0, 0, -60), "pdf")
	writeRollout(t, home, "expired.jsonl", now.AddDate(0, 0, -90), "pdf")
	writeTimedRollout(t, home, "long-lived.jsonl", now, now.AddDate(0, 0, -60), "legacy")

	usage, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 2}, usage["pdf"])
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["browser"])
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["legacy"])
	_, err = os.Stat(filepath.Join(home, ".skillsgo", "cache", "skill-usage", "codex-2026-07-24.json"))
	require.NoError(t, err)
}

func writeTimedRollout(t *testing.T, home, name string, modified, occurred time.Time, skill string) string {
	t.Helper()
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, name)
	content := `{"timestamp":"` + occurred.Format(time.RFC3339Nano) + `","payload":"<skill>\n<name>` + skill + `</name>\n</skill>"}` + "\n"
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(path, modified, modified))
	return path
}

func TestCollectCodexRefreshesChangedAndRemovesMissingSessions(t *testing.T) {
	home := t.TempDir()
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	now := time.Date(2026, 8, 3, 12, 0, 0, 0, time.UTC)
	path := writeRollout(t, home, "session.jsonl", now, "pdf")

	first, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Equal(t, 1, first["pdf"].Hits45Days)
	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	require.NoError(t, err)
	_, err = file.WriteString(`{"payload":"<skill>\n<name>browser</name>\n</skill>"}` + "\n")
	require.NoError(t, err)
	require.NoError(t, file.Close())
	require.NoError(t, os.Chtimes(path, now.Add(time.Minute), now.Add(time.Minute)))

	incremental, err := CollectCodex(home, now.Add(time.Minute))
	require.NoError(t, err)
	require.Equal(t, 1, incremental["pdf"].Hits45Days)
	require.Equal(t, 1, incremental["browser"].Hits45Days)

	require.NoError(t, os.Remove(path))
	second, err := CollectCodex(home, now)
	require.NoError(t, err)
	require.Empty(t, second)
}

func writeRollout(t *testing.T, home, name string, modified time.Time, skills ...string) string {
	t.Helper()
	root := filepath.Join(home, ".codex", "sessions", "2026", "08", "03")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, name)
	content := ""
	for _, skill := range skills {
		content += `{"payload":"<skill>\n<name>` + skill + `</name>\n</skill>"}` + "\n"
	}
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(path, modified, modified))
	return path
}
