/*
 * [INPUT]: Uses an isolated user home and the embedded AgentsView local providers.
 * [OUTPUT]: Specifies the private Session archive path, empty-archive completeness, stale-while-revalidate snapshots, stable per-Agent usage shape, coalesced analytics invalidations, throttled progress, and reconnect snapshots.
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

	avsdk "github.com/skillsgo/agentsview/sdk"
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

func TestCollectArchiveKeepsPublishedSnapshotAvailableWhileRefreshing(t *testing.T) {
	home := t.TempDir()
	dbPath := filepath.Join(home, ".skillsgo", "sessions", "sessions.db")
	require.NoError(t, os.MkdirAll(filepath.Dir(dbPath), 0o700))
	state := &archiveState{
		started: true,
		syncing: true,
		snapshot: &ArchiveUsage{
			ByAgent: map[string]map[string]Usage{
				"codex": {"example": {Hits45Days: 3, Hits90Days: 5}},
			},
			Errors: map[string]string{},
		},
	}
	archiveStates.Store(dbPath, state)
	t.Cleanup(func() { archiveStates.Delete(dbPath) })

	result, err := CollectArchive(context.Background(), home, time.Now())
	require.NoError(t, err)
	require.False(t, result.Syncing)
	require.Equal(t, 3, result.ByAgent["codex"]["example"].Hits45Days)
	require.Equal(t, 5, result.ByAgent["codex"]["example"].Hits90Days)
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

func TestAnalyticsProgressCoalescesAndReplaysLatest(t *testing.T) {
	resetAnalyticsProgressForTest()
	events, cancel := SubscribeAnalyticsProgress()
	defer cancel()
	publishAnalyticsProgress(avsdk.SyncProgress{Phase: "discovering"})
	first := <-events
	publishAnalyticsProgress(avsdk.SyncProgress{
		Phase:         "syncing",
		SessionsDone:  3,
		SessionsTotal: 5,
	})
	publishAnalyticsProgress(avsdk.SyncProgress{
		Phase:         "syncing",
		SessionsDone:  4,
		SessionsTotal: 5,
	})
	latest := <-events
	require.Greater(t, latest.Revision, first.Revision)
	require.Equal(t, 4, latest.Progress.SessionsDone)

	replayed, cancelReplay := SubscribeAnalyticsProgress()
	defer cancelReplay()
	require.Equal(t, latest, <-replayed)
}

func TestArchiveProgressThrottlesSamePhaseButPublishesPhaseChanges(t *testing.T) {
	resetAnalyticsProgressForTest()
	events, cancel := SubscribeAnalyticsProgress()
	defer cancel()
	state := &archiveState{}
	publishArchiveProgress(state, avsdk.SyncProgress{Phase: "discovering"})
	first := <-events
	publishArchiveProgress(state, avsdk.SyncProgress{Phase: "discovering"})
	select {
	case <-events:
		t.Fatal("same-phase progress was not throttled")
	default:
	}
	publishArchiveProgress(state, avsdk.SyncProgress{Phase: "syncing"})
	second := <-events
	require.Greater(t, second.Revision, first.Revision)
}

func resetAnalyticsProgressForTest() {
	analyticsProgressEvents.Lock()
	analyticsProgressEvents.revision = 0
	analyticsProgressEvents.latest = nil
	analyticsProgressEvents.Unlock()
}
