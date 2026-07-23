-- [INPUT]: Depends on PostgreSQL with pg_trgm and the pre-release Repository Artifact domain model.
-- [OUTPUT]: Provides the complete Hub Catalog baseline with Repository-owned Releases, immutable member snapshots, discovery projections, localization, and Backfill Runs.
-- [POS]: Serves as the single clean pre-release PostgreSQL schema; no Skill-owned version or audit tables exist.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE TABLE repositories (
  id BIGSERIAL PRIMARY KEY,
  source_host TEXT NOT NULL,
  repository_path TEXT NOT NULL,
  repository_id TEXT NOT NULL UNIQUE,
  current_release_id BIGINT,
  description TEXT NOT NULL DEFAULT '',
  stars BIGINT NOT NULL DEFAULT 0,
  source_metadata_etag TEXT,
  source_metadata_checked_at TIMESTAMPTZ,
  source_metadata_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_host, repository_path)
);
CREATE TABLE repository_releases (
  id BIGSERIAL PRIMARY KEY,
  repository_id BIGINT NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  sum TEXT NOT NULL,
  archive_size BIGINT NOT NULL CHECK (archive_size > 0),
  release_info BYTEA NOT NULL,
  commit_time TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(repository_id, version)
);
ALTER TABLE repositories ADD CONSTRAINT repositories_current_release
  FOREIGN KEY (current_release_id) REFERENCES repository_releases(id);
CREATE TABLE skills (
  id BIGSERIAL PRIMARY KEY,
  repository_id BIGINT NOT NULL REFERENCES repositories(id),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  source_host TEXT NOT NULL DEFAULT '',
  repository TEXT NOT NULL DEFAULT '',
  skill_path TEXT NOT NULL DEFAULT '',
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(repository_id, name)
);
CREATE INDEX skills_repository_id ON skills(repository_id);
CREATE INDEX skills_search_trgm ON skills USING gin ((name || ' ' || description) gin_trgm_ops);
CREATE TABLE repository_release_members (
  id BIGSERIAL PRIMARY KEY,
  release_id BIGINT NOT NULL REFERENCES repository_releases(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  skill_path TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  UNIQUE(release_id, name)
);
CREATE TABLE localized_descriptions (
  id BIGSERIAL PRIMARY KEY,
  resource_kind TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  locale TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  source_digest TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(resource_kind, resource_id, locale)
);
CREATE TABLE repository_backfill_runs (
  id TEXT PRIMARY KEY,
  repository_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'complete_with_errors')),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_count INTEGER NOT NULL DEFAULT 0,
  diagnostics JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX repository_backfill_runs_one_active ON repository_backfill_runs(repository_id)
  WHERE status IN ('queued', 'running');
CREATE INDEX repository_backfill_runs_repository_created ON repository_backfill_runs(repository_id, created_at DESC);
