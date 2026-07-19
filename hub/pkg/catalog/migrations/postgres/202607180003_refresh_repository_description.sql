-- [INPUT]: Depends on Repository description storage and prior source metadata cache timestamps.
-- [OUTPUT]: Invalidates legacy source metadata cache rows once so descriptions are populated.
-- [POS]: Serves as the PostgreSQL data migration for Repository About metadata backfill.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
UPDATE repositories SET source_metadata_checked_at = NULL;
