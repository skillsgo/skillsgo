-- [INPUT]: Depends on Repository and Skill version metadata plus Historical Publication visibility.
-- [OUTPUT]: Adds one immutable completion marker per fully committed Repository Publication.
-- [POS]: Serves as the SQLite idempotency boundary distinguishing complete Repository publication from standalone Skill indexing.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
CREATE TABLE repository_publications (
    repository_id INTEGER NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    version TEXT NOT NULL,
    commit_sha TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK (visibility IN ('current', 'historical')),
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY (repository_id, version)
);

CREATE TABLE repository_publication_members (
    repository_id INTEGER NOT NULL,
    version TEXT NOT NULL,
    skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    PRIMARY KEY (repository_id, version, skill_id),
    FOREIGN KEY (repository_id, version) REFERENCES repository_publications(repository_id, version) ON DELETE CASCADE
);
