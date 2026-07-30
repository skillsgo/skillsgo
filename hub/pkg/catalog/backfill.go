/*
 * [INPUT]: Depends on Catalog SQL/pgx persistence, UUID run identities, and caller-supplied transactional River enqueueing.
 * [OUTPUT]: Provides durable Backfill Run creation, active-run deduplication, explicit aggregate states, per-Version outcomes, retry progress, status reads, and exact Package Publication checks.
 * [POS]: Serves as the Catalog business-state boundary for Package History Backfill independently of River transport tables.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/catalogsqlc"
)

type BackfillStatus string

const (
	BackfillQueued                 BackfillStatus = "queued"
	BackfillRunning                BackfillStatus = "running"
	BackfillComplete               BackfillStatus = "complete"
	BackfillCompleteWithRejections BackfillStatus = "complete_with_rejections"
	BackfillFailed                 BackfillStatus = "failed"
)

type BackfillVersionOutcomeKind string

const (
	BackfillOutcomePublished        BackfillVersionOutcomeKind = "published"
	BackfillOutcomeAlreadyPublished BackfillVersionOutcomeKind = "already_published"
	BackfillOutcomeSkipped          BackfillVersionOutcomeKind = "skipped"
	BackfillOutcomeRejected         BackfillVersionOutcomeKind = "rejected"
	BackfillOutcomeRetryableFailure BackfillVersionOutcomeKind = "retryable_failure"
)

type BackfillVersionOutcome struct {
	RunID        string                     `json:"runId"`
	Version      string                     `json:"version"`
	CommitSHA    string                     `json:"commitSha"`
	Outcome      BackfillVersionOutcomeKind `json:"outcome"`
	ReasonCode   string                     `json:"reasonCode,omitempty"`
	AttemptCount int                        `json:"attemptCount"`
	CreatedAt    time.Time                  `json:"createdAt"`
	UpdatedAt    time.Time                  `json:"updatedAt"`
}

// BackfillRun is durable administrator-facing business state aggregated from
// explicit per-Version outcomes. FailureCode is reserved for Run-wide terminal state.
type BackfillRun struct {
	ID             string                   `json:"runId"`
	PackagePath    string                   `json:"moduleId"`
	Status         BackfillStatus           `json:"status"`
	StartedAt      *time.Time               `json:"startedAt,omitempty"`
	CompletedAt    *time.Time               `json:"completedAt,omitempty"`
	PublishedCount int                      `json:"publishedCount"`
	SkippedCount   int                      `json:"skippedCount"`
	RejectedCount  int                      `json:"rejectedCount"`
	FailedCount    int                      `json:"failedCount"`
	FailureCode    string                   `json:"failureCode,omitempty"`
	Outcomes       []BackfillVersionOutcome `json:"outcomes,omitempty"`
	CreatedAt      time.Time                `json:"createdAt"`
	UpdatedAt      time.Time                `json:"updatedAt"`
}

// SubmitBackfillRun atomically creates a queued run and invokes enqueue with
// the same PostgreSQL transaction. An existing active run is returned without
// invoking enqueue.
func (c *Catalog) SubmitBackfillRun(ctx context.Context, packagePath string, enqueue func(context.Context, pgx.Tx, BackfillRun) error) (BackfillRun, bool, error) {
	if enqueue == nil {
		return BackfillRun{}, false, errors.New("Backfill enqueue callback is required")
	}
	var result BackfillRun
	created := false
	err := c.WithPostgresTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext($1))`, packagePath); err != nil {
			return fmt.Errorf("lock Package Backfill submission: %w", err)
		}
		q := c.queries.WithTx(tx)
		row, err := q.ActiveBackfillRun(ctx, packagePath)
		if err == nil {
			result, err = decodeBackfillRun(row)
			return err
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		result = newBackfillRun(packagePath)
		if err := q.InsertBackfillRun(ctx, catalogsqlc.InsertBackfillRunParams{ID: result.ID, PackagePath: result.PackagePath, Status: string(result.Status), CreatedAt: result.CreatedAt}); err != nil {
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

func (c *Catalog) LatestBackfillRun(ctx context.Context, packagePath string) (BackfillRun, error) {
	row, err := c.queries.LatestBackfillRun(ctx, packagePath)
	if err != nil {
		return BackfillRun{}, err
	}
	run, err := decodeBackfillRun(row)
	if err != nil {
		return BackfillRun{}, err
	}
	run.Outcomes, err = c.BackfillVersionOutcomes(ctx, run.ID)
	return run, err
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

func (c *Catalog) CompleteBackfillRun(ctx context.Context, runID string) error {
	now := time.Now().UTC()
	changed, err := c.queries.CompleteBackfillRun(ctx, catalogsqlc.CompleteBackfillRunParams{ID: runID, CompletedAt: &now})
	if err != nil {
		return err
	}
	if changed == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (c *Catalog) RecordBackfillVersionOutcome(ctx context.Context, outcome BackfillVersionOutcome) error {
	now := time.Now().UTC()
	return c.WithPostgresTx(ctx, func(tx pgx.Tx) error {
		q := c.queries.WithTx(tx)
		if _, err := q.LockRunningBackfillRun(ctx, outcome.RunID); err != nil {
			return err
		}
		if err := q.UpsertBackfillVersionOutcome(ctx, catalogsqlc.UpsertBackfillVersionOutcomeParams{
			RunID: outcome.RunID, Version: outcome.Version, CommitSha: outcome.CommitSHA, Outcome: string(outcome.Outcome),
			ReasonCode: nullableText(outcome.ReasonCode), CreatedAt: now,
		}); err != nil {
			return err
		}
		changed, err := q.RefreshBackfillRunCounts(ctx, catalogsqlc.RefreshBackfillRunCountsParams{RunID: outcome.RunID, UpdatedAt: now})
		if err != nil {
			return err
		}
		if changed == 0 {
			return pgx.ErrNoRows
		}
		return nil
	})
}

func (c *Catalog) BackfillVersionOutcomes(ctx context.Context, runID string) ([]BackfillVersionOutcome, error) {
	rows, err := c.queries.BackfillVersionOutcomes(ctx, runID)
	if err != nil {
		return nil, err
	}
	result := make([]BackfillVersionOutcome, 0, len(rows))
	for _, row := range rows {
		result = append(result, BackfillVersionOutcome{RunID: row.RunID, Version: row.Version, CommitSHA: row.CommitSha,
			Outcome: BackfillVersionOutcomeKind(row.Outcome), ReasonCode: textValue(row.ReasonCode), AttemptCount: int(row.AttemptCount),
			CreatedAt: row.CreatedAt.UTC(), UpdatedAt: row.UpdatedAt.UTC()})
	}
	return result, nil
}

func (c *Catalog) FailBackfillRun(ctx context.Context, runID, failureCode string) error {
	return c.finishBackfillRun(ctx, runID, failureCode, false)
}

func (c *Catalog) RejectBackfillRun(ctx context.Context, runID, failureCode string) error {
	return c.finishBackfillRun(ctx, runID, failureCode, true)
}

func (c *Catalog) finishBackfillRun(ctx context.Context, runID, failureCode string, rejected bool) error {
	if failureCode == "" {
		return errors.New("Backfill terminal failure code is required")
	}
	now := time.Now().UTC()
	var changed int64
	var err error
	if rejected {
		changed, err = c.queries.RejectBackfillRun(ctx, catalogsqlc.RejectBackfillRunParams{ID: runID, CompletedAt: &now, FailureCode: nullableText(failureCode)})
	} else {
		changed, err = c.queries.FailBackfillRun(ctx, catalogsqlc.FailBackfillRunParams{ID: runID, CompletedAt: &now, FailureCode: nullableText(failureCode)})
	}
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
	now := time.Now().UTC()
	return c.queries.ExpireStaleBackfillRuns(ctx, catalogsqlc.ExpireStaleBackfillRunsParams{UpdatedAt: before.UTC(), CompletedAt: &now})
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
	now := time.Now().UTC()
	changed, err := c.queries.ExpireQueuedBackfillRun(ctx, catalogsqlc.ExpireQueuedBackfillRunParams{ID: runID, CompletedAt: &now})
	if err != nil {
		return err
	}
	if changed == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (c *Catalog) PackagePublicationExists(ctx context.Context, packagePath, version string) (bool, error) {
	_, err := c.PackagePublicationCommit(ctx, packagePath, version)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (c *Catalog) PackagePublicationCommit(ctx context.Context, packagePath, version string) (string, error) {
	return c.queries.PackagePublicationCommit(ctx, catalogsqlc.PackagePublicationCommitParams{PackagePath: packagePath, Version: version})
}

func (c *Catalog) backfillRunByID(ctx context.Context, runID string) (BackfillRun, error) {
	row, err := c.queries.BackfillRunByID(ctx, runID)
	if err != nil {
		return BackfillRun{}, err
	}
	return decodeBackfillRun(row)
}

func decodeBackfillRun(row catalogsqlc.PackageBackfillRun) (BackfillRun, error) {
	return BackfillRun{ID: row.ID, PackagePath: row.PackagePath, Status: BackfillStatus(row.Status),
		StartedAt: utcTimePointer(row.StartedAt), CompletedAt: utcTimePointer(row.CompletedAt),
		PublishedCount: int(row.PublishedCount), SkippedCount: int(row.SkippedCount), RejectedCount: int(row.RejectedCount), FailedCount: int(row.FailedCount),
		FailureCode: textValue(row.FailureCode), Outcomes: []BackfillVersionOutcome{}, CreatedAt: row.CreatedAt.UTC(), UpdatedAt: row.UpdatedAt.UTC()}, nil
}

func newBackfillRun(packagePath string) BackfillRun {
	now := time.Now().UTC()
	return BackfillRun{ID: uuid.NewString(), PackagePath: packagePath, Status: BackfillQueued,
		Outcomes: []BackfillVersionOutcome{}, CreatedAt: now, UpdatedAt: now}
}

func nullableText(value string) pgtype.Text { return pgtype.Text{String: value, Valid: value != ""} }
func textValue(value pgtype.Text) string {
	if value.Valid {
		return value.String
	}
	return ""
}
