-- [INPUT]: Depends on the reviewed PostgreSQL Package Catalog schema and sqlc's pgx/v5 generator.
-- [OUTPUT]: Defines typed Package, immutable Package Version Skill, localization, search, and Backfill persistence operations.
-- [POS]: Serves as the single maintained query source for the Hub Catalog module.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

-- name: UpsertPackage :one
INSERT INTO packages (source_host, source_path, path, created_at, updated_at)
VALUES ($1, $2, $3, $4, $4)
ON CONFLICT (path) DO UPDATE SET updated_at = excluded.updated_at
RETURNING *;

-- name: PackageByPath :one
SELECT * FROM packages WHERE path = sqlc.arg(package_path);

-- name: UpdatePackageSourceMetadata :execrows
UPDATE packages SET description = sqlc.arg(description), stars = sqlc.arg(stars), source_etag = sqlc.arg(source_etag),
source_checked_at = COALESCE(sqlc.narg(source_checked_at), source_checked_at), source_retry_at = sqlc.narg(source_retry_at),
updated_at = CURRENT_TIMESTAMP WHERE path = sqlc.arg(package_path);

-- name: InsertPackageVersion :one
INSERT INTO versions (package_id, version, ref, commit_sha, tree_sha, sum, archive_size, commit_time, created_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id;

-- name: InsertSkill :exec
INSERT INTO skills (
    version_id, name, path, description
) VALUES ($1,$2,$3,$4);

-- name: SetCurrentVersion :exec
UPDATE packages SET current_version_id=$2, updated_at=$3 WHERE id=$1;

-- name: SetCurrentVersionByCoordinate :exec
UPDATE packages AS target
SET current_version_id=(
    SELECT id FROM versions
    WHERE versions.package_id=target.id AND version=sqlc.arg(version)
), updated_at=sqlc.arg(updated_at)
WHERE target.path=sqlc.arg(package_path);

-- name: PackageVersionCount :one
SELECT COUNT(*)
FROM versions mv
JOIN packages m ON m.id=mv.package_id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version);

-- name: PackageVersion :one
SELECT mv.id, mv.package_id, mv.version, mv.ref, mv.commit_sha, mv.tree_sha,
       mv.sum, mv.archive_size, mv.commit_time, mv.created_at
FROM versions mv
JOIN packages m ON m.id=mv.package_id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version);

-- name: Skills :many
SELECT mvs.version_id, mvs.name, mv.version, mv.commit_sha,
       mvs.path, mv.commit_time, mvs.description
FROM packages m
JOIN versions mv ON mv.package_id=m.id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version)
ORDER BY mvs.path;

-- name: CurrentSkill :one
SELECT mvs.version_id, mvs.name, mv.version, mv.commit_sha,
       mvs.path, mv.commit_time, mvs.description
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mvs.name=sqlc.arg(name)
ORDER BY mvs.path
LIMIT 1;

-- name: SkillPublishedVersions :many
SELECT DISTINCT mv.version
FROM packages m
JOIN versions mv ON mv.package_id=m.id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mvs.name=sqlc.arg(name)
ORDER BY mv.version;

-- name: PackagePublicationCommit :one
SELECT mv.commit_sha
FROM versions mv
JOIN packages m ON m.id=mv.package_id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version);

-- name: UpsertLocalizedDescription :exec
INSERT INTO localized_descriptions (resource_kind,resource_id,locale,description,source_digest,prompt_version,created_at,updated_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$7)
ON CONFLICT(resource_kind,resource_id,locale) DO UPDATE SET
description=excluded.description,source_digest=excluded.source_digest,
prompt_version=excluded.prompt_version,updated_at=excluded.updated_at;

-- name: LocalizedDescription :one
SELECT description FROM localized_descriptions
WHERE resource_kind=$1 AND resource_id=$2 AND locale=$3;

-- name: SkillByCoordinate :one
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, mvs.description, m.source_host,
       m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mvs.name=sqlc.arg(name)
ORDER BY mvs.path
LIMIT 1;

