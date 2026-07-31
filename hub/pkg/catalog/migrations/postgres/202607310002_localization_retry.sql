ALTER TABLE localizations
  ADD COLUMN failure_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN retry_at TIMESTAMPTZ,
  ADD COLUMN failure_terminal BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE localizations
SET failure_count = 1,
    failure_terminal = TRUE
WHERE result_kind = 'failed';

ALTER TABLE localizations
  ADD CONSTRAINT localizations_failure_lifecycle_check CHECK (
    (result_kind = 'failed' AND failure_count > 0 AND (failure_terminal OR retry_at IS NOT NULL))
    OR
    (result_kind <> 'failed' AND failure_count = 0 AND retry_at IS NULL AND NOT failure_terminal)
  );

CREATE INDEX localizations_retry_due
  ON localizations (retry_at)
  WHERE result_kind = 'failed' AND NOT failure_terminal;
