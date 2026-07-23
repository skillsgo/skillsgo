-- atlas:delimiter \nGO
-- [INPUT]: Depends on SQLite with foreign keys and FTS5 enabled plus the pre-release Repository Artifact domain model.
-- [OUTPUT]: Provides the complete Hub Catalog baseline with Repository-owned Releases, immutable member snapshots, discovery projections, localization, Backfill Runs, and synchronized FTS.
-- [POS]: Serves as the single clean pre-release SQLite schema; no Skill-owned version or audit tables exist.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TABLE repositories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_host TEXT NOT NULL,
  repository_path TEXT NOT NULL,
  repository_id TEXT NOT NULL UNIQUE,
  current_release_id INTEGER REFERENCES repository_releases(id),
  description TEXT NOT NULL DEFAULT '',
  stars INTEGER NOT NULL DEFAULT 0,
  source_metadata_etag TEXT,
  source_metadata_checked_at TIMESTAMP,
  source_metadata_retry_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_host, repository_path)
);
CREATE TABLE repository_releases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  repository_id INTEGER NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  sum TEXT NOT NULL,
  archive_size INTEGER NOT NULL CHECK (archive_size > 0),
  release_info BLOB NOT NULL,
  commit_time TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(repository_id, version)
);
CREATE TABLE skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  repository_id INTEGER NOT NULL REFERENCES repositories(id),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  source_host TEXT NOT NULL DEFAULT '',
  repository TEXT NOT NULL DEFAULT '',
  skill_path TEXT NOT NULL DEFAULT '',
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(repository_id, name)
);
CREATE INDEX skills_repository_id ON skills(repository_id);
CREATE TABLE repository_release_members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  release_id INTEGER NOT NULL REFERENCES repository_releases(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  skill_path TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  UNIQUE(release_id, name)
);
CREATE TABLE localized_descriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resource_kind TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  locale TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  source_digest TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(resource_kind, resource_id, locale)
);
CREATE TABLE repository_backfill_runs (
  id TEXT PRIMARY KEY,
  repository_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'complete_with_errors')),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  error_count INTEGER NOT NULL DEFAULT 0,
  diagnostics TEXT NOT NULL DEFAULT '[]',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
CREATE UNIQUE INDEX repository_backfill_runs_one_active ON repository_backfill_runs(repository_id)
  WHERE status IN ('queued', 'running');
CREATE INDEX repository_backfill_runs_repository_created ON repository_backfill_runs(repository_id, created_at DESC);
CREATE VIRTUAL TABLE skills_fts USING fts5(name, description, content='skills', content_rowid='id', tokenize='trigram');
CREATE TRIGGER skills_fts_insert AFTER INSERT ON skills BEGIN
  INSERT INTO skills_fts(rowid,name,description) VALUES(new.id,new.name,new.description);
END;
GO
CREATE TRIGGER skills_fts_delete AFTER DELETE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description) VALUES('delete',old.id,old.name,old.description);
END;
GO
CREATE TRIGGER skills_fts_update AFTER UPDATE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description) VALUES('delete',old.id,old.name,old.description);
  INSERT INTO skills_fts(rowid,name,description) VALUES(new.id,new.name,new.description);
END;
GO
