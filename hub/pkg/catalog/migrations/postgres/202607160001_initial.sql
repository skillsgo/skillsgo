-- [INPUT]: Depends on PostgreSQL with permission to enable pg_trgm.
-- [OUTPUT]: Provides the initial Catalog relational schema and trigram search index.
-- [POS]: Serves as the first reviewed PostgreSQL schema migration for the Hub Catalog.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE TABLE skills (
  id BIGSERIAL PRIMARY KEY,
  coordinate TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  source_host TEXT NOT NULL,
  repository TEXT NOT NULL,
  skill_path TEXT NOT NULL,
  latest_version TEXT NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE skill_versions (
  id BIGSERIAL PRIMARY KEY,
  skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(skill_id, version)
);
CREATE TABLE risk_assessments (
  id BIGSERIAL PRIMARY KEY,
  skill_version_id BIGINT NOT NULL REFERENCES skill_versions(id) ON DELETE CASCADE,
  level TEXT NOT NULL,
  scanner_version TEXT NOT NULL,
  evidence JSONB NOT NULL,
  fingerprint TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE install_events (
  event_id TEXT PRIMARY KEY,
  skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  agents JSONB NOT NULL,
  scope TEXT NOT NULL,
  cli_version TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE skill_stats (
  skill_id BIGINT PRIMARY KEY REFERENCES skills(id) ON DELETE CASCADE,
  total_installs BIGINT NOT NULL DEFAULT 0
);
CREATE TABLE skill_hourly_stats (
  id BIGSERIAL PRIMARY KEY,
  skill_id BIGINT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  bucket TIMESTAMPTZ NOT NULL,
  installs BIGINT NOT NULL DEFAULT 0,
  UNIQUE(skill_id, bucket)
);
CREATE INDEX skills_search_trgm ON skills USING gin ((name || ' ' || description || ' ' || coordinate) gin_trgm_ops);