-- name: SkillsByCoordinates :many
WITH requested AS (
    SELECT package_paths.package_path, skill_names.name, package_paths.ordinal
    FROM unnest(sqlc.arg(package_paths)::text[]) WITH ORDINALITY AS package_paths(package_path, ordinal)
    JOIN unnest(sqlc.arg(names)::text[]) WITH ORDINALITY AS skill_names(name, ordinal) USING (ordinal)
)
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, mvs.description, m.source_host,
       m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM requested input
JOIN packages m ON m.path=input.package_path
JOIN versions mv ON mv.id=m.current_version_id
JOIN LATERAL (
    SELECT candidate.*
    FROM skills candidate
    WHERE candidate.version_id=mv.id AND candidate.name=input.name
    ORDER BY candidate.path
    LIMIT 1
) mvs ON true
ORDER BY input.ordinal;

-- name: SkillsByPathCoordinates :many
WITH requested AS (
    SELECT package_paths.package_path, skill_paths.path, package_paths.ordinal
    FROM unnest(sqlc.arg(package_paths)::text[]) WITH ORDINALITY AS package_paths(package_path, ordinal)
    JOIN unnest(sqlc.arg(paths)::text[]) WITH ORDINALITY AS skill_paths(path, ordinal) USING (ordinal)
)
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, mvs.description, m.source_host,
       m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM requested input
JOIN packages m ON m.path=input.package_path
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id AND mvs.path=input.path
ORDER BY input.ordinal;

-- name: ListSkills :many
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, mvs.description, m.source_host,
       m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
ORDER BY mvs.name,m.path,mvs.path
LIMIT $1 OFFSET $2;

-- name: SearchSkills :many
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, mvs.description, m.source_host,
       m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE (sqlc.arg(exact_name)::boolean AND lower(mvs.name)=lower(sqlc.arg(query)))
OR (NOT sqlc.arg(exact_name)::boolean AND
    (mvs.name || ' ' || mvs.description || ' ' || m.path) ILIKE '%' || sqlc.arg(query) || '%')
ORDER BY CASE
    WHEN lower(mvs.name)=lower(sqlc.arg(query)) THEN 0
    WHEN lower(mvs.name) LIKE lower(sqlc.arg(query)) || '%' THEN 1
    WHEN lower(mvs.name) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 2
    WHEN lower(m.path)=lower(sqlc.arg(query)) THEN 3
    WHEN lower(m.path) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 4
    ELSE 5
END,
similarity(mvs.name,sqlc.arg(query)) DESC,m.path,mvs.path
LIMIT sqlc.arg(page_limit) OFFSET sqlc.arg(page_offset);

-- name: TranslationCandidates :many
SELECT 'module'::text AS resource_kind, m.path AS resource_id, m.description,
       COALESCE(ld.source_digest, '') AS source_digest,
       COALESCE(ld.prompt_version, '') AS prompt_version
FROM packages m
LEFT JOIN localized_descriptions ld
  ON ld.resource_kind='module' AND ld.resource_id=m.path AND ld.locale=$1
WHERE trim(m.description)<>''
UNION ALL
SELECT 'skill'::text, m.path || ':' || mvs.name, mvs.description,
       COALESCE(ld.source_digest, ''), COALESCE(ld.prompt_version, '')
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
LEFT JOIN localized_descriptions ld
  ON ld.resource_kind='skill' AND ld.resource_id=m.path || ':' || mvs.name AND ld.locale=$1
WHERE trim(mvs.description)<>''
  AND mvs.path=(
      SELECT min(candidate.path)
      FROM skills candidate
      WHERE candidate.version_id=mv.id AND candidate.name=mvs.name
  )
ORDER BY resource_kind, resource_id;

-- name: SearchLocalizedSkills :many
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, COALESCE(ls.description,mvs.description) AS description,
       m.source_host, m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
LEFT JOIN localized_descriptions ls
  ON ls.resource_kind='skill' AND ls.resource_id=m.path || ':' || mvs.name AND ls.locale=sqlc.arg(locale)
LEFT JOIN localized_descriptions lm
  ON lm.resource_kind='module' AND lm.resource_id=m.path AND lm.locale=sqlc.arg(locale)
