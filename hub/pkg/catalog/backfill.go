/*
 * [INPUT]: Depends on Catalog SQL/pgx persistence, UUID run identities, and caller-supplied transactional River enqueueing.
 * [OUTPUT]: Provides durable Backfill Run creation, active-run deduplication, state transitions, diagnostics, status reads, and exact Repository Publication checks.
 * [POS]: Serves as the Catalog business-state boundary for Repository History Backfill independently of River transport tables.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/catalogsqlc"
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

// SubmitBackfillRun atomically creates a queued run and invokes enqueue with
// the same PostgreSQL transaction. An existing active run is returned without
// invoking enqueue.
func (c *Catalog) SubmitBackfillRun(ctx context.Context, repositoryID string, enqueue func(context.Context, pgx.Tx, BackfillRun) error) (BackfillRun, bool, error) {
	if enqueue == nil {
		return BackfillRun{}, false, errors.New("Backfill enqueue callback is required")
	}
	var result BackfillRun
	created := false
	err := c.WithPostgresTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext($1))`, repositoryID); err != nil {
			return fmt.Errorf("lock Repository Backfill submission: %w", err)
		}
		q := c.queries.WithTx(tx)
		row, err := q.ActiveBackfillRun(ctx, repositoryID)
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
		if err := q.InsertBackfillRun(ctx, catalogsqlc.InsertBackfillRunParams{ID: result.ID, RepositoryID: result.RepositoryID, Status: string(result.Status), Diagnostics: encoded, CreatedAt: result.CreatedAt}); err != nil {
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
	row, err := c.queries.LatestBackfillRun(ctx, repositoryID)
	if err != nil {
		return BackfillRun{}, err
	}
	return decodeBackfillRun(row)
}

func (c *Catalog) StartBackfillRun(ctx context.Context, runID string) (BackfillRun, bool, error) {
	now := time.Now().UTC()
	changed, err := c.queries.StartBackfillRun(ctx, catalogsqlc.StartBackfillRunParams{ID: runID, Now: now})
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
	changed, err := c.queries.CompleteBackfillRun(ctx, catalogsqlc.CompleteBackfillRunParams{ID: runID, Status: string(status), CompletedAt: &now, ErrorCount: int32(errorCount), Diagnostics: encoded})
	if err != nil {
		return err
	}
	if changed == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (c *Catalog) TouchBackfillRun(ctx context.Context, runID string) error {
	changed, err := c.queries.TouchBackfillRun(ctx, catalogsqlc.TouchBackfillRunParams{ID: runID, UpdatedAt: time.Now().UTC()})
	if err != nil {
		return err
	}
	if changed == 0 {
		return pgx.ErrNoRows
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
	return c.queries.ExpireStaleBackfillRuns(ctx, catalogsqlc.ExpireStaleBackfillRunsParams{UpdatedAt: before.UTC(), CompletedAt: &now, Diagnostics: diagnostics})
}

func (c *Catalog) StaleQueuedBackfillRuns(ctx context.Context, before time.Time, limit int) ([]BackfillRun, error) {
	if limit <= 0 || limit > 1000 {
		limit = 100
	}
	rows, err := c.queries.StaleQueuedBackfillRuns(ctx, catalogsqlc.StaleQueuedBackfillRunsParams{UpdatedAt: before.UTC(), Limit: int32(limit)})
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
	changed, err := c.queries.ExpireQueuedBackfillRun(ctx, catalogsqlc.ExpireQueuedBackfillRunParams{ID: runID, CompletedAt: &now, Diagnostics: diagnostics})
	if err != nil {
		return err
	}
	if changed == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (c *Catalog) RepositoryPublicationExists(ctx context.Context, repositoryID, version string) (bool, error) {
	_, err := c.RepositoryPublicationCommit(ctx, repositoryID, version)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (c *Catalog) RepositoryPublicationCommit(ctx context.Context, repositoryID, version string) (string, error) {
	return c.queries.RepositoryPublicationCommit(ctx, catalogsqlc.RepositoryPublicationCommitParams{RepositoryID: repositoryID, Version: version})
}

func (c *Catalog) backfillRunByID(ctx context.Context, runID string) (BackfillRun, error) {
	row, err := c.queries.BackfillRunByID(ctx, runID)
	if err != nil {
		return BackfillRun{}, err
	}
	return decodeBackfillRun(row)
}

func decodeBackfillRun(row catalogsqlc.RepositoryBackfillRun) (BackfillRun, error) {
	diagnostics := make([]string, 0)
	if len(row.Diagnostics) > 0 {
		if err := json.Unmarshal(row.Diagnostics, &diagnostics); err != nil {
			return BackfillRun{}, fmt.Errorf("decode Backfill diagnostics: %w", err)
		}
	}
	return BackfillRun{ID: row.ID, RepositoryID: row.RepositoryID, Status: BackfillStatus(row.Status),
		StartedAt: utcTimePointer(row.StartedAt), CompletedAt: utcTimePointer(row.CompletedAt), ErrorCount: int(row.ErrorCount),
		Diagnostics: diagnostics, CreatedAt: row.CreatedAt.UTC(), UpdatedAt: row.UpdatedAt.UTC()}, nil
}

func newBackfillRun(repositoryID string) BackfillRun {
	now := time.Now().UTC()
	return BackfillRun{ID: uuid.NewString(), RepositoryID: repositoryID, Status: BackfillQueued,
		Diagnostics: []string{}, CreatedAt: now, UpdatedAt: now}
}
