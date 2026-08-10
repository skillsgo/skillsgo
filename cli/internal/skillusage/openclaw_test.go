/*
 * [INPUT]: Uses isolated OpenClaw Session JSONL fixtures containing successful, failed, duplicate, archived, and incidental Skill-path evidence.
 * [OUTPUT]: Specifies correlated successful OpenClaw Skill instruction-load attribution and rolling-window aggregation.
 * [POS]: Serves as the executable contract for the OpenClaw usage-evidence adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCollectOpenClawCountsOnlyVerifiedSuccessfulSkillReads(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	sessions := filepath.Join(home, ".openclaw", "agents", "main", "sessions")
	require.NoError(t, os.MkdirAll(sessions, 0o755))
	content := "" +
		`{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Maybe /tmp/ignored/SKILL.md"}]}}` + "\n" +
		openClawReadCall("call-1", "/tmp/readme-i18n/SKILL.md") + "\n" +
		openClawReadResult("call-1", false, "---\nname: readme-i18n\ndescription: Translate\n---\n# Instructions", now.Add(-2*time.Hour)) + "\n" +
		openClawReadCall("call-2", "/tmp/readme-i18n/SKILL.md") + "\n" +
		openClawReadResult("call-2", false, "---\nname: readme-i18n\ndescription: Translate\n---\n# Instructions", now.Add(-time.Hour)) + "\n" +
		openClawReadCall("call-failed", "/tmp/ignored/SKILL.md") + "\n" +
		openClawReadResult("call-failed", true, "read failed", now.Add(-time.Hour)) + "\n" +
		openClawReadCall("call-mismatch", "/tmp/wrong-directory/SKILL.md") + "\n" +
		openClawReadResult("call-mismatch", false, "---\nname: another-skill\n---\n", now.Add(-time.Hour)) + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(sessions, "session-one.jsonl"), []byte(content), 0o600))

	usage, err := CollectOpenClaw(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "ignored")
	require.NotContains(t, usage, "another-skill")
}

func TestCollectOpenClawIncludesResetSessionsInNinetyDayWindow(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	sessions := filepath.Join(home, ".openclaw", "agents", "research", "sessions")
	require.NoError(t, os.MkdirAll(sessions, 0o755))
	observedAt := now.AddDate(0, 0, -60)
	content := openClawReadCall("call-old", `C:\\skills\\research\\SKILL.md`) + "\n" +
		openClawReadResult("call-old", false, "---\nname: research\n---\n", observedAt) + "\n"
	path := filepath.Join(sessions, "session-old.jsonl.reset.2026-08-09T00-00-00.000Z")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(path, now, now))

	usage, err := CollectOpenClaw(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["research"])
}

func openClawReadCall(callID, path string) string {
	return fmt.Sprintf(`{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","id":%q,"name":"read","arguments":{"file_path":%q}}]}}`, callID, path)
}

func openClawReadResult(callID string, isError bool, text string, observedAt time.Time) string {
	return fmt.Sprintf(`{"type":"message","message":{"role":"toolResult","toolCallId":%q,"toolName":"read","content":[{"type":"text","text":%q}],"isError":%t,"timestamp":%d}}`, callID, text, isError, observedAt.UnixMilli())
}
