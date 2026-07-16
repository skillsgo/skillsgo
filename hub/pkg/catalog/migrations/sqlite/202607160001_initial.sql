-- [INPUT]: Depends on SQLite with foreign keys and FTS5 enabled.
-- [OUTPUT]: Provides the initial Catalog relational schema and FTS5 search index.
-- [POS]: Serves as the first reviewed SQLite schema migration for the Hub Catalog.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TABLE skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  source_host TEXT NOT NULL,
  repository TEXT NOT NULL,
  skill_path TEXT NOT NULL,
  latest_version TEXT NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE skill_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(skill_id, version)
);
CREATE TABLE risk_assessments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_version_id INTEGER NOT NULL REFERENCES skill_versions(id) ON DELETE CASCADE,
  level TEXT NOT NULL,
  scanner_version TEXT NOT NULL,
  evidence TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE install_events (
  event_id TEXT PRIMARY KEY,
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  agents TEXT NOT NULL,
  scope TEXT NOT NULL,
  cli_version TEXT NOT NULL,
  occurred_at TIMESTAMP NOT NULL,
  received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE skill_stats (
  skill_id INTEGER PRIMARY KEY REFERENCES skills(id) ON DELETE CASCADE,
  total_installs INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE skill_hourly_stats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  bucket TIMESTAMP NOT NULL,
  installs INTEGER NOT NULL DEFAULT 0,
  UNIQUE(skill_id, bucket)
);
CREATE VIRTUAL TABLE skills_fts USING fts5(name, description, skill_id, content='skills', content_rowid='id', tokenize='trigram');
