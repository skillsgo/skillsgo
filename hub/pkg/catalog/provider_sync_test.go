/*
 * [INPUT]: Uses a temporary SQLite Catalog to exercise crawl-generation fencing deterministically.
 * [OUTPUT]: Specifies monotonic crawl fencing, stale-writer rejection, takeover cleanup, idempotent completed windows, and complete-crawl publication.
 * [POS]: Serves as concurrency contract coverage for external provider synchronization persistence.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
)

func TestProviderSyncRejectsStaleWriterAfterCrawlTakeover(t *testing.T) {
	ctx := context.Background()
	c, err := Open(ctx, config.DatabaseConfig{Type: "sqlite", DSN: filepath.Join(t.TempDir(), "hub.db"), MaxOpenConns: 1, MaxIdleConns: 1})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, c.Close()) })

	window := time.Date(2026, time.July, 21, 12, 0, 0, 0, time.UTC)
	crawlID := "skillssh-20260721T120000Z"
	fenceA, started, err := c.BeginProviderCrawl(ctx, crawlID, "skills.sh", window)
	require.NoError(t, err)
	require.True(t, started)
	require.NoError(t, c.StoreProviderPage(ctx, fenceA, 0, 2, window, []ProviderObservation{{SkillID: "old", Source: "a/b", Slug: "old", Installs: 1}}))

	fenceB, started, err := c.BeginProviderCrawl(ctx, crawlID, "skills.sh", window)
	require.NoError(t, err)
	require.True(t, started)
	require.Greater(t, fenceB.FencingToken, fenceA.FencingToken)

	require.ErrorIs(t, c.StoreProviderPage(ctx, fenceA, 1, 2, window, nil), ErrCrawlSuperseded)
	require.NoError(t, c.StoreProviderPage(ctx, fenceB, 0, 1, window, []ProviderObservation{{SkillID: "new", Source: "a/b", Slug: "new", Installs: 2}}))
	require.NoError(t, c.CompleteProviderCrawl(ctx, fenceB))
	_, started, err = c.BeginProviderCrawl(ctx, crawlID, "skills.sh", window)
	require.NoError(t, err)
	require.False(t, started)

	var oldCount, newCount int
	require.NoError(t, c.db.GetContext(ctx, &oldCount, `SELECT COUNT(*) FROM provider_skill_observations WHERE crawl_id = ? AND skill_id = 'old'`, crawlID))
	require.NoError(t, c.db.GetContext(ctx, &newCount, `SELECT COUNT(*) FROM provider_skill_observations WHERE crawl_id = ? AND skill_id = 'new'`, crawlID))
	require.Zero(t, oldCount)
	require.Equal(t, 1, newCount)
}
