-- [INPUT]: Depends on PostgreSQL with permission to enable pg_trgm.
-- [OUTPUT]: Provides the complete initial Catalog schema and trigram search indexes.
-- [POS]: Serves as the single pre-release PostgreSQL baseline migration for the Hub Catalog.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE TABLE repositories (
  id BIGSERIAL PRIMARY KEY,
  source_host TEXT NOT NULL,
  repository_path TEXT NOT NULL,
  repository_id TEXT NOT NULL UNIQUE,
  stars BIGINT NOT NULL DEFAULT 0,
  source_metadata_etag TEXT,
  source_metadata_checked_at TIMESTAMPTZ,
  source_metadata_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_host, repository_path)
);
CREATE TABLE skills (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  source_host TEXT NOT NULL,
  repository TEXT NOT NULL,
  repository_id BIGINT NOT NULL REFERENCES repositories(id),
  skill_path TEXT NOT NULL,
  latest_version TEXT NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(repository_id, name)
);
CREATE INDEX skills_repository_id ON skills(repository_id);
CREATE INDEX skills_search_trgm ON skills USING gin ((name || ' ' || description) gin_trgm_ops);
CREATE TABLE skill_versions (
  id BIGSERIAL PRIMARY KEY,
  skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  relative_path TEXT NOT NULL,
  commit_time TIMESTAMPTZ NOT NULL DEFAULT '0001-01-01 00:00:00+00:00',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(skill_id, version)
);
CREATE TABLE skill_risk_assessments (
  id BIGSERIAL PRIMARY KEY,
  skill_version_id BIGINT NOT NULL REFERENCES skill_versions(id) ON DELETE CASCADE,
  level TEXT NOT NULL,
  scanner_version TEXT NOT NULL,
  evidence JSONB NOT NULL,
  fingerprint TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
