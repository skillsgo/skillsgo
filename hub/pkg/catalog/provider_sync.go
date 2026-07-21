/*
 * [INPUT]: Depends on Catalog SQL transactions, database time, and provider crawl/page/observation migration tables.
 * [OUTPUT]: Provides fenced lease acquisition, renewal, page persistence, and complete-crawl publication for provider synchronization.
 * [POS]: Serves as the durable concurrency and snapshot boundary for external provider ingestion.
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

var ErrLeaseLost = errors.New("provider synchronization lease lost")

type ProviderLease struct {
	JobName      string
	OwnerID      string
	FencingToken int64
}

type ProviderObservation struct {
	SkillID  string
	Source   string
	Slug     string
	Installs int64
}

func (c *Catalog) AcquireProviderLease(ctx context.Context, jobName, ownerID string, ttl time.Duration) (ProviderLease, bool, error) {
	_, err := c.db.ExecContext(ctx, c.db.Rebind(`INSERT INTO provider_sync_leases
		(job_name, owner_id, fencing_token, lease_expires_at, heartbeat_at)
		VALUES (?, '', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
		ON CONFLICT(job_name) DO NOTHING`), jobName)
	if err != nil {
		return ProviderLease{}, false, fmt.Errorf("initialize provider lease: %w", err)
	}
	seconds := int64(ttl / time.Second)
	query := `UPDATE provider_sync_leases SET owner_id = ?, fencing_token = fencing_token + 1,
		lease_expires_at = ` + c.addSecondsExpression() + `, heartbeat_at = CURRENT_TIMESTAMP
		WHERE job_name = ? AND lease_expires_at <= CURRENT_TIMESTAMP RETURNING fencing_token`
	var token int64
	err = c.db.GetContext(ctx, &token, c.db.Rebind(query), ownerID, seconds, jobName)
	if errors.Is(err, sql.ErrNoRows) {
		return ProviderLease{}, false, nil
	}
	if err != nil {
		return ProviderLease{}, false, fmt.Errorf("acquire provider lease: %w", err)
	}
	return ProviderLease{JobName: jobName, OwnerID: ownerID, FencingToken: token}, true, nil
}

func (c *Catalog) RenewProviderLease(ctx context.Context, lease ProviderLease, ttl time.Duration) error {
	query := `UPDATE provider_sync_leases SET lease_expires_at = ` + c.addSecondsExpression() + `,
		heartbeat_at = CURRENT_TIMESTAMP WHERE job_name = ? AND owner_id = ? AND fencing_token = ?
		AND lease_expires_at > CURRENT_TIMESTAMP`
	result, err := c.db.ExecContext(ctx, c.db.Rebind(query), int64(ttl/time.Second), lease.JobName, lease.OwnerID, lease.FencingToken)
	if err != nil {
		return fmt.Errorf("renew provider lease: %w", err)
	}
	return requireAffected(result)
}

func (c *Catalog) BeginProviderCrawl(ctx context.Context, lease ProviderLease, crawlID, provider string, window time.Time) error {
	query := `INSERT INTO provider_crawls
		(crawl_id, provider, scheduled_window, fencing_token, status, expected_pages, completed_pages, started_at)
		VALUES (?, ?, ?, ?, 'running', 0, 0, CURRENT_TIMESTAMP)
		ON CONFLICT(provider, scheduled_window) DO UPDATE SET fencing_token = excluded.fencing_token,
		status = 'running', expected_pages = 0, completed_pages = 0, failure = '', started_at = CURRENT_TIMESTAMP,
		completed_at = NULL WHERE provider_crawls.status != 'completed'`
	return c.withLeaseTx(ctx, lease, func(tx *sql.Tx) error {
		result, err := tx.ExecContext(ctx, c.db.Rebind(query), crawlID, provider, window.UTC(), lease.FencingToken)
		if err != nil {
			return fmt.Errorf("begin provider crawl: %w", err)
		}
		if err := requireAffected(result); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`DELETE FROM provider_crawl_pages WHERE crawl_id = ?`), crawlID); err != nil {
			return fmt.Errorf("clear provider crawl pages: %w", err)
		}
		if _, err := tx.ExecContext(ctx, c.db.Rebind(`DELETE FROM provider_skill_observations WHERE crawl_id = ?`), crawlID); err != nil {
			return fmt.Errorf("clear provider crawl observations: %w", err)
		}
		return nil
	})
}

func (c *Catalog) StoreProviderPage(ctx context.Context, lease ProviderLease, crawlID string, page, expectedPages int, observedAt time.Time, observations []ProviderObservation) error {
	return c.withLeaseTx(ctx, lease, func(tx *sql.Tx) error {
		result, err := tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO provider_crawl_pages
			(crawl_id, page, fencing_token, observed_at) VALUES (?, ?, ?, ?)
			ON CONFLICT(crawl_id, page) DO UPDATE SET fencing_token = excluded.fencing_token,
			observed_at = excluded.observed_at`), crawlID, page, lease.FencingToken, observedAt.UTC())
		if err != nil {
			return fmt.Errorf("store provider page: %w", err)
		}
		if err := requireAffected(result); err != nil {
			return err
		}
		if len(observations) > 0 {
			values := make([]string, 0, len(observations))
			arguments := make([]any, 0, len(observations)*7)
			for _, item := range observations {
				values = append(values, "(?, ?, ?, ?, ?, ?, ?)")
				arguments = append(arguments, crawlID, item.SkillID, item.Source, item.Slug, item.Installs, observedAt.UTC(), lease.FencingToken)
			}
			query := `INSERT INTO provider_skill_observations
				(crawl_id, skill_id, source, slug, installs, observed_at, fencing_token) VALUES ` +
				strings.Join(values, ",") + ` ON CONFLICT(crawl_id, skill_id) DO UPDATE SET
				source = excluded.source, slug = excluded.slug, installs = excluded.installs,
				observed_at = excluded.observed_at, fencing_token = excluded.fencing_token`
			if _, err := tx.ExecContext(ctx, c.db.Rebind(query), arguments...); err != nil {
				return fmt.Errorf("store provider observations: %w", err)
			}
		}
		result, err = tx.ExecContext(ctx, c.db.Rebind(`UPDATE provider_crawls SET expected_pages = ?,
			completed_pages = (SELECT COUNT(*) FROM provider_crawl_pages WHERE crawl_id = ?)
			WHERE crawl_id = ? AND fencing_token = ? AND status = 'running'`), expectedPages, crawlID, crawlID, lease.FencingToken)
		if err != nil {
			return err
		}
		return requireAffected(result)
	})
}

func (c *Catalog) CompleteProviderCrawl(ctx context.Context, lease ProviderLease, crawlID string) error {
	return c.withLeaseTx(ctx, lease, func(tx *sql.Tx) error {
		result, err := tx.ExecContext(ctx, c.db.Rebind(`UPDATE provider_crawls SET status = 'completed',
			completed_at = CURRENT_TIMESTAMP WHERE crawl_id = ? AND fencing_token = ? AND status = 'running'
			AND expected_pages > 0 AND completed_pages = expected_pages`), crawlID, lease.FencingToken)
		if err != nil {
			return fmt.Errorf("complete provider crawl: %w", err)
		}
		return requireAffected(result)
	})
}

func (c *Catalog) withLeaseTx(ctx context.Context, lease ProviderLease, fn func(*sql.Tx) error) error {
	tx, err := c.db.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	var valid int
	err = tx.QueryRowContext(ctx, c.db.Rebind(`SELECT 1 FROM provider_sync_leases WHERE job_name = ?
		AND owner_id = ? AND fencing_token = ? AND lease_expires_at > CURRENT_TIMESTAMP`),
		lease.JobName, lease.OwnerID, lease.FencingToken).Scan(&valid)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrLeaseLost
	}
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}

func (c *Catalog) addSecondsExpression() string {
	if c.dialect == Postgres {
		return "CURRENT_TIMESTAMP + (? * INTERVAL '1 second')"
	}
	return "datetime(CURRENT_TIMESTAMP, '+' || ? || ' seconds')"
}

func requireAffected(result sql.Result) error {
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count == 0 {
		return ErrLeaseLost
	}
	return nil
}