WHERE (sqlc.arg(exact_name)::boolean AND lower(mvs.name)=lower(sqlc.arg(query)))
OR (NOT sqlc.arg(exact_name)::boolean AND (
    lower(mvs.name) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(mvs.description) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(m.path) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(COALESCE(ls.description,'')) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(COALESCE(lm.description,'')) LIKE '%' || lower(sqlc.arg(query)) || '%'
))
ORDER BY CASE
    WHEN lower(mvs.name)=lower(sqlc.arg(query)) THEN 0
    WHEN lower(mvs.name) LIKE lower(sqlc.arg(query)) || '%' THEN 1
    WHEN lower(mvs.name) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 2
    WHEN lower(m.path)=lower(sqlc.arg(query)) THEN 3
    WHEN lower(m.path) LIKE '%' || lower(sqlc.arg(query)) || '%' THEN 4
    ELSE 5
END,
similarity(mvs.name,sqlc.arg(query)) DESC,m.path,mvs.path
LIMIT sqlc.arg(page_limit) OFFSET sqlc.arg(page_offset);

-- name: FindLocalizedSkillsBatch :many
WITH requested AS (
    SELECT ids.id AS query_id, queries.query, package_paths.package_path, exact_names.exact_name, ids.ordinal
    FROM unnest(sqlc.arg(query_ids)::text[]) WITH ORDINALITY AS ids(id, ordinal)
    JOIN unnest(sqlc.arg(queries)::text[]) WITH ORDINALITY AS queries(query, ordinal) USING (ordinal)
    JOIN unnest(sqlc.arg(package_paths)::text[]) WITH ORDINALITY AS package_paths(package_path, ordinal) USING (ordinal)
    JOIN unnest(sqlc.arg(exact_names)::boolean[]) WITH ORDINALITY AS exact_names(exact_name, ordinal) USING (ordinal)
)
SELECT input.query_id::text AS query_id,input.query::text AS query,input.package_path::text AS requested_package_path,
       result.id,result.package_id,result.package_path,result.name,result.description,
       result.source_host,result.source_repository,result.path,result.latest_version,result.stars,
       result.created_at,result.updated_at
FROM requested input
JOIN LATERAL (
    SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
           mvs.name, COALESCE(ls.description,mvs.description) AS description,
           m.source_host, m.source_path AS source_repository, mvs.path,
           mv.version AS latest_version, m.stars,
           mv.created_at, m.updated_at,
           CASE
               WHEN lower(mvs.name)=lower(input.query) THEN 0
               WHEN lower(mvs.name) LIKE lower(input.query) || '%' THEN 1
               WHEN lower(mvs.name) LIKE '%' || lower(input.query) || '%' THEN 2
               WHEN lower(m.path)=lower(input.query) THEN 3
               WHEN lower(m.path) LIKE '%' || lower(input.query) || '%' THEN 4
               ELSE 5
           END AS sort_tier,
           similarity(mvs.name,input.query) AS name_similarity
    FROM packages m
    JOIN versions mv ON mv.id=m.current_version_id
    JOIN skills mvs ON mvs.version_id=mv.id
    LEFT JOIN localized_descriptions ls
      ON ls.resource_kind='skill' AND ls.resource_id=m.path || ':' || mvs.name AND ls.locale=sqlc.arg(locale)
    LEFT JOIN localized_descriptions lm
      ON lm.resource_kind='module' AND lm.resource_id=m.path AND lm.locale=sqlc.arg(locale)
    WHERE (
        input.package_path<>'' AND m.path=input.package_path AND mvs.name=input.query
    ) OR (
        input.package_path='' AND (
            (input.exact_name AND lower(mvs.name)=lower(input.query))
            OR (NOT input.exact_name AND (
                lower(mvs.name) LIKE '%' || lower(input.query) || '%'
                OR lower(mvs.description) LIKE '%' || lower(input.query) || '%'
                OR lower(m.path) LIKE '%' || lower(input.query) || '%'
                OR lower(COALESCE(ls.description,'')) LIKE '%' || lower(input.query) || '%'
                OR lower(COALESCE(lm.description,'')) LIKE '%' || lower(input.query) || '%'
            ))
        )
    )
    ORDER BY sort_tier,name_similarity DESC,m.path,mvs.path
    LIMIT CASE WHEN input.package_path<>'' THEN 1 ELSE sqlc.arg(page_limit)::int END
) result ON true
ORDER BY input.ordinal,result.sort_tier,result.name_similarity DESC,
         result.package_path,result.path;

