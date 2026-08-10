/*
 * [INPUT]: Uses isolated Pi Session JSONL fixtures with expanded Skill commands, successful and failed correlated `SKILL.md` reads, corruption, configured directories, and event timestamps.
 * [OUTPUT]: Specifies conservative Pi Skill invocation attribution, timestamp and corruption completeness, Session deduplication, and rolling windows.
 * [POS]: Serves as the executable contract for the Pi usage-evidence adapter.
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

func TestCollectPiCountsExpandedCommandsAndSuccessfulSkillReadsPerSession(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".pi", "agent", "sessions", "--work--")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := "" +
		`{"type":"session","version":3,"id":"session-one","timestamp":"2026-08-10T09:00:00Z","cwd":"/work"}` + "\n" +
		`{"type":"message","id":"u1","parentId":null,"timestamp":"2026-08-10T09:01:00Z","message":{"role":"user","content":[{"type":"text","text":"<skill name=\"readme-i18n\" location=\"/skills/readme-i18n/SKILL.md\">\nbody\n</skill>"}],"timestamp":1786352460000}}` + "\n" +
		`{"type":"message","id":"a1","parentId":"u1","timestamp":"2026-08-10T09:02:00Z","message":{"role":"assistant","content":[{"type":"toolCall","id":"ok","name":"read","arguments":{"path":"/skills/research/SKILL.md"}},{"type":"toolCall","id":"bad","name":"read","arguments":{"path":"/skills/review/SKILL.md"}},{"type":"toolCall","id":"other","name":"read","arguments":{"path":"/work/README.md"}}],"timestamp":1786352520000}}` + "\n" +
		`{"type":"message","id":"r1","parentId":"a1","timestamp":"2026-08-10T09:02:01Z","message":{"role":"toolResult","toolCallId":"ok","toolName":"read","content":[{"type":"text","text":"---\nname: research\ndescription: Research.\n---\nbody"}],"isError":false,"timestamp":1786352521000}}` + "\n" +
		`{"type":"message","id":"r2","parentId":"r1","timestamp":"2026-08-10T09:02:02Z","message":{"role":"toolResult","toolCallId":"bad","toolName":"read","content":[{"type":"text","text":"---\nname: review\n---"}],"isError":true,"timestamp":1786352522000}}` + "\n" +
		`{"type":"message","id":"u2","parentId":"r2","timestamp":"2026-08-10T09:03:00Z","message":{"role":"user","content":[{"type":"text","text":"<skill name=\"readme-i18n\" location=\"/skills/readme-i18n/SKILL.md\">again</skill>"}],"timestamp":1786352580000}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectPi(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["research"])
	require.NotContains(t, usage, "review")
}

func TestCollectPiUsesConfiguredSessionDirectoryAndRollingWindows(t *testing.T) {
	home := t.TempDir()
	sessions := t.TempDir()
	t.Setenv("PI_CODING_AGENT_SESSION_DIR", sessions)
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	content := `{"type":"session","version":3,"id":"session-old","timestamp":"2026-06-11T09:00:00Z","cwd":"C:\\work"}` + "\n" +
		`{"type":"message","id":"u1","parentId":null,"timestamp":"2026-06-11T09:01:00Z","message":{"role":"user","content":"<skill name=\"research\" location=\"C:\\\\skills\\\\research\\\\SKILL.md\">body</skill>","timestamp":1781168460000}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(sessions, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectPi(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])
}

func TestCollectPiCorruptSessionMarksUsageIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".pi", "agent", "sessions")
	require.NoError(t, os.MkdirAll(root, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(root, "broken.jsonl"), []byte("not-json\n"), 0o600))

	_, err := CollectPi(home, now)
	require.Error(t, err)
}

func TestCollectPiInvalidMessageTimestampIsIncomplete(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".pi", "agent", "sessions")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := `{"type":"session","id":"time"}` + "\n" +
		`{"type":"message","message":{"role":"user","content":"<skill name=\"review\" location=\"/skills/review/SKILL.md\">body</skill>"}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "session.jsonl"), []byte(content), 0o600))

	usage, err := CollectPi(home, now)
	require.Error(t, err)
	require.NotContains(t, usage, "review")
}
