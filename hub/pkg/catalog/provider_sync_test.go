/*
 * [INPUT]: Uses a temporary SQLite Catalog and direct lease expiry setup to exercise fencing boundaries deterministically.
 * [OUTPUT]: Specifies exclusive lease acquisition, monotonic fencing, stale-writer rejection, takeover cleanup, and complete-crawl publication.
 * [POS]: Serves as concurrency contract coverage for external provider synchronization persistence.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
)

func TestProviderSyncRejectsStaleWriterAfterLeaseTakeover(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	window := time.Date(2026, time.July, 21, 12, 0, 0, 0, time.UTC)
	crawlID := "skillssh-20260721T120000Z"
	leaseA, acquired, err := c.AcquireProviderLease(ctx, "skillssh", "hub-a", time.Minute)
	require.NoError(t, err)
	require.True(t, acquired)
	require.NoError(t, c.BeginProviderCrawl(ctx, leaseA, crawlID, "skills.sh", window))
	require.NoError(t, c.StoreProviderPage(ctx, leaseA, crawlID, 0, 2, window, []ProviderObservation{{SkillID: "old", Source: "a/b", Slug: "old", Installs: 1}}))

	_, err = c.db.ExecContext(ctx, `UPDATE provider_sync_leases SET lease_expires_at = datetime(CURRENT_TIMESTAMP, '-1 second') WHERE job_name = ?`, "skillssh")
	require.NoError(t, err)
	leaseB, acquired, err := c.AcquireProviderLease(ctx, "skillssh", "hub-b", time.Minute)
	require.NoError(t, err)
	require.True(t, acquired)
	require.Greater(t, leaseB.FencingToken, leaseA.FencingToken)

	err = c.StoreProviderPage(ctx, leaseA, crawlID, 1, 2, window, nil)
	require.True(t, errors.Is(err, ErrLeaseLost))
	require.NoError(t, c.BeginProviderCrawl(ctx, leaseB, crawlID, "skills.sh", window))
	require.NoError(t, c.StoreProviderPage(ctx, leaseB, crawlID, 0, 1, window, []ProviderObservation{{SkillID: "new", Source: "a/b", Slug: "new", Installs: 2}}))
	require.NoError(t, c.CompleteProviderCrawl(ctx, leaseB, crawlID))

	var oldCount, newCount int
	require.NoError(t, c.db.GetContext(ctx, &oldCount, `SELECT COUNT(*) FROM provider_skill_observations WHERE crawl_id = ? AND skill_id = 'old'`, crawlID))
	require.NoError(t, c.db.GetContext(ctx, &newCount, `SELECT COUNT(*) FROM provider_skill_observations WHERE crawl_id = ? AND skill_id = 'new'`, crawlID))
	require.Zero(t, oldCount)
	require.Equal(t, 1, newCount)
}
