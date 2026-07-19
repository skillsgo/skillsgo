-- [INPUT]: Depends on the pre-existing PostgreSQL repositories table.
-- [OUTPUT]: Adds provider-owned Repository description cache storage.
-- [POS]: Serves as the PostgreSQL schema evolution for Repository About metadata.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE repositories ADD COLUMN description text NOT NULL DEFAULT '';