-- name: FindExactLocalizedSkillsBatch :many
WITH requested AS (
    SELECT ids.id AS query_id, queries.query, package_paths.package_path, ids.ordinal
    FROM unnest(sqlc.arg(query_ids)::text[]) WITH ORDINALITY AS ids(id, ordinal)
    JOIN unnest(sqlc.arg(queries)::text[]) WITH ORDINALITY AS queries(query, ordinal) USING (ordinal)
    JOIN unnest(sqlc.arg(package_paths)::text[]) WITH ORDINALITY AS package_paths(package_path, ordinal) USING (ordinal)
),
ranked AS (
    SELECT input.query_id::text AS query_id,input.query::text AS query,input.package_path::text AS requested_package_path,input.ordinal,
           mvs.version_id AS id,mv.package_id,m.path AS package_path,mvs.name,
           COALESCE(ls.description,mvs.description) AS description,
           m.source_host,m.source_path AS source_repository,mvs.path,
           mv.version AS latest_version,m.stars,mv.created_at,m.updated_at,
           row_number() OVER (
               PARTITION BY input.ordinal
               ORDER BY CASE WHEN input.package_path<>'' THEN mvs.path ELSE '' END,
                        m.path,mvs.path
           ) AS result_ordinal
    FROM requested input
    JOIN packages m ON input.package_path='' OR m.path=input.package_path
    JOIN versions mv ON mv.id=m.current_version_id
    JOIN skills mvs
      ON mvs.version_id=mv.id AND lower(mvs.name)=lower(input.query)
    LEFT JOIN localized_descriptions ls
      ON ls.resource_kind='skill' AND ls.resource_id=m.path || ':' || mvs.name AND ls.locale=sqlc.arg(locale)
)
SELECT query_id,query,requested_package_path,id,package_id,package_path,name,description,
       source_host,source_repository,path,latest_version,stars,created_at,updated_at
FROM ranked
WHERE result_ordinal<=CASE WHEN requested_package_path<>'' THEN 1 ELSE sqlc.arg(page_limit)::bigint END
ORDER BY ordinal,result_ordinal;

-- name: ActiveBackfillRun :one
SELECT * FROM package_backfill_runs
WHERE package_path=$1 AND status IN ('queued','running')
ORDER BY created_at DESC LIMIT 1;

-- name: InsertBackfillRun :exec
INSERT INTO package_backfill_runs (id,package_path,status,error_count,diagnostics,created_at,updated_at)
VALUES ($1,$2,$3,0,$4,$5,$5);

-- name: LatestBackfillRun :one
SELECT * FROM package_backfill_runs WHERE package_path=$1 ORDER BY created_at DESC LIMIT 1;

-- name: BackfillRunByID :one
SELECT * FROM package_backfill_runs WHERE id=$1;

-- name: StartBackfillRun :execrows
UPDATE package_backfill_runs SET status='running',started_at=COALESCE(started_at,sqlc.arg(now)),updated_at=sqlc.arg(now)
WHERE id=sqlc.arg(id) AND status='queued';

-- name: CompleteBackfillRun :execrows
UPDATE package_backfill_runs SET status=$2,completed_at=$3,error_count=$4,diagnostics=$5,updated_at=$3
WHERE id=$1 AND status IN ('queued','running');

-- name: TouchBackfillRun :execrows
UPDATE package_backfill_runs SET updated_at=$2 WHERE id=$1 AND status='running';

-- name: ExpireStaleBackfillRuns :execrows
UPDATE package_backfill_runs SET status='complete_with_errors',completed_at=$2,error_count=error_count+1,diagnostics=$3,updated_at=$2
WHERE status='running' AND updated_at<$1;

-- name: StaleQueuedBackfillRuns :many
SELECT * FROM package_backfill_runs WHERE status='queued' AND updated_at<$1 ORDER BY updated_at LIMIT $2;

-- name: ExpireQueuedBackfillRun :execrows
UPDATE package_backfill_runs SET status='complete_with_errors',completed_at=$2,error_count=error_count+1,diagnostics=$3,updated_at=$2
WHERE id=$1 AND status='queued';
