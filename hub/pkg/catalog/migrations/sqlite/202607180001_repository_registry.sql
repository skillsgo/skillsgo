-- [INPUT]: Depends on the normalized Repository registry plus the existing skills, install_events, and risk_assessments tables.
-- [OUTPUT]: Adds the Repository lookup index and gives Skill-scoped event/risk tables explicit names.
-- [POS]: Serves as the SQLite migration to repository-owned public identity and unambiguous telemetry table scope.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE install_events RENAME TO skill_install_events;
ALTER TABLE risk_assessments RENAME TO skill_risk_assessments;
CREATE INDEX skills_repository_id ON skills(repository_id);
