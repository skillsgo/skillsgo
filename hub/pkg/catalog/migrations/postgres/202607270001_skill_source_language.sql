-- [INPUT]: Depends on immutable version-owned Skill rows published before source-language provenance existed.
-- [OUTPUT]: Adds persisted source-language provenance for each immutable Skill snapshot.
-- [POS]: Serves as the forward-only Catalog migration that moves language detection out of detail reads.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE skills ADD COLUMN source_language TEXT NOT NULL DEFAULT '';

COMMENT ON COLUMN skills.source_language IS 'Detected BCP 47 source language for the immutable SKILL.md document; empty when undetermined or mixed.';
