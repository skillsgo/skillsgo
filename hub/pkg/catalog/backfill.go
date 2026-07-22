/*
 * [INPUT]: Depends on Catalog SQL/pgx persistence, UUID run identities, and caller-supplied transactional River enqueueing.
 * [OUTPUT]: Provides durable Backfill Run creation, active-run deduplication, state transitions, diagnostics, status reads, and exact Repository Publication checks.
 * [POS]: Serves as the Catalog business-state boundary for Repository History Backfill independently of River transport tables.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	catalogent "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent"
)

type BackfillStatus string

const (
	BackfillQueued             BackfillStatus = "queued"
	BackfillRunning            BackfillStatus = "running"
	BackfillComplete           BackfillStatus = "complete"
	BackfillCompleteWithErrors BackfillStatus = "complete_with_errors"
)

// BackfillRun is durable administrator-facing business state. Diagnostics are
// intentionally bounded and sanitized by the worker before persistence.
type BackfillRun struct {
	ID           string         `json:"runId"`
	RepositoryID string         `json:"repositoryId"`
	Status       BackfillStatus `json:"status"`
	StartedAt    *time.Time     `json:"startedAt,omitempty"`
	CompletedAt  *time.Time     `json:"completedAt,omitempty"`
	ErrorCount   int            `json:"errorCount"`
	Diagnostics  []string       `json:"diagnostics"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
}

type backfillRunRow struct {
	ID           string         `db:"id"`
	RepositoryID string         `db:"repository_id"`
	Status       BackfillStatus `db:"status"`
	StartedAt    *time.Time     `db:"started_at"`
	CompletedAt  *time.Time     `db:"completed_at"`
	ErrorCount   int            `db:"error_count"`
	Diagnostics  []byte         `db:"diagnostics"`
	CreatedAt    time.Time      `db:"created_at"`
	UpdatedAt    time.Time      `db:"updated_at"`
}

// SubmitBackfillRun atomically creates a queued run and invokes enqueue with
// the same PostgreSQL transaction. An existing active run is returned without
// invoking enqueue.
func (c *Catalog) SubmitBackfillRun(ctx context.Context, repositoryID string, enqueue func(context.Context, pgx.Tx, BackfillRun) error) (BackfillRun, bool, error) {
	if c.pgxPool == nil {
		return BackfillRun{}, false, errors.New("Repository Backfill requires PostgreSQL")
	}
	if enqueue == nil {
		return BackfillRun{}, false, errors.New("Backfill enqueue callback is required")
	}
	var result BackfillRun
	created := false
	err := c.WithPostgresTx(ctx, func(_ *catalogent.Client, tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext($1))`, repositoryID); err != nil {
			return fmt.Errorf("lock Repository Backfill submission: %w", err)
		}
		var row backfillRunRow
		err := tx.QueryRow(ctx, `SELECT id, repository_id, status, started_at, completed_at,
			error_count, diagnostics, created_at, updated_at
			FROM repository_backfill_runs WHERE repository_id = $1 AND status IN ('queued', 'running')
			ORDER BY created_at DESC LIMIT 1`, repositoryID).Scan(
			&row.ID, &row.RepositoryID, &row.Status, &row.StartedAt, &row.CompletedAt,
			&row.ErrorCount, &row.Diagnostics, &row.CreatedAt, &row.UpdatedAt,
		)
		if err == nil {
			result, err = decodeBackfillRun(row)
			return err
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		result = newBackfillRun(repositoryID)
		encoded, err := json.Marshal(result.Diagnostics)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO repository_backfill_runs
			(id, repository_id, status, error_count, diagnostics, created_at, updated_at)
			VALUES ($1, $2, $3, 0, $4, $5, $6)`, result.ID, result.RepositoryID,
			result.Status, encoded, result.CreatedAt, result.UpdatedAt); err != nil {
			return err
		}
		if err := enqueue(ctx, tx, result); err != nil {
			return err
		}
		created = true
		return nil
	})
	return result, created, err
}

func (c *Catalog) LatestBackfillRun(ctx context.Context, repositoryID string) (BackfillRun, error) {
	var row backfillRunRow
	err := c.db.GetContext(ctx, &row, c.db.Rebind(`SELECT id, repository_id, status, started_at, completed_at,
		error_count, diagnostics, created_at, updated_at
		FROM repository_backfill_runs WHERE repository_id = ? ORDER BY created_at DESC LIMIT 1`), repositoryID)
	if err != nil {
		return BackfillRun{}, err
	}
	return decodeBackfillRun(row)
}

func (c *Catalog) StartBackfillRun(ctx context.Context, runID string) (BackfillRun, bool, error) {
	now := time.Now().UTC()
	result, err := c.db.ExecContext(ctx, c.db.Rebind(`UPDATE repository_backfill_runs
		SET status = ?, started_at = COALESCE(started_at, ?), updated_at = ?
		WHERE id = ? AND status = ?`), BackfillRunning, now, now, runID, BackfillQueued)
	if err != nil {
		return BackfillRun{}, false, err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return BackfillRun{}, false, err
	}
	run, err := c.backfillRunByID(ctx, runID)
	return run, changed > 0 || run.Status == BackfillRunning, err
}

func (c *Catalog) CompleteBackfillRun(ctx context.Context, runID string, errorCount int, diagnostics []string) error {
	status := BackfillComplete
	if errorCount > 0 {
		status = BackfillCompleteWithErrors
	}
	encoded, err := json.Marshal(diagnostics)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	result, err := c.db.ExecContext(ctx, c.db.Rebind(`UPDATE repository_backfill_runs
		SET status = ?, completed_at = ?, error_count = ?, diagnostics = ?, updated_at = ?
		WHERE id = ? AND status IN (?, ?)`), status, now, errorCount, encoded, now, runID, BackfillQueued, BackfillRunning)
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (c *Catalog) TouchBackfillRun(ctx context.Context, runID string) error {
	result, err := c.db.ExecContext(ctx, c.db.Rebind(`UPDATE repository_backfill_runs SET updated_at = ?
		WHERE id = ? AND status = ?`), time.Now().UTC(), runID, BackfillRunning)
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// ExpireStaleBackfillRuns recovers business Runs whose River execution could
// not persist its terminal failure. Active workers heartbeat updated_at before
// each bounded version operation, so only abandoned Runs cross the cutoff.
func (c *Catalog) ExpireStaleBackfillRuns(ctx context.Context, before time.Time) (int64, error) {
	diagnostics, err := json.Marshal([]string{"repository: execution_expired"})
	if err != nil {
		return 0, err
	}
	now := time.Now().UTC()
	result, err := c.db.ExecContext(ctx, c.db.Rebind(`UPDATE repository_backfill_runs
		SET status = ?, completed_at = ?, error_count = error_count + 1, diagnostics = ?, updated_at = ?
		WHERE status = ? AND updated_at < ?`), BackfillCompleteWithErrors, now, diagnostics, now,
		BackfillRunning, before.UTC())
	if err != nil {
		return 0, err
	}
	return result.RowsAffected()
}

func (c *Catalog) StaleQueuedBackfillRuns(ctx context.Context, before time.Time, limit int) ([]BackfillRun, error) {
	if limit <= 0 || limit > 1000 {
		limit = 100
	}
	rows := make([]backfillRunRow, 0)
	err := c.db.SelectContext(ctx, &rows, c.db.Rebind(`SELECT id, repository_id, status, started_at, completed_at,
		error_count, diagnostics, created_at, updated_at FROM repository_backfill_runs
		WHERE status = ? AND updated_at < ? ORDER BY updated_at ASC LIMIT ?`), BackfillQueued, before.UTC(), limit)
	if err != nil {
		return nil, err
	}
	runs := make([]BackfillRun, 0, len(rows))
	for _, row := range rows {
		run, err := decodeBackfillRun(row)
		if err != nil {
			return nil, err
		}
		runs = append(runs, run)
	}
	return runs, nil
}

func (c *Catalog) ExpireQueuedBackfillRun(ctx context.Context, runID string) error {
	diagnostics, err := json.Marshal([]string{"repository: execution_expired"})
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	result, err := c.db.ExecContext(ctx, c.db.Rebind(`UPDATE repository_backfill_runs
		SET status = ?, completed_at = ?, error_count = error_count + 1, diagnostics = ?, updated_at = ?
		WHERE id = ? AND status = ?`), BackfillCompleteWithErrors, now, diagnostics, now, runID, BackfillQueued)
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (c *Catalog) RepositoryPublicationExists(ctx context.Context, repositoryID, version string) (bool, error) {
	_, err := c.RepositoryPublicationCommit(ctx, repositoryID, version)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (c *Catalog) RepositoryPublicationCommit(ctx context.Context, repositoryID, version string) (string, error) {
	var commitSHA string
	err := c.db.GetContext(ctx, &commitSHA, c.db.Rebind(`SELECT rp.commit_sha
		FROM repository_publications rp JOIN repositories r ON r.id = rp.repository_id
		WHERE r.repository_id = ? AND rp.version = ?`), repositoryID, version)
	return commitSHA, err
}

func (c *Catalog) backfillRunByID(ctx context.Context, runID string) (BackfillRun, error) {
	var row backfillRunRow
	err := c.db.GetContext(ctx, &row, c.db.Rebind(`SELECT id, repository_id, status, started_at, completed_at,
		error_count, diagnostics, created_at, updated_at FROM repository_backfill_runs WHERE id = ?`), runID)
	if err != nil {
		return BackfillRun{}, err
	}
	return decodeBackfillRun(row)
}

func decodeBackfillRun(row backfillRunRow) (BackfillRun, error) {
	diagnostics := make([]string, 0)
	if len(row.Diagnostics) > 0 {
		if err := json.Unmarshal(row.Diagnostics, &diagnostics); err != nil {
			return BackfillRun{}, fmt.Errorf("decode Backfill diagnostics: %w", err)
		}
	}
	return BackfillRun{ID: row.ID, RepositoryID: row.RepositoryID, Status: row.Status,
		StartedAt: row.StartedAt, CompletedAt: row.CompletedAt, ErrorCount: row.ErrorCount,
		Diagnostics: diagnostics, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}, nil
}

func newBackfillRun(repositoryID string) BackfillRun {
	now := time.Now().UTC()
	return BackfillRun{ID: uuid.NewString(), RepositoryID: repositoryID, Status: BackfillQueued,
		Diagnostics: []string{}, CreatedAt: now, UpdatedAt: now}
}
