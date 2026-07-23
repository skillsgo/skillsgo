-- [INPUT]: Depends on the initial Repository Catalog schema whose Skill projections and immutable members were unique by name.
-- [OUTPUT]: Allows complete same-name Skill metadata at distinct source paths while retaining one row per Repository or Release path.
-- [POS]: Evolves Skill membership identity from name uniqueness to source-path uniqueness without discarding published data.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ALTER TABLE skills DROP CONSTRAINT skills_repository_id_name_key;
ALTER TABLE skills ADD CONSTRAINT skills_repository_id_skill_path_key UNIQUE (repository_id, skill_path);
ALTER TABLE repository_release_members DROP CONSTRAINT repository_release_members_release_id_name_key;
ALTER TABLE repository_release_members ADD CONSTRAINT repository_release_members_release_id_skill_path_key UNIQUE (release_id, skill_path);
