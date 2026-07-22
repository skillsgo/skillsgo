-- [INPUT]: Depends on complete Repository Publication markers and immutable member metadata.
-- [OUTPUT]: Persists the exact Repository Release Record bytes committed with each publication.
-- [POS]: Serves as the SQLite byte-stability boundary for exact Repository .info responses.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE repository_publications ADD COLUMN release_info BLOB NOT NULL DEFAULT X'';
