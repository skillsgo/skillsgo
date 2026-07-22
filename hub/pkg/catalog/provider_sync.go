/*
 * [INPUT]: Depends on Catalog SQL transactions and provider crawl/page/observation migration tables.
 * [OUTPUT]: Provides crawl-generation fencing, page persistence, and complete-crawl publication for provider synchronization.
 * [POS]: Serves as the durable stale-writer and snapshot boundary beneath River-scheduled provider ingestion.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

var ErrCrawlSuperseded = errors.New("provider crawl generation superseded")

type ProviderCrawlFence struct {
	CrawlID      string
	FencingToken int64
}

type ProviderObservation struct {
	SkillID  string
	Source   string
	Slug     string
	Installs int64
}

// BeginProviderCrawl starts a new generation for one scheduled window. A
// completed window is an idempotent no-op; otherwise a retry or rescued River
// job supersedes the previous generation and atomically clears its partial data.
func (c *Catalog) BeginProviderCrawl(ctx context.Context, crawlID, provider string, window time.Time) (ProviderCrawlFence, bool, error) {
	tx, err := c.db.DB.BeginTx(ctx, nil)
	if err != nil {
		return ProviderCrawlFence{}, false, err
	}
	defer func() { _ = tx.Rollback() }()
	query := `INSERT INTO provider_crawls
		(crawl_id, provider, scheduled_window, fencing_token, status, expected_pages, completed_pages, started_at)
		VALUES (?, ?, ?, 1, 'running', 0, 0, CURRENT_TIMESTAMP)
		ON CONFLICT(provider, scheduled_window) DO UPDATE SET
		fencing_token = provider_crawls.fencing_token + 1, status = 'running', expected_pages = 0,
		completed_pages = 0, failure = '', started_at = CURRENT_TIMESTAMP, completed_at = NULL
		WHERE provider_crawls.status != 'completed' RETURNING fencing_token`
	fence := ProviderCrawlFence{CrawlID: crawlID}
	err = tx.QueryRowContext(ctx, c.db.Rebind(query), crawlID, provider, window.UTC()).Scan(&fence.FencingToken)
	if errors.Is(err, sql.ErrNoRows) {
		return ProviderCrawlFence{}, false, nil
	}
	if err != nil {
		return ProviderCrawlFence{}, false, fmt.Errorf("begin provider crawl: %w", err)
	}
	if _, err := tx.ExecContext(ctx, c.db.Rebind(`DELETE FROM provider_crawl_pages WHERE crawl_id = ?`), crawlID); err != nil {
		return ProviderCrawlFence{}, false, fmt.Errorf("clear provider crawl pages: %w", err)
	}
	if _, err := tx.ExecContext(ctx, c.db.Rebind(`DELETE FROM provider_skill_observations WHERE crawl_id = ?`), crawlID); err != nil {
		return ProviderCrawlFence{}, false, fmt.Errorf("clear provider crawl observations: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return ProviderCrawlFence{}, false, fmt.Errorf("commit provider crawl generation: %w", err)
	}
	return fence, true, nil
}

func (c *Catalog) StoreProviderPage(ctx context.Context, fence ProviderCrawlFence, page, expectedPages int, observedAt time.Time, observations []ProviderObservation) error {
	return c.withCrawlTx(ctx, fence, func(tx *sql.Tx) error {
		result, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO provider_crawl_pages
			(crawl_id, page, observed_at) VALUES (?, ?, ?)
			ON CONFLICT(crawl_id, page) DO UPDATE SET observed_at = excluded.observed_at`),
			fence.CrawlID, page, observedAt.UTC())
		if err != nil {
			return fmt.Errorf("store provider page: %w", err)
		}
		if err := requireAffected(result); err != nil {
			return err
		}
		if len(observations) > 0 {
			values := make([]string, 0, len(observations))
			arguments := make([]any, 0, len(observations)*6)
			for _, item := range observations {
				values = append(values, "(?, ?, ?, ?, ?, ?)")
				arguments = append(arguments, fence.CrawlID, item.SkillID, item.Source, item.Slug, item.Installs, observedAt.UTC())
			}
			query := `INSERT INTO provider_skill_observations
				(crawl_id, skill_id, source, slug, installs, observed_at) VALUES ` +
				strings.Join(values, ",") + ` ON CONFLICT(crawl_id, skill_id) DO UPDATE SET
				source = excluded.source, slug = excluded.slug, installs = excluded.installs,
				observed_at = excluded.observed_at`
			if _, err := tx.ExecContext(ctx, c.db.Rebind(query), arguments...); err != nil {
				return fmt.Errorf("store provider observations: %w", err)
			}
		}
		result, err = tx.ExecContext(ctx, c.db.Rebind(`UPDATE provider_crawls SET expected_pages = ?,
			completed_pages = (SELECT COUNT(*) FROM provider_crawl_pages WHERE crawl_id = ?)
			WHERE crawl_id = ? AND fencing_token = ? AND status = 'running'`),
			expectedPages, fence.CrawlID, fence.CrawlID, fence.FencingToken)
		if err != nil {
			return err
		}
		return requireAffected(result)
	})
}

func (c *Catalog) CompleteProviderCrawl(ctx context.Context, fence ProviderCrawlFence) error {
	return c.withCrawlTx(ctx, fence, func(tx *sql.Tx) error {
		result, err := tx.ExecContext(ctx, c.db.Rebind(`UPDATE provider_crawls SET status = 'completed',
			completed_at = CURRENT_TIMESTAMP WHERE crawl_id = ? AND fencing_token = ? AND status = 'running'
			AND expected_pages > 0 AND completed_pages = expected_pages`), fence.CrawlID, fence.FencingToken)
		if err != nil {
			return fmt.Errorf("complete provider crawl: %w", err)
		}
		return requireAffected(result)
	})
}

func (c *Catalog) withCrawlTx(ctx context.Context, fence ProviderCrawlFence, fn func(*sql.Tx) error) error {
	tx, err := c.db.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	var valid int
	err = tx.QueryRowContext(ctx, c.db.Rebind(`SELECT 1 FROM provider_crawls WHERE crawl_id = ?
		AND fencing_token = ? AND status = 'running'`), fence.CrawlID, fence.FencingToken).Scan(&valid)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrCrawlSuperseded
	}
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}

func requireAffected(result sql.Result) error {
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count == 0 {
		return ErrCrawlSuperseded
	}
	return nil
}
