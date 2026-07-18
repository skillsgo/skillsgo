-- atlas:delimiter \nGO
-- [INPUT]: Depends on SQLite with foreign keys and FTS5 enabled.
-- [OUTPUT]: Provides the complete initial Catalog schema, indexes, and synchronized FTS5 search resources.
-- [POS]: Serves as the single pre-release SQLite baseline migration for the Hub Catalog.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TABLE repositories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_host TEXT NOT NULL,
  repository_path TEXT NOT NULL,
  repository_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_host, repository_path)
);
CREATE TABLE skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  source_host TEXT NOT NULL,
  repository TEXT NOT NULL,
  repository_id INTEGER NOT NULL REFERENCES repositories(id),
  skill_path TEXT NOT NULL,
  latest_version TEXT NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  github_stars INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX skills_repository_id ON skills(repository_id);
CREATE TABLE skill_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  tree_sha TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  commit_time TIMESTAMP NOT NULL DEFAULT '0001-01-01 00:00:00+00:00',
  archive_size INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(skill_id, version)
);
CREATE TABLE skill_risk_assessments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_version_id INTEGER NOT NULL REFERENCES skill_versions(id) ON DELETE CASCADE,
  level TEXT NOT NULL,
  scanner_version TEXT NOT NULL,
  evidence TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE skill_install_events (
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
CREATE TRIGGER skills_fts_insert AFTER INSERT ON skills BEGIN
  INSERT INTO skills_fts(rowid,name,description,skill_id) VALUES(new.id,new.name,new.description,new.skill_id);
END;
GO
CREATE TRIGGER skills_fts_delete AFTER DELETE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description,skill_id) VALUES('delete',old.id,old.name,old.description,old.skill_id);
END;
GO
CREATE TRIGGER skills_fts_update AFTER UPDATE ON skills BEGIN
  INSERT INTO skills_fts(skills_fts,rowid,name,description,skill_id) VALUES('delete',old.id,old.name,old.description,old.skill_id);
  INSERT INTO skills_fts(rowid,name,description,skill_id) VALUES(new.id,new.name,new.description,new.skill_id);
END;
GO
