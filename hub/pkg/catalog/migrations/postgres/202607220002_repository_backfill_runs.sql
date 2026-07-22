-- [INPUT]: Depends on the Catalog baseline and Historical Publication visibility migration.
-- [OUTPUT]: Adds durable Repository Backfill Run business state and active-work deduplication.
-- [POS]: Serves as the PostgreSQL schema evolution for River-backed Repository history work.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TABLE repository_backfill_runs (
    id TEXT PRIMARY KEY,
    repository_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'complete_with_errors')),
    started_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    error_count INTEGER NOT NULL DEFAULT 0,
    diagnostics JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX repository_backfill_runs_one_active
    ON repository_backfill_runs(repository_id)
    WHERE status IN ('queued', 'running');

CREATE INDEX repository_backfill_runs_repository_created
    ON repository_backfill_runs(repository_id, created_at DESC);
