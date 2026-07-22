-- [INPUT]: Depends on existing Skill rows representing current discovery membership.
-- [OUTPUT]: Adds explicit current-discovery visibility while preserving every existing Skill as discoverable.
-- [POS]: Serves as the PostgreSQL schema transition enabling Historical Publication without resurrecting retired Skills.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE skills ADD COLUMN discoverable BOOLEAN NOT NULL DEFAULT TRUE;
