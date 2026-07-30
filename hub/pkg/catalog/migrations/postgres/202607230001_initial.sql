-- [INPUT]: Depends on PostgreSQL with pg_trgm and the pre-launch Package distribution model.
-- [OUTPUT]: Provides the Hub Catalog baseline with Packages, content-addressed effective and equivalent observed Versions, effective-version-owned Skills, localization, and Package Backfill Runs.
-- [POS]: Serves as the single clean pre-launch PostgreSQL schema; Source Repository metadata belongs to Packages and no compatibility tables exist.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE packages (
  id BIGSERIAL PRIMARY KEY,
  source_host TEXT NOT NULL,
  source_path TEXT NOT NULL,
  path TEXT NOT NULL UNIQUE,
  current_version_id BIGINT,
  description TEXT NOT NULL DEFAULT '',
  description_digest TEXT NOT NULL DEFAULT '',
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
  package_id BIGINT NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  ref TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  content_sum TEXT NOT NULL,
  equivalent_version TEXT,
  sum TEXT,
  commit_time TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(package_id, version),
  UNIQUE(package_id, id),
  FOREIGN KEY (package_id, equivalent_version) REFERENCES versions(package_id, version),
  CONSTRAINT versions_artifact_ownership CHECK (
    (equivalent_version IS NULL AND sum IS NOT NULL)
    OR (equivalent_version IS NOT NULL AND sum IS NULL)
  ),
  CONSTRAINT versions_not_self_equivalent CHECK (equivalent_version IS NULL OR equivalent_version <> version)
);

ALTER TABLE packages ADD CONSTRAINT packages_current_version
  FOREIGN KEY (id, current_version_id) REFERENCES versions(package_id, id);

CREATE TABLE skills (
  id BIGSERIAL PRIMARY KEY,
  version_id BIGINT NOT NULL REFERENCES versions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  path TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  description_digest TEXT NOT NULL,
  document_digest TEXT NOT NULL,
  source_language TEXT NOT NULL DEFAULT '',
  UNIQUE(version_id, path)
);

COMMENT ON TABLE packages IS 'Canonical Skill Packages and mutable source/discovery state.';
COMMENT ON COLUMN packages.source_host IS 'Source host derived from Package Path, for example github.com.';
COMMENT ON COLUMN packages.source_path IS 'Host-relative source path derived from Package Path, for example acme/skills.';
COMMENT ON COLUMN packages.path IS 'Canonical globally unique Package Path.';
COMMENT ON COLUMN packages.current_version_id IS 'Current discovery-visible Version; constrained to belong to this Package.';
COMMENT ON COLUMN packages.description IS 'Mutable source description used by discovery.';
COMMENT ON COLUMN packages.stars IS 'Mutable source popularity count used by discovery.';
COMMENT ON COLUMN packages.source_etag IS 'Conditional-request token for source enrichment.';
COMMENT ON COLUMN packages.source_checked_at IS 'Last successful source enrichment check.';
COMMENT ON COLUMN packages.source_retry_at IS 'Earliest source enrichment retry after upstream throttling.';

COMMENT ON TABLE versions IS 'Immutable published versions owned by Packages.';
COMMENT ON COLUMN versions.version IS 'Canonical immutable Package Version.';
COMMENT ON COLUMN versions.ref IS 'Source ref resolved when the Version was published.';
COMMENT ON COLUMN versions.commit_sha IS 'Source commit captured by this Version.';
COMMENT ON COLUMN versions.tree_sha IS 'Package root tree captured by this Version.';
COMMENT ON COLUMN versions.content_sum IS 'Version-independent h1 checksum of the normalized Package Artifact tree.';
COMMENT ON COLUMN versions.equivalent_version IS 'Direct effective Version whose Package content is identical; NULL when this Version owns an Artifact.';
COMMENT ON COLUMN versions.sum IS 'Canonical coordinate-bound h1 checksum of the normalized Package Artifact tree.';
COMMENT ON COLUMN versions.commit_time IS 'Source commit time exposed as Package Info time.';

COMMENT ON TABLE skills IS 'Skill members contained by one immutable Package Version.';
COMMENT ON COLUMN skills.name IS 'Canonical Skill name read from SKILL.md.';
COMMENT ON COLUMN skills.path IS 'Package-relative directory containing SKILL.md; unique within the Version.';
COMMENT ON COLUMN skills.description IS 'Searchable Skill description read from SKILL.md.';
COMMENT ON COLUMN skills.source_language IS 'Detected BCP 47 source language for the immutable SKILL.md document; empty when undetermined or mixed.';

CREATE INDEX skills_version_id ON skills(version_id);
CREATE INDEX versions_package_content_sum ON versions(package_id, content_sum);
CREATE INDEX skills_name_lower ON skills(lower(name));
CREATE INDEX skills_search_trgm ON skills USING gin ((name || ' ' || description) gin_trgm_ops);

CREATE TABLE localizations (
  resource_kind TEXT NOT NULL CHECK (resource_kind IN ('package_description','skill_description','skill_document')),
  source_digest TEXT NOT NULL,
  lang TEXT NOT NULL,
  result_kind TEXT NOT NULL CHECK (result_kind IN ('translated','source','failed')),
  text_content TEXT,
  error_kind TEXT,
  error_message TEXT,
  prompt_version TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(resource_kind, source_digest, lang),
  CONSTRAINT localizations_content_check CHECK (
    (result_kind='source' AND text_content IS NULL AND error_kind IS NULL AND error_message IS NULL)
    OR
    (result_kind='translated' AND resource_kind IN ('package_description','skill_description') AND text_content IS NOT NULL AND error_kind IS NULL AND error_message IS NULL)
    OR
    (result_kind='translated' AND resource_kind='skill_document' AND text_content IS NULL AND error_kind IS NULL AND error_message IS NULL)
    OR
    (result_kind='failed' AND text_content IS NULL AND error_kind IS NOT NULL AND error_message IS NOT NULL)
  )
);

CREATE TABLE package_backfill_runs (
  id TEXT PRIMARY KEY,
  package_path TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'complete_with_errors')),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_count INTEGER NOT NULL DEFAULT 0,
  diagnostics JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX package_backfill_runs_one_active ON package_backfill_runs(package_path)
  WHERE status IN ('queued', 'running');
CREATE INDEX package_backfill_runs_module_created ON package_backfill_runs(package_path, created_at DESC);
