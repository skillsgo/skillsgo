-- [INPUT]: Depends on the legacy Catalog schema containing content_digest-backed Skill history.
-- [OUTPUT]: Destructively clears pre-release Catalog history before Repository artifact publication becomes authoritative.
-- [POS]: Serves as the intentional pre-release data reset for the Repository artifact architecture cutover.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
DELETE FROM localized_descriptions;
DELETE FROM repository_backfill_runs;
DELETE FROM repositories;
