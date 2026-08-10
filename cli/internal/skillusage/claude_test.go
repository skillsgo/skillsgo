/*
 * [INPUT]: Uses isolated Claude Code Session JSONL fixtures with successful, failed, unmatched, namespaced, duplicate Skill-tool evidence, and slash-command Skill injection evidence.
 * [OUTPUT]: Specifies conservative Claude Code Skill invocation attribution across tool and slash-command forms plus rolling-window aggregation.
 * [POS]: Serves as the executable contract for the Claude Code usage-evidence adapter.
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

func TestCollectClaudeCountsOnlyCorrelatedSuccessfulSkillTools(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".claude", "projects", "workspace")
	require.NoError(t, os.MkdirAll(root, 0o755))
	session := filepath.Join(root, "session.jsonl")
	content := "" +
		`{"type":"user","message":{"content":"mention ignored-skill"}}` + "\n" +
		`{"type":"assistant","message":{"content":[{"type":"tool_use","id":"ok","name":"Skill","input":{"skill":"plugin:writing-plans"}},{"type":"tool_use","id":"failed","name":"Skill","input":{"skill":"review"}},{"type":"tool_use","id":"unmatched","name":"Skill","input":{"skill":"research"}}]}}` + "\n" +
		`{"type":"user","timestamp":"2026-08-07T10:00:00Z","message":{"content":[{"type":"tool_result","tool_use_id":"ok","is_error":false},{"type":"tool_result","tool_use_id":"failed","is_error":true}]}}` + "\n" +
		`{"type":"assistant","message":{"content":[{"type":"tool_use","id":"again","name":"Skill","input":{"skill":"plugin:writing-plans"}}]}}` + "\n" +
		`{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"again","is_error":false}]}}` + "\n"
	require.NoError(t, os.WriteFile(session, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(session, now, now))

	usage, err := CollectClaude(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["writing-plans"])
	require.NotContains(t, usage, "review")
	require.NotContains(t, usage, "research")
	require.NotContains(t, usage, "ignored-skill")
}

func TestCollectClaudeUsesConfiguredHomeAndRollingWindows(t *testing.T) {
	home := t.TempDir()
	claude := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", claude)
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(claude, "projects", "workspace")
	require.NoError(t, os.MkdirAll(root, 0o755))
	session := filepath.Join(root, "older.jsonl")
	content := `{"type":"assistant","message":{"content":[{"type":"tool_use","id":"one","name":"Skill","input":{"skill":"legacy"}}]}}` + "\n" +
		`{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"one","is_error":false}]}}` + "\n"
	require.NoError(t, os.WriteFile(session, []byte(content), 0o600))
	observed := now.AddDate(0, 0, -60)
	require.NoError(t, os.Chtimes(session, observed, observed))

	usage, err := CollectClaude(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 0, Hits90Days: 1}, usage["legacy"])
}

func TestCollectClaudeCountsSlashCommandOnlyAfterSkillBodyInjection(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".claude", "projects", "workspace")
	require.NoError(t, os.MkdirAll(root, 0o755))
	session := filepath.Join(root, "slash.jsonl")
	content := "" +
		`{"type":"user","message":{"content":"<command-message>ask-matt</command-message>\n<command-name>/ask-matt</command-name>"}}` + "\n" +
		`{"type":"user","timestamp":"2026-08-07T10:00:00Z","message":{"content":[{"type":"text","text":"Base directory for this skill: /tmp/.claude/skills/ask-matt\n\n# Ask Matt"}]}}` + "\n" +
		`{"type":"user","message":{"content":"<command-message>missing</command-message>\n<command-name>/missing</command-name>"}}` + "\n" +
		`{"type":"assistant","message":{"content":[{"type":"text","text":"Unknown skill"}]}}` + "\n"
	require.NoError(t, os.WriteFile(session, []byte(content), 0o600))
	require.NoError(t, os.Chtimes(session, now, now))

	usage, err := CollectClaude(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["ask-matt"])
	require.NotContains(t, usage, "missing")
}
