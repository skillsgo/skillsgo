/*
 * [INPUT]: Uses an isolated user home and the embedded AgentsView local providers.
 * [OUTPUT]: Specifies the private Session archive path, empty-archive completeness, stable per-Agent usage shape, and coalesced analytics invalidations.
 * [POS]: Serves as focused integration coverage for the sole active Skill-usage adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCollectArchiveCreatesPrivateSkillsGoSessionArchive(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Cleanup(func() {
		closeArchiveState(filepath.Join(home, ".skillsgo", "sessions", "sessions.db"))
	})

	result, err := CollectArchive(context.Background(), home, time.Date(2026, 8, 17, 12, 0, 0, 0, time.UTC))
	require.NoError(t, err)
	require.True(t, result.Syncing)
	require.Contains(t, result.ByAgent, "codex")
	require.Empty(t, result.ByAgent["codex"])
	require.Eventually(t, func() bool {
		result, err = CollectArchive(context.Background(), home, time.Date(2026, 8, 17, 12, 0, 0, 0, time.UTC))
		return err == nil && !result.Syncing
	}, 5*time.Second, 10*time.Millisecond)
	require.FileExists(t, filepath.Join(home, ".skillsgo", "sessions", "sessions.db"))

	info, err := os.Stat(filepath.Join(home, ".skillsgo", "sessions"))
	require.NoError(t, err)
	require.Equal(t, os.FileMode(0o700), info.Mode().Perm())
}

func TestAnalyticsInvalidationsPublishNewestRevision(t *testing.T) {
	events, cancel := SubscribeAnalyticsInvalidations()
	defer cancel()
	publishAnalyticsInvalidation()
	first := <-events
	publishAnalyticsInvalidation()
	publishAnalyticsInvalidation()
	latest := <-events
	require.Greater(t, latest.Revision, first.Revision)
}
