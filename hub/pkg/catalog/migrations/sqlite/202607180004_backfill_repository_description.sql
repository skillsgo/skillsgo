-- [INPUT]: Depends on legacy Repository metadata rows that may retain an ETag without a description.
-- [OUTPUT]: Schedules one unconditional provider refresh for Repository About metadata.
-- [POS]: Serves as the SQLite compatibility backfill after adding Repository descriptions.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
UPDATE repositories SET source_metadata_checked_at = NULL WHERE description = '';
