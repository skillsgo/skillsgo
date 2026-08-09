/*
 * [INPUT]: Uses isolated Reasonix primary and sidecar Session JSONL fixtures with successful, failed, unmatched, and duplicate Skill tool evidence.
 * [OUTPUT]: Specifies conservative Reasonix Skill invocation attribution and rolling-window aggregation.
 * [POS]: Serves as the executable contract for the Reasonix usage-evidence adapter.
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

func TestCollectReasonixCountsOnlyCorrelatedSuccessfulSkillTools(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".reasonix", "sessions")
	require.NoError(t, os.MkdirAll(root, 0o755))
	session := filepath.Join(root, "session.jsonl")
	content := "" +
		`{"role":"user","content":"mention ignored-skill"}` + "\n" +
		`{"role":"assistant","tool_calls":[{"id":"ok","name":"read_skill","arguments":"{\"name\":\"ask-matt\"}"},{"id":"failed","name":"run_skill","arguments":"{\"name\":\"review\"}"},{"id":"unmatched","name":"read_only_skill","arguments":"{\"name\":\"research\"}"}]}` + "\n" +
		`{"role":"tool","tool_call_id":"ok","name":"read_skill","content":"# Ask Matt","createdAt":1786082400000}` + "\n" +
		`{"role":"tool","tool_call_id":"failed","name":"run_skill","content":"error: unavailable"}` + "\n" +
		`{"role":"assistant","tool_calls":[{"id":"again","name":"read_skill","arguments":"{\"name\":\"ask-matt\"}"}]}` + "\n" +
		`{"role":"tool","tool_call_id":"again","name":"read_skill","content":"# Ask Matt"}` + "\n"
	require.NoError(t, os.WriteFile(session, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(session, now, now))
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.events.jsonl"), []byte(content), 0o600))

	usage, err := CollectReasonix(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["ask-matt"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "research")
	require.NotContains(t, usage, "ignored-skill")
}

func TestCollectReasonixUsesConfiguredHomeAndRollingWindows(t *testing.T) {
	home := t.TempDir()
	reasonix := t.TempDir()
	t.Setenv("REASONIX_HOME", reasonix)
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(reasonix, "projects", "workspace", "sessions")
	require.NoError(t, os.MkdirAll(root, 0o755))
	session := filepath.Join(root, "older.jsonl")
	content := `{"role":"assistant","tool_calls":[{"id":"one","name":"use_skill","arguments":"{\"name\":\"legacy\"}"}]}` + "\n" +
		`{"role":"tool","tool_call_id":"one","name":"use_skill","content":"loaded"}` + "\n"
	require.NoError(t, os.WriteFile(session, []byte(content), 0o600))
	observed := now.AddDate(0, 0, -60)
	require.NoError(t, os.Chtimes(session, observed, observed))

	usage, err := CollectReasonix(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["legacy"])
}
