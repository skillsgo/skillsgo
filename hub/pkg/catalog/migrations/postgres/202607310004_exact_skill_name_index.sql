-- [INPUT]: Depends on the Catalog skills table and case-sensitive exact-name candidate lookup.
-- [OUTPUT]: Adds a B-tree index for case-sensitive exact Skill name equality.
-- [POS]: Serves as the query-specific index for server-ranked exact-name Adoption candidates.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

CREATE INDEX skills_name ON skills (name);
