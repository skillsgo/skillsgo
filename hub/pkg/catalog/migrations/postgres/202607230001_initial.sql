-- [INPUT]: Depends on PostgreSQL with pg_trgm and the pre-launch Module distribution model.
-- [OUTPUT]: Provides the Hub Catalog baseline with Modules, immutable Versions, version-owned Skills, localization, and Module Backfill Runs.
-- [POS]: Serves as the single clean pre-launch PostgreSQL schema; Source Repository metadata belongs to Modules and no compatibility tables exist.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE modules (
  id BIGSERIAL PRIMARY KEY,
  source_host TEXT NOT NULL,
  source_path TEXT NOT NULL,
  path TEXT NOT NULL UNIQUE,
  current_version_id BIGINT,
  description TEXT NOT NULL DEFAULT '',
  stars BIGINT NOT NULL DEFAULT 0,
  source_etag TEXT,
  source_checked_at TIMESTAMPTZ,
  source_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_host, source_path)
);

CREATE TABLE versions (
  id BIGSERIAL PRIMARY KEY,
  module_id BIGINT NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  ref TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  sum TEXT NOT NULL,
  archive_size BIGINT NOT NULL CHECK (archive_size > 0),
  commit_time TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(module_id, version),
  UNIQUE(module_id, id)
);

ALTER TABLE modules ADD CONSTRAINT modules_current_version
  FOREIGN KEY (id, current_version_id) REFERENCES versions(module_id, id);

CREATE TABLE skills (
  id BIGSERIAL PRIMARY KEY,
  version_id BIGINT NOT NULL REFERENCES versions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  path TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  UNIQUE(version_id, path)
);

COMMENT ON TABLE modules IS 'Canonical Skill Modules and mutable source/discovery state.';
COMMENT ON COLUMN modules.source_host IS 'Source host derived from Module Path, for example github.com.';
COMMENT ON COLUMN modules.source_path IS 'Host-relative source path derived from Module Path, for example acme/skills.';
COMMENT ON COLUMN modules.path IS 'Canonical globally unique Module Path.';
COMMENT ON COLUMN modules.current_version_id IS 'Current discovery-visible Version; constrained to belong to this Module.';
COMMENT ON COLUMN modules.description IS 'Mutable source description used by discovery.';
COMMENT ON COLUMN modules.stars IS 'Mutable source popularity count used by discovery.';
COMMENT ON COLUMN modules.source_etag IS 'Conditional-request token for source enrichment.';
COMMENT ON COLUMN modules.source_checked_at IS 'Last successful source enrichment check.';
COMMENT ON COLUMN modules.source_retry_at IS 'Earliest source enrichment retry after upstream throttling.';

COMMENT ON TABLE versions IS 'Immutable published versions owned by Modules.';
COMMENT ON COLUMN versions.version IS 'Canonical immutable Module Version.';
COMMENT ON COLUMN versions.ref IS 'Source ref resolved when the Version was published.';
COMMENT ON COLUMN versions.commit_sha IS 'Source commit captured by this Version.';
COMMENT ON COLUMN versions.tree_sha IS 'Module root tree captured by this Version.';
COMMENT ON COLUMN versions.sum IS 'Canonical h1 checksum of the Module ZIP.';
COMMENT ON COLUMN versions.archive_size IS 'Exact Module ZIP size in bytes.';
COMMENT ON COLUMN versions.commit_time IS 'Source commit time exposed as Module Info time.';

COMMENT ON TABLE skills IS 'Skill members contained by one immutable Module Version.';
COMMENT ON COLUMN skills.name IS 'Canonical Skill name read from SKILL.md.';
COMMENT ON COLUMN skills.path IS 'Module-relative directory containing SKILL.md; unique within the Version.';
COMMENT ON COLUMN skills.description IS 'Searchable Skill description read from SKILL.md.';

CREATE INDEX skills_version_id ON skills(version_id);
CREATE INDEX skills_name_lower ON skills(lower(name));
CREATE INDEX skills_search_trgm ON skills USING gin ((name || ' ' || description) gin_trgm_ops);

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

CREATE TABLE module_backfill_runs (
  id TEXT PRIMARY KEY,
  module_path TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'complete_with_errors')),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_count INTEGER NOT NULL DEFAULT 0,
  diagnostics JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX module_backfill_runs_one_active ON module_backfill_runs(module_path)
  WHERE status IN ('queued', 'running');
CREATE INDEX module_backfill_runs_module_created ON module_backfill_runs(module_path, created_at DESC);
