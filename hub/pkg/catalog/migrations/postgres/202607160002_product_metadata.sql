-- [INPUT]: Depends on the PostgreSQL skills and skill_versions tables.
-- [OUTPUT]: Adds repository popularity, source commit time, and deterministic ZIP size metadata.
-- [POS]: Serves as the additive product-metadata migration for Skill detail decisions.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE skills ADD COLUMN github_stars BIGINT NOT NULL DEFAULT 0;
ALTER TABLE skill_versions ADD COLUMN commit_time TIMESTAMPTZ NOT NULL DEFAULT '0001-01-01 00:00:00+00:00';
ALTER TABLE skill_versions ADD COLUMN archive_size BIGINT NOT NULL DEFAULT 0;
