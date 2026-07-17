-- [INPUT]: Depends on canonical Skill IDs plus the existing skills, install_events, and risk_assessments tables.
-- [OUTPUT]: Adds the normalized repositories registry, links every Skill to its Repository, and gives Skill-scoped event/risk tables explicit names.
-- [POS]: Serves as the SQLite migration to repository-owned public identity and unambiguous telemetry table scope.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE install_events RENAME TO skill_install_events;
ALTER TABLE risk_assessments RENAME TO skill_risk_assessments;
CREATE TABLE repositories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_host TEXT NOT NULL,
  repository_path TEXT NOT NULL,
  repository_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_host, repository_path)
);
INSERT INTO repositories (source_host, repository_path, repository_id)
SELECT DISTINCT lower(source_host), lower(repository), lower(source_host || '/' || repository) FROM skills;
ALTER TABLE skills ADD COLUMN repository_id INTEGER REFERENCES repositories(id);
UPDATE skills SET repository_id = (
  SELECT repositories.id FROM repositories
  WHERE repositories.repository_id = lower(skills.source_host || '/' || skills.repository)
);
CREATE INDEX skills_repository_id ON skills(repository_id);
