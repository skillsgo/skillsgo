-- [INPUT]: Depends on the legacy Catalog schema containing content_digest-backed Skill history.
-- [OUTPUT]: Destructively clears legacy Catalog history and renames the Skill version checksum column to sum.
-- [POS]: Serves as the intentional pre-release data reset for the h1 Sum protocol cutover.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
DELETE FROM localized_descriptions;
DELETE FROM repository_backfill_runs;
DELETE FROM repositories;

ALTER TABLE skill_versions RENAME COLUMN content_digest TO sum;
