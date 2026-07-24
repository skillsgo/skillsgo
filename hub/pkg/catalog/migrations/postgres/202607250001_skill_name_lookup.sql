-- [INPUT]: Depends on the Catalog skills table and case-insensitive exact-name Find semantics.
-- [OUTPUT]: Provides an indexed lower-case Skill name lookup for exact single and set-based batch Find requests.
-- [POS]: Accelerates adoption matching without changing public Skill identity or stored user data.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE INDEX skills_name_lower ON skills (lower(name));
