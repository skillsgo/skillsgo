-- [INPUT]: Depends on SQLite skill_install_events retained by the initial Catalog schema.
-- [OUTPUT]: Provides the time-window index used by rolling Hot ranking aggregation.
-- [POS]: Serves as the SQLite query-support migration for short-term installation velocity.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE INDEX skill_install_events_occurred_at_skill_id ON skill_install_events(occurred_at, skill_id);
