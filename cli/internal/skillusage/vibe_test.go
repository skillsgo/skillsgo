/*
 * [INPUT]: Uses isolated Mistral Vibe Session JSONL, metadata, and TOML fixtures with correlated persisted Skill results, failures, corruption, configured homes, configured Session logging, and rolling-window Session timestamps.
 * [OUTPUT]: Specifies conservative Mistral Vibe Skill invocation attribution, metadata/argument corruption completeness, section-scoped configuration, and cross-platform home resolution.
 * [POS]: Serves as the executable contract for the Mistral Vibe usage-evidence adapter.
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

func TestCollectVibeCountsOnlyCorrelatedPersistedSkillResultsPerSession(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	session := filepath.Join(home, ".vibe", "logs", "session", "session_one")
	require.NoError(t, os.MkdirAll(session, 0o755))
	content := "" +
		`{"role":"assistant","content":"","tool_calls":[{"id":"ok","function":{"name":"skill","arguments":"{\"name\":\"readme-i18n\"}"}},{"id":"bad","function":{"name":"skill","arguments":"{\"name\":\"review\"}"}},{"id":"other","function":{"name":"read_file","arguments":"{\"name\":\"ignored\"}"}}]}` + "\n" +
		`{"role":"tool","name":"skill","tool_call_id":"ok","content":"name: readme-i18n","tool_result":{"output":{"name":"readme-i18n","content":"loaded"}}}` + "\n" +
		`{"role":"tool","name":"skill","tool_call_id":"bad","content":"Skill not found"}` + "\n" +
		`{"role":"assistant","content":"","tool_calls":[{"id":"again","function":{"name":"skill","arguments":"{\"name\":\"readme-i18n\"}"}}]}` + "\n" +
		`{"role":"tool","name":"skill","tool_call_id":"again","content":"loaded","tool_result":{"output":{"name":"readme-i18n","content":"loaded"}}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(session, "messages.jsonl"), []byte(content), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(session, "meta.json"), []byte(`{"session_id":"session-one","end_time":"2026-08-10T10:00:00Z"}`), 0o600))

	usage, err := CollectVibe(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "ignored")
}

func TestCollectVibeUsesConfiguredHomeAndSessionEndForRollingWindows(t *testing.T) {
	home := t.TempDir()
	vibeHome := t.TempDir()
	t.Setenv("VIBE_HOME", vibeHome)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	session := filepath.Join(vibeHome, "logs", "session", "session_old")
	require.NoError(t, os.MkdirAll(session, 0o755))
	content := `{"role":"assistant","tool_calls":[{"id":"old","function":{"name":"skill","arguments":"{\"name\":\"research\"}"}}]}` + "\n" +
		`{"role":"tool","name":"skill","tool_call_id":"old","tool_result":{"output":{"name":"research","content":"loaded"}}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(session, "messages.jsonl"), []byte(content), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(session, "meta.json"), []byte(`{"session_id":"session-old","end_time":"2026-06-11T10:00:00Z"}`), 0o600))

	usage, err := CollectVibe(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])
}

func TestVibeSessionRootsOnlyReadsSessionLoggingSaveDir(t *testing.T) {
	home := t.TempDir()
	vibeHome := filepath.Join(home, ".vibe")
	custom := filepath.Join(home, "custom-vibe-sessions")
	require.NoError(t, os.MkdirAll(vibeHome, 0o755))
	config := "[unrelated]\n" +
		"save_dir = '/wrong'\n\n" +
		"[session_logging]\n" +
		"save_dir = '" + custom + "'\n"
	require.NoError(t, os.WriteFile(filepath.Join(vibeHome, "config.toml"), []byte(config), 0o600))

	roots, err := vibeSessionRoots(home)
	require.NoError(t, err)
	require.Equal(t, []string{
		filepath.Join(vibeHome, "logs", "session"),
		custom,
	}, roots)
}

func TestVibeRelativeSaveDirUsesCurrentCandidateButMarksIncomplete(t *testing.T) {
	home := t.TempDir()
	working := t.TempDir()
	t.Chdir(working)
	vibeHome := filepath.Join(home, ".vibe")
	require.NoError(t, os.MkdirAll(vibeHome, 0o755))
	require.NoError(t, os.WriteFile(
		filepath.Join(vibeHome, "config.toml"),
		[]byte("[session_logging]\nsave_dir = '.vibe-sessions'\n"),
		0o600,
	))

	roots, err := vibeSessionRoots(home)
	require.Error(t, err)
	require.Contains(t, roots, filepath.Join(working, ".vibe-sessions"))
}

func TestCollectVibeCorruptSessionOrLoggingConfigMarksUsageIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	vibeHome := filepath.Join(home, ".vibe")
	session := filepath.Join(vibeHome, "logs", "session", "broken")
	require.NoError(t, os.MkdirAll(session, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(session, "messages.jsonl"), []byte("not-json\n"), 0o600))

	_, err := CollectVibe(home, now)
	require.Error(t, err)

	require.NoError(t, os.RemoveAll(filepath.Join(vibeHome, "logs")))
	require.NoError(t, os.WriteFile(filepath.Join(vibeHome, "config.toml"), []byte("[session_logging]\nsave_dir = 42\n"), 0o600))
	_, err = CollectVibe(home, now)
	require.Error(t, err)
}

func TestCollectVibeMissingOrInvalidMetadataAndArgumentsMarkUsageIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	session := filepath.Join(home, ".vibe", "logs", "session", "broken-meta")
	require.NoError(t, os.MkdirAll(session, 0o755))
	content := `{"role":"assistant","tool_calls":[{"id":"bad","function":{"name":"skill","arguments":"not-json"}}]}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(session, "messages.jsonl"), []byte(content), 0o600))

	_, err := CollectVibe(home, now)
	require.Error(t, err)

	require.NoError(t, os.WriteFile(filepath.Join(session, "meta.json"), []byte(`{"session_id":"broken","end_time":"not-a-time"}`), 0o600))
	_, err = CollectVibe(home, now)
	require.Error(t, err)
}

func TestCollectVibeCacheRefreshesWhenOnlyMetadataChanges(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	session := filepath.Join(home, ".vibe", "logs", "session", "metadata-update")
	require.NoError(t, os.MkdirAll(session, 0o755))
	content := `{"role":"assistant","tool_calls":[{"id":"call","function":{"name":"skill","arguments":"{\"name\":\"research\"}"}}]}` + "\n" +
		`{"role":"tool","name":"skill","tool_call_id":"call","tool_result":{"output":{"name":"research"}}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(session, "messages.jsonl"), []byte(content), 0o600))
	metadataPath := filepath.Join(session, "meta.json")
	require.NoError(t, os.WriteFile(metadataPath, []byte(`{"session_id":"metadata","end_time":"2026-06-11T10:00:00Z"}`), 0o600))
	usage, err := CollectVibe(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])

	require.NoError(t, os.WriteFile(metadataPath, []byte(`{"session_id":"metadata","end_time":"2026-08-10T10:00:00Z"}`), 0o600))
	require.NoError(t, os.Chtimes(metadataPath, now, now))
	usage, err = CollectVibe(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["research"])
}
