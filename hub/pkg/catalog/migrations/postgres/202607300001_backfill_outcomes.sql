-- Replace ambiguous Backfill errors with explicit Run aggregates and per-Version outcomes.
ALTER TABLE package_backfill_runs DROP CONSTRAINT package_backfill_runs_status_check;
ALTER TABLE package_backfill_runs
  ADD COLUMN published_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN skipped_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN rejected_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN failed_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN failure_code TEXT;

UPDATE package_backfill_runs
SET status = 'failed',
    failed_count = GREATEST(error_count, 1),
    failure_code = 'legacy_unspecified'
WHERE status = 'complete_with_errors';

ALTER TABLE package_backfill_runs
  ADD CONSTRAINT package_backfill_runs_status_check
  CHECK (status IN ('queued', 'running', 'complete', 'complete_with_rejections', 'failed')),
  ADD CONSTRAINT package_backfill_runs_failure_code_check CHECK (
    (status = 'failed' AND failure_code IS NOT NULL)
    OR (status <> 'failed')
  );

CREATE TABLE package_backfill_version_outcomes (
  run_id TEXT NOT NULL REFERENCES package_backfill_runs(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('published', 'already_published', 'skipped', 'rejected', 'retryable_failure')),
  reason_code TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 1 CHECK (attempt_count > 0),
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (run_id, version),
  CONSTRAINT package_backfill_version_outcomes_reason_check CHECK (
    (outcome IN ('published', 'already_published') AND reason_code IS NULL)
    OR
    (outcome IN ('skipped', 'rejected', 'retryable_failure') AND reason_code IS NOT NULL)
  )
);

CREATE INDEX package_backfill_version_outcomes_run_outcome
  ON package_backfill_version_outcomes(run_id, outcome);

ALTER TABLE package_backfill_runs DROP COLUMN error_count, DROP COLUMN diagnostics;
