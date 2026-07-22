-- [INPUT]: Depends on the Catalog baseline and Historical Publication visibility migration.
-- [OUTPUT]: Adds durable Repository Backfill Run business state and active-work deduplication.
-- [POS]: Serves as the SQLite schema evolution for administrator-triggered Repository history work.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TABLE repository_backfill_runs (
    id TEXT PRIMARY KEY,
    repository_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'complete_with_errors')),
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    error_count INTEGER NOT NULL DEFAULT 0,
    diagnostics TEXT NOT NULL DEFAULT '[]',
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX repository_backfill_runs_one_active
    ON repository_backfill_runs(repository_id)
    WHERE status IN ('queued', 'running');

CREATE INDEX repository_backfill_runs_repository_created
    ON repository_backfill_runs(repository_id, created_at DESC);
