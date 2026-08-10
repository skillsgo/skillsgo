/*
 * [INPUT]: Uses isolated GitHub Copilot CLI durable Session event fixtures containing invoked, merely loaded, and duplicate Skill evidence.
 * [OUTPUT]: Specifies conservative GitHub Copilot CLI Skill invocation attribution and rolling-window aggregation.
 * [POS]: Serves as the executable contract for the GitHub Copilot CLI usage-evidence adapter.
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

func TestCollectCopilotCountsOnlyInvokedSkillsOncePerSession(t *testing.T) {
	home := t.TempDir()
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	root := filepath.Join(home, ".copilot", "session-state", "session-one")
	require.NoError(t, os.MkdirAll(root, 0o755))
	content := "" +
		`{"type":"session.skills_loaded","timestamp":"2026-08-07T09:00:00Z","data":{"skills":[{"name":"ignored"}]}}` + "\n" +
		`{"type":"skill.invoked","timestamp":"2026-08-07T10:00:00Z","data":{"name":"plugin:tdd","path":"/tmp/tdd/SKILL.md"}}` + "\n" +
		`{"type":"skill.invoked","timestamp":"2026-08-07T10:01:00Z","data":{"name":"plugin:tdd","path":"/tmp/tdd/SKILL.md"}}` + "\n"
	require.NoError(t, os.WriteFile(filepath.Join(root, "events.jsonl"), []byte(content), 0o600))

	usage, err := CollectCopilot(home, now)
	require.NoError(t, err)
	require.Equal(t, Usage{Hits45Days: 1, Hits90Days: 1}, usage["tdd"])
	require.NotContains(t, usage, "ignored")
}
