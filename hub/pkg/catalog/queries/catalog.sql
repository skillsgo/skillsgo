-- [INPUT]: Depends on the reviewed PostgreSQL Catalog schema and sqlc's pgx/v5 generator.
-- [OUTPUT]: Defines typed Repository, Release, Skill, localization, name-first/exact Find, and Backfill persistence operations.
-- [POS]: Serves as the single maintained query source for the Hub Catalog module.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

-- name: UpsertRepository :one
INSERT INTO repositories (source_host, repository_path, repository_id, created_at, updated_at)
VALUES ($1, $2, $3, $4, $4)
ON CONFLICT (repository_id) DO UPDATE SET updated_at = excluded.updated_at
RETURNING *;

-- name: RepositoryByIdentity :one
SELECT * FROM repositories WHERE repository_id = $1;

-- name: UpdateRepositorySourceMetadata :execrows
UPDATE repositories SET description = $2, stars = $3, source_metadata_etag = $4,
source_metadata_checked_at = COALESCE($5, source_metadata_checked_at), source_metadata_retry_at = $6,
updated_at = CURRENT_TIMESTAMP WHERE repository_id = $1;

-- name: UpsertSkill :one
INSERT INTO skills (repository_id, name, description, source_host, repository, skill_path, verified, created_at, updated_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
ON CONFLICT (repository_id, skill_path) DO UPDATE SET name=excluded.name, description=excluded.description, source_host=excluded.source_host,
repository=excluded.repository, verified=excluded.verified, updated_at=excluded.updated_at
RETURNING id;

-- name: DeleteRepositorySkills :exec
DELETE FROM skills WHERE repository_id = $1;

-- name: InsertSkill :exec
INSERT INTO skills (repository_id, name, description, source_host, repository, skill_path, verified, created_at, updated_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9);

-- name: InsertRepositoryRelease :one
INSERT INTO repository_releases (repository_id, version, commit_sha, tree_sha, sum, archive_size, release_info, commit_time, created_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id;

-- name: InsertRepositoryReleaseMember :exec
INSERT INTO repository_release_members (release_id, name, skill_path, tree_sha) VALUES ($1,$2,$3,$4);

-- name: SetCurrentRelease :exec
UPDATE repositories SET current_release_id=$2, updated_at=$3 WHERE id=$1;

-- name: SetCurrentReleaseByVersion :exec
UPDATE repositories AS target SET current_release_id=(SELECT id FROM repository_releases WHERE repository_releases.repository_id=target.id AND version=$2), updated_at=$3 WHERE target.repository_id=$1;

-- name: RepositoryReleaseCount :one
SELECT COUNT(*) FROM repository_releases rr JOIN repositories r ON r.id=rr.repository_id WHERE r.repository_id=$1 AND rr.version=$2;

-- name: RepositoryReleaseInfo :one
SELECT rr.release_info FROM repository_releases rr JOIN repositories r ON r.id=rr.repository_id WHERE r.repository_id=$1 AND rr.version=$2;

-- name: RepositoryReleaseMembers :many
SELECT rrm.release_id, rrm.name, rr.version, rr.commit_sha, rrm.tree_sha, rrm.skill_path, rr.commit_time
FROM repositories r JOIN repository_releases rr ON rr.repository_id=r.id JOIN repository_release_members rrm ON rrm.release_id=rr.id
WHERE r.repository_id=$1 AND rr.version=$2 ORDER BY rrm.skill_path;

-- name: CurrentRepositoryReleaseMember :one
SELECT rrm.release_id, rrm.name, rr.version, rr.commit_sha, rrm.tree_sha, rrm.skill_path, rr.commit_time
FROM repositories r JOIN repository_releases rr ON rr.id=r.current_release_id JOIN repository_release_members rrm ON rrm.release_id=rr.id
WHERE r.repository_id=$1 AND rrm.name=$2 ORDER BY rrm.skill_path LIMIT 1;

-- name: SkillPublishedVersions :many
SELECT DISTINCT rr.version FROM repositories r JOIN repository_releases rr ON rr.repository_id=r.id
JOIN repository_release_members rrm ON rrm.release_id=rr.id WHERE r.repository_id=$1 AND rrm.name=$2 ORDER BY rr.version;

-- name: RepositoryPublicationCommit :one
SELECT rr.commit_sha FROM repository_releases rr JOIN repositories r ON r.id=rr.repository_id WHERE r.repository_id=$1 AND rr.version=$2;

-- name: UpsertLocalizedDescription :exec
INSERT INTO localized_descriptions (resource_kind,resource_id,locale,description,source_digest,prompt_version,created_at,updated_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$7) ON CONFLICT(resource_kind,resource_id,locale) DO UPDATE SET
description=excluded.description,source_digest=excluded.source_digest,prompt_version=excluded.prompt_version,updated_at=excluded.updated_at;

-- name: LocalizedDescription :one
SELECT description FROM localized_descriptions WHERE resource_kind=$1 AND resource_id=$2 AND locale=$3;

-- name: SkillByCoordinate :one
SELECT s.id,s.repository_id,r.repository_id AS repository_identity,s.name,s.description,s.source_host,s.repository,s.skill_path,
COALESCE(cr.version,'') AS latest_version,r.stars,s.verified,s.created_at,s.updated_at
FROM skills s JOIN repositories r ON r.id=s.repository_id LEFT JOIN repository_releases cr ON cr.id=r.current_release_id
WHERE r.repository_id=$1 AND s.name=$2 ORDER BY s.skill_path LIMIT 1;

-- name: SkillsByCoordinates :many
WITH requested AS (
    SELECT repositories.repository_identity, skill_names.name, repositories.ordinal
    FROM unnest(sqlc.arg(repository_identities)::text[]) WITH ORDINALITY AS repositories(repository_identity, ordinal)
    JOIN unnest(sqlc.arg(names)::text[]) WITH ORDINALITY AS skill_names(name, ordinal) USING (ordinal)
)
SELECT s.id,s.repository_id,r.repository_id AS repository_identity,s.name,s.description,s.source_host,s.repository,s.skill_path,
COALESCE(cr.version,'') AS latest_version,r.stars,s.verified,s.created_at,s.updated_at
FROM requested input
JOIN repositories r ON r.repository_id=input.repository_identity
JOIN LATERAL (
    SELECT candidate.* FROM skills candidate
    WHERE candidate.repository_id=r.id AND candidate.name=input.name
    ORDER BY candidate.skill_path LIMIT 1
) s ON true
LEFT JOIN repository_releases cr ON cr.id=r.current_release_id
ORDER BY input.ordinal;

-- name: ListSkills :many
SELECT s.id,s.repository_id,r.repository_id AS repository_identity,s.name,s.description,s.source_host,s.repository,s.skill_path,
COALESCE(cr.version,'') AS latest_version,r.stars,s.verified,s.created_at,s.updated_at
FROM skills s JOIN repositories r ON r.id=s.repository_id LEFT JOIN repository_releases cr ON cr.id=r.current_release_id
ORDER BY s.verified DESC,s.name LIMIT $1 OFFSET $2;

-- name: SearchSkills :many
SELECT s.id,s.repository_id,r.repository_id AS repository_identity,s.name,s.description,s.source_host,s.repository,s.skill_path,
COALESCE(cr.version,'') AS latest_version,r.stars,s.verified,s.created_at,s.updated_at
FROM skills s JOIN repositories r ON r.id=s.repository_id LEFT JOIN repository_releases cr ON cr.id=r.current_release_id
WHERE (sqlc.arg(exact_name)::boolean AND lower(s.name)=lower(sqlc.arg(query)))
OR (NOT sqlc.arg(exact_name)::boolean AND (s.name || ' ' || s.description || ' ' || r.repository_id) ILIKE '%' || sqlc.arg(query) || '%')
ORDER BY CASE
    WHEN lower(s.name)=lower(sqlc.arg(query)) THEN 0
    WHEN lower(s.name) LIKE lower(sqlc.arg(query)) || '%' THEN 1
    WHEN lower(s.name) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 2
    WHEN lower(r.repository_id)=lower(sqlc.arg(query)) THEN 3
    WHEN lower(r.repository_id) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 4
    ELSE 5
END,
similarity(s.name,sqlc.arg(query)) DESC,s.verified DESC,r.repository_id,s.skill_path
LIMIT sqlc.arg(page_limit) OFFSET sqlc.arg(page_offset);

-- name: TranslationCandidates :many
SELECT 'repository'::text AS resource_kind, r.repository_id AS resource_id, r.description,
COALESCE(ld.source_digest, '') AS source_digest, COALESCE(ld.prompt_version, '') AS prompt_version
FROM repositories r LEFT JOIN localized_descriptions ld
ON ld.resource_kind='repository' AND ld.resource_id=r.repository_id AND ld.locale=$1
WHERE trim(r.description)<>''
UNION ALL
SELECT 'skill'::text, r.repository_id || ':' || s.name, s.description,
COALESCE(ld.source_digest, ''), COALESCE(ld.prompt_version, '')
FROM skills s JOIN repositories r ON r.id=s.repository_id LEFT JOIN localized_descriptions ld
ON ld.resource_kind='skill' AND ld.resource_id=r.repository_id || ':' || s.name AND ld.locale=$1
WHERE trim(s.description)<>'' AND s.skill_path=(
    SELECT min(candidate.skill_path) FROM skills candidate
    WHERE candidate.repository_id=s.repository_id AND candidate.name=s.name
) ORDER BY resource_kind, resource_id;

-- name: SearchLocalizedSkills :many
SELECT s.id,s.repository_id,r.repository_id AS repository_identity,s.name,
COALESCE(ls.description,s.description) AS description,s.source_host,s.repository,s.skill_path,
COALESCE(cr.version,'') AS latest_version,r.stars,s.verified,s.created_at,s.updated_at
FROM skills s JOIN repositories r ON r.id=s.repository_id
LEFT JOIN repository_releases cr ON cr.id=r.current_release_id
LEFT JOIN localized_descriptions ls ON ls.resource_kind='skill' AND ls.resource_id=r.repository_id || ':' || s.name AND ls.locale=sqlc.arg(locale)
LEFT JOIN localized_descriptions lr ON lr.resource_kind='repository' AND lr.resource_id=r.repository_id AND lr.locale=sqlc.arg(locale)
WHERE (sqlc.arg(exact_name)::boolean AND lower(s.name)=lower(sqlc.arg(query)))
OR (NOT sqlc.arg(exact_name)::boolean AND (
    lower(s.name) LIKE '%' || lower(sqlc.arg(query)) || '%' OR lower(s.description) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(r.repository_id) LIKE '%' || lower(sqlc.arg(query)) || '%' OR lower(COALESCE(ls.description,'')) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(COALESCE(lr.description,'')) LIKE '%' || lower(sqlc.arg(query)) || '%'
))
ORDER BY CASE
    WHEN lower(s.name)=lower(sqlc.arg(query)) THEN 0
    WHEN lower(s.name) LIKE lower(sqlc.arg(query)) || '%' THEN 1
    WHEN lower(s.name) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 2
    WHEN lower(r.repository_id)=lower(sqlc.arg(query)) THEN 3
    WHEN lower(r.repository_id) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 4
    ELSE 5
END,
similarity(s.name,sqlc.arg(query)) DESC,s.verified DESC,r.repository_id,s.skill_path
LIMIT sqlc.arg(page_limit) OFFSET sqlc.arg(page_offset);

-- name: ActiveBackfillRun :one
SELECT * FROM repository_backfill_runs WHERE repository_id=$1 AND status IN ('queued','running') ORDER BY created_at DESC LIMIT 1;

-- name: InsertBackfillRun :exec
INSERT INTO repository_backfill_runs (id,repository_id,status,error_count,diagnostics,created_at,updated_at)
VALUES ($1,$2,$3,0,$4,$5,$5);

-- name: LatestBackfillRun :one
SELECT * FROM repository_backfill_runs WHERE repository_id=$1 ORDER BY created_at DESC LIMIT 1;

-- name: BackfillRunByID :one
SELECT * FROM repository_backfill_runs WHERE id=$1;

-- name: StartBackfillRun :execrows
UPDATE repository_backfill_runs SET status='running',started_at=COALESCE(started_at,sqlc.arg(now)),updated_at=sqlc.arg(now)
WHERE id=sqlc.arg(id) AND status='queued';

-- name: CompleteBackfillRun :execrows
UPDATE repository_backfill_runs SET status=$2,completed_at=$3,error_count=$4,diagnostics=$5,updated_at=$3
WHERE id=$1 AND status IN ('queued','running');

-- name: TouchBackfillRun :execrows
UPDATE repository_backfill_runs SET updated_at=$2 WHERE id=$1 AND status='running';

-- name: ExpireStaleBackfillRuns :execrows
UPDATE repository_backfill_runs SET status='complete_with_errors',completed_at=$2,error_count=error_count+1,diagnostics=$3,updated_at=$2
WHERE status='running' AND updated_at<$1;

-- name: StaleQueuedBackfillRuns :many
SELECT * FROM repository_backfill_runs WHERE status='queued' AND updated_at<$1 ORDER BY updated_at LIMIT $2;

-- name: ExpireQueuedBackfillRun :execrows
UPDATE repository_backfill_runs SET status='complete_with_errors',completed_at=$2,error_count=error_count+1,diagnostics=$3,updated_at=$2
WHERE id=$1 AND status='queued';
