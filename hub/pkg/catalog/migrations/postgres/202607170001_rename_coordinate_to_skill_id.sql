-- [INPUT]: Depends on the PostgreSQL skills table and its existing coordinate search index.
-- [OUTPUT]: Renames the public Skill identifier column to skill_id and rebuilds its trigram search index.
-- [POS]: Serves as the additive Catalog migration from Skill Coordinate to public Skill ID terminology.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
DROP INDEX skills_search_trgm;
ALTER TABLE skills RENAME COLUMN coordinate TO skill_id;
CREATE INDEX skills_search_trgm ON skills USING gin ((name || ' ' || description || ' ' || skill_id) gin_trgm_ops);
