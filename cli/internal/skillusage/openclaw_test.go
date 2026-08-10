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
	t.Setenv("OPENCLAW_STATE_DIR", "")
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
		openClawReadResult("call-mismatch", false, "---\nname: another-skill\n---\n# Body\n---\nname: yaml-example\n---\n", now.Add(-time.Hour)) + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(sessions, "session-one.jsonl"), []byte(content), 0o600))

	usage, err := CollectOpenClaw(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["readme-i18n"])
	require.NotContains(t, usage, "ignored")
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["another-skill"])
	require.NotContains(t, usage, "yaml-example")
}

func TestCollectOpenClawIncludesResetSessionsInNinetyDayWindow(t *testing.T) {
	t.Setenv("OPENCLAW_STATE_DIR", "")
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

func TestOpenClawStateRootExpandsConfiguredHomePath(t *testing.T) {
	home := t.TempDir()
	t.Setenv("OPENCLAW_STATE_DIR", "~/.custom-openclaw")
	require.Equal(t, filepath.Join(home, ".custom-openclaw"), openClawStateRoot(home))
}

func TestCollectOpenClawContinuesAppendedSessionFromDisposableCache(t *testing.T) {
	t.Setenv("OPENCLAW_STATE_DIR", "")
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	sessions := filepath.Join(home, ".openclaw", "agents", "main", "sessions")
	require.NoError(t, os.MkdirAll(sessions, 0o755))
	path := filepath.Join(sessions, "session-incremental.jsonl")
	require.NoError(t, os.WriteFile(path, []byte(openClawReadCall("call-pending", "/tmp/custom-dir/SKILL.md")+"\n"), 0o600))

	usage, err := CollectOpenClaw(home, now)
	require.NoError(t, err)
	require.Empty(t, usage)
	require.FileExists(t, filepath.Join(home, ".skillsgo", "cache", "skill-usage", "openclaw-state.json"))

	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o600)
	require.NoError(t, err)
	_, err = file.WriteString(openClawReadResult("call-pending", false, "---\nname: canonical-name\n---\n", now) + "\n")
	require.NoError(t, err)
	require.NoError(t, file.Close())

	usage, err = CollectOpenClaw(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["canonical-name"])
}

func TestCollectOpenClawUsesConfiguredSessionStoreDirectory(t *testing.T) {
	t.Setenv("OPENCLAW_STATE_DIR", "")
	t.Setenv("OPENCLAW_CONFIG_PATH", "")
	home := t.TempDir()
	now := time.Date(2026, 8, 10, 12, 0, 0, 0, time.UTC)
	customSessions := filepath.Join(home, "custom-sessions")
	require.NoError(t, os.MkdirAll(customSessions, 0o755))
	configRoot := filepath.Join(home, ".openclaw")
	require.NoError(t, os.MkdirAll(configRoot, 0o755))
	config := fmt.Sprintf(`{session: {store: %q}}`, filepath.Join(customSessions, "sessions.json"))
	require.NoError(t, os.WriteFile(filepath.Join(configRoot, "openclaw.json"), []byte(config), 0o600))
	content := openClawReadCall("custom", "/tmp/custom/SKILL.md") + "\n" +
		openClawReadResult("custom", false, "---\nname: custom-store-skill\n---\n", now) + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(customSessions, "custom.jsonl"), []byte(content), 0o600))

	usage, err := CollectOpenClaw(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["custom-store-skill"])
}

func openClawReadCall(callID, path string) string {
	return fmt.Sprintf(`{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","id":%q,"name":"read","arguments":{"file_path":%q}}]}}`, callID, path)
}

func openClawReadResult(callID string, isError bool, text string, observedAt time.Time) string {
	return fmt.Sprintf(`{"type":"message","message":{"role":"toolResult","toolCallId":%q,"toolName":"read","content":[{"type":"text","text":%q}],"isError":%t,"timestamp":%d}}`, callID, text, isError, observedAt.UnixMilli())
}
