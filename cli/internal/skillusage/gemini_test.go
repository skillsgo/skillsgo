/*
 * [INPUT]: Uses isolated Gemini CLI JSONL transcripts containing repeated tool snapshots, successful and failed Skill activations, known and unknown rewinds, corruption, configured homes, incremental cache reuse, and rolling-window timestamps.
 * [OUTPUT]: Specifies conservative Gemini CLI `activate_skill` attribution, timestamp and corruption completeness, incremental cache retention, and cross-platform home resolution.
 * [POS]: Serves as the executable contract for the Gemini CLI usage-evidence adapter.
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

func TestCollectGeminiCountsOnlyFinalSuccessfulActivationsPerSession(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := "" +
		`{"sessionId":"session-one","projectHash":"project","startTime":"2026-08-10T09:00:00Z"}` + "\n" +
		`{"id":"m1","type":"gemini","timestamp":"2026-08-10T09:01:00Z","content":"","toolCalls":[{"id":"ok","name":"activate_skill","args":{"name":"readme-i18n"},"status":"executing","timestamp":"2026-08-10T09:01:00Z"}]}` + "\n" +
		`{"id":"m1","type":"gemini","timestamp":"2026-08-10T09:01:01Z","content":"","toolCalls":[{"id":"ok","name":"activate_skill","args":{"name":"readme-i18n"},"status":"success","timestamp":"2026-08-10T09:01:01Z"}]}` + "\n" +
		`{"id":"m2","type":"gemini","timestamp":"2026-08-10T09:02:00Z","content":"","toolCalls":[{"id":"failed","name":"activate_skill","args":{"name":"review"},"status":"error","timestamp":"2026-08-10T09:02:00Z"},{"id":"other","name":"read_file","args":{"name":"ignored"},"status":"success","timestamp":"2026-08-10T09:02:00Z"}]}` + "\n" +
		`{"id":"m3","type":"gemini","timestamp":"2026-08-10T09:03:00Z","content":"","toolCalls":[{"id":"again","name":"activate_skill","args":{"name":"readme-i18n"},"status":"success","timestamp":"2026-08-10T09:03:00Z"}]}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectGemini(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "ignored")
}

func TestCollectGeminiHonorsRewindConfiguredHomeAndRollingWindows(t *testing.T) {
	home := t.TempDir()
	configured := t.TempDir()
	t.Setenv("GEMINI_CLI_HOME", configured)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(configured, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := "" +
		`{"sessionId":"session-two","projectHash":"project","startTime":"2026-06-11T09:00:00Z"}` + "\n" +
		`{"id":"keep","type":"gemini","timestamp":"2026-06-11T09:01:00Z","content":"","toolCalls":[{"id":"old","name":"activate_skill","args":{"name":"research"},"status":"success","timestamp":"2026-06-11T09:01:00Z"}]}` + "\n" +
		`{"id":"rewound","type":"gemini","timestamp":"2026-06-11T09:02:00Z","content":"","toolCalls":[{"id":"gone","name":"activate_skill","args":{"name":"review"},"status":"success","timestamp":"2026-06-11T09:02:00Z"}]}` + "\n" +
		`{"$rewindTo":"rewound"}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectGemini(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])
	require.NotContains(t, usage, "review")
}

func TestCollectGeminiUnknownRewindClearsHistoryAndCorruptionMarksIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"sessionId":"session-three"}` + "\n" +
		`{"id":"old","type":"gemini","timestamp":"2026-08-10T09:00:00Z","toolCalls":[{"name":"activate_skill","args":{"name":"review"},"status":"success"}]}` + "\n" +
		`{"$rewindTo":"missing"}` + "\n" +
		`not-json` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectGemini(home, now)
	require.Error(t, err)
	require.NotContains(t, usage, "review")
}

func TestCollectGeminiInvalidTimestampIsIncompleteAndDoesNotUseFileTime(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"sessionId":"session-time"}` + "\n" +
		`{"id":"message","type":"gemini","toolCalls":[{"name":"activate_skill","args":{"name":"review"},"status":"success"}]}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectGemini(home, now)
	require.Error(t, err)
	require.NotContains(t, usage, "review")
}

func TestCollectGeminiKeepsLastCompleteCacheWhenActiveFileIsTemporarilyCorrupt(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	path := filepath.Join(root, "session.jsonl")
	valid := `{"sessionId":"session-cache"}` + "\n" +
		`{"id":"message","type":"gemini","timestamp":"2026-08-10T09:00:00Z","toolCalls":[{"name":"activate_skill","args":{"name":"research"},"status":"success"}]}` + "\n"
	require.NoError(t, os.WriteFile(path, []byte(valid), 0o600))
	usage, err := CollectGemini(home, now)
	require.NoError(t, err)
	require.Equal(t, 1, usage["research"].Hits90Days)

	newTrusted := `{"id":"new","type":"gemini","timestamp":"2026-08-10T10:00:00Z","toolCalls":[{"name":"activate_skill","args":{"name":"review"},"status":"success"}]}` + "\n"
	require.NoError(t, os.WriteFile(path, []byte(valid+newTrusted+"not-json\n"), 0o600))
	usage, err = CollectGemini(home, now)
	require.Error(t, err)
	require.Equal(t, 1, usage["research"].Hits90Days)
	require.Equal(t, 1, usage["review"].Hits90Days)
}

func TestCollectGeminiColdCorruptFileReturnsTrustedPrefixAsIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"sessionId":"partial-session"}` + "\n" +
		`{"id":"message","type":"gemini","timestamp":"2026-08-10T09:00:00Z","toolCalls":[{"name":"activate_skill","args":{"name":"research"},"status":"success"}]}` + "\n" +
		"not-json\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectGemini(home, now)
	require.Error(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["research"])
}

func TestCollectGeminiCacheDeduplicatesOneSessionAcrossFiles(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".gemini", "tmp", "project", "chats")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"sessionId":"shared-session"}` + "\n" +
		`{"id":"message","type":"gemini","timestamp":"2026-08-10T09:00:00Z","toolCalls":[{"name":"activate_skill","args":{"name":"research"},"status":"success"}]}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "current.jsonl"), []byte(content), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(root, "archived.jsonl"), []byte(content), 0o600))

	usage, err := CollectGemini(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["research"])
}
