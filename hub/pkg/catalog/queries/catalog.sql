-- [INPUT]: Depends on the reviewed PostgreSQL Package Catalog schema and sqlc's pgx/v5 generator.
-- [OUTPUT]: Defines typed Package, immutable Package Version listing, exact-path Skill history, one-query localized Card reads, due metadata keyset scans, batch current-Package update projection, localization, search, and Backfill persistence operations.
-- [POS]: Serves as the single maintained query source for the Hub Catalog module.
-- [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

-- name: UpsertPackage :one
INSERT INTO packages (source_host, source_path, path, created_at, updated_at)
VALUES ($1, $2, $3, $4, $4)
ON CONFLICT (path) DO UPDATE SET updated_at = excluded.updated_at
RETURNING *;

-- name: PackageByPath :one
SELECT * FROM packages WHERE path = sqlc.arg(package_path);

-- name: PackagesDueForSourceMetadataRefresh :many
SELECT id, path
FROM packages
WHERE current_version_id IS NOT NULL
  AND source_host = ANY(sqlc.arg(source_hosts)::text[])
  AND (source_checked_at IS NULL OR source_checked_at <= sqlc.arg(stale_before))
  AND (source_retry_at IS NULL OR source_retry_at <= sqlc.arg(now))
  AND id > sqlc.arg(after_id)
ORDER BY id
LIMIT sqlc.arg(page_limit);

-- name: CurrentPackagesByPaths :many
WITH requested AS (
    SELECT package_path, ordinal
    FROM unnest(sqlc.arg(package_paths)::text[]) WITH ORDINALITY AS input(package_path, ordinal)
)
SELECT input.package_path::text AS package_path,
       COALESCE(mv.version, '')::text AS latest_version,
       COALESCE(mv.sum, '')::text AS sum,
       COALESCE(
           jsonb_agg(jsonb_build_object('name', mvs.name, 'path', mvs.path) ORDER BY mvs.path)
               FILTER (WHERE mvs.id IS NOT NULL),
           '[]'::jsonb
       )::jsonb AS skills
FROM requested input
LEFT JOIN packages m ON m.path=input.package_path
LEFT JOIN versions mv ON mv.id=m.current_version_id
LEFT JOIN skills mvs ON mvs.version_id=mv.id
GROUP BY input.ordinal, input.package_path, mv.version, mv.sum
ORDER BY input.ordinal;

-- name: CurrentPackageVersionForUpdate :one
SELECT COALESCE(mv.version, '')::text
FROM packages m
LEFT JOIN versions mv ON mv.id=m.current_version_id
WHERE m.id=sqlc.arg(package_id)
FOR UPDATE OF m;

-- name: UpdatePackageSourceMetadata :execrows
UPDATE packages SET description = sqlc.arg(description), description_digest = sqlc.arg(description_digest), stars = sqlc.arg(stars), source_etag = sqlc.arg(source_etag),
source_checked_at = COALESCE(sqlc.narg(source_checked_at), source_checked_at), source_retry_at = sqlc.narg(source_retry_at),
updated_at = CURRENT_TIMESTAMP WHERE path = sqlc.arg(package_path);

-- name: InsertPackageVersion :one
INSERT INTO versions (package_id, version, ref, commit_sha, tree_sha, sum, commit_time, created_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id;

-- name: InsertSkill :exec
INSERT INTO skills (
    version_id, name, path, description, description_digest, document_digest, source_language
) VALUES ($1,$2,$3,$4,$5,$6,$7);

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
       mv.sum, mv.commit_time, mv.created_at
FROM versions mv
JOIN packages m ON m.id=mv.package_id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version);

-- name: Skills :many
SELECT mvs.version_id, mvs.name, mv.version, mv.commit_sha,
       mvs.path, mv.commit_time, mvs.description, mvs.description_digest, mvs.document_digest, mvs.source_language
FROM packages m
JOIN versions mv ON mv.package_id=m.id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version)
ORDER BY mvs.path;

-- name: LocalizedVersionSkillCards :many
SELECT mvs.version_id, mvs.name, mv.version, mv.commit_sha,
       mvs.path, mv.commit_time, COALESCE(l.text_content,mvs.description) AS description,
       mvs.description_digest, mvs.document_digest, mvs.source_language
FROM packages m
JOIN versions mv ON mv.package_id=m.id
JOIN skills mvs ON mvs.version_id=mv.id
LEFT JOIN localizations l
  ON l.resource_kind='skill_description' AND l.source_digest=mvs.description_digest
  AND l.lang=sqlc.arg(lang) AND l.result_kind='translated'
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version)
ORDER BY mvs.path;

-- name: CurrentSkill :one
SELECT mvs.version_id, mvs.name, mv.version, mv.commit_sha,
       mvs.path, mv.commit_time, mvs.description, mvs.description_digest, mvs.document_digest, mvs.source_language
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mvs.name=sqlc.arg(name)
ORDER BY mvs.path
LIMIT 1;

-- name: SkillPublishedVersionsByPath :many
SELECT DISTINCT mv.version
FROM packages m
JOIN versions mv ON mv.package_id=m.id
JOIN skills mvs ON mvs.version_id=mv.id
WHERE m.path=sqlc.arg(package_path) AND mvs.path=sqlc.arg(path)
ORDER BY mv.version;

-- name: PackagePublishedVersions :many
SELECT mv.version
FROM packages m
JOIN versions mv ON mv.package_id=m.id
WHERE m.path=sqlc.arg(package_path)
ORDER BY mv.version;

-- name: PackagePublicationCommit :one
SELECT mv.commit_sha
FROM versions mv
JOIN packages m ON m.id=mv.package_id
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version);

-- name: UpsertLocalization :exec
INSERT INTO localizations (resource_kind,source_digest,lang,result_kind,text_content,prompt_version,updated_at)
VALUES ($1,$2,$3,$4,$5,$6,$7)
ON CONFLICT(resource_kind,source_digest,lang) DO UPDATE SET
result_kind=excluded.result_kind,text_content=excluded.text_content,
prompt_version=excluded.prompt_version,error_kind=NULL,error_message=NULL,updated_at=excluded.updated_at;

-- name: UpsertLocalizationFailure :exec
INSERT INTO localizations (resource_kind,source_digest,lang,result_kind,prompt_version,error_kind,error_message,updated_at)
VALUES ($1,$2,$3,'failed',$4,$5,$6,$7)
ON CONFLICT(resource_kind,source_digest,lang) DO UPDATE SET
result_kind='failed',text_content=NULL,prompt_version=excluded.prompt_version,
error_kind=excluded.error_kind,error_message=excluded.error_message,updated_at=excluded.updated_at;

-- name: PackageLocalizedDescription :one
SELECT l.text_content
FROM packages m JOIN localizations l ON l.source_digest=m.description_digest
WHERE m.path=$1 AND l.resource_kind='package_description' AND l.lang=$2
  AND l.result_kind='translated';

-- name: SkillLocalizedDescription :one
SELECT l.text_content
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
JOIN localizations l ON l.source_digest=mvs.description_digest
WHERE m.path=$1 AND mvs.name=$2 AND l.resource_kind='skill_description' AND l.lang=$3
  AND l.result_kind='translated'
ORDER BY mvs.path LIMIT 1;

-- name: VersionSkillLocalization :one
SELECT l.result_kind,l.text_content,l.source_digest,l.prompt_version,mvs.document_digest,mvs.description_digest
FROM packages m
JOIN versions mv ON mv.package_id=m.id
JOIN skills mvs ON mvs.version_id=mv.id
JOIN localizations l ON l.source_digest=CASE WHEN sqlc.arg(resource_kind)::text='skill_document' THEN mvs.document_digest ELSE mvs.description_digest END
WHERE m.path=sqlc.arg(package_path) AND mv.version=sqlc.arg(version) AND mvs.path=sqlc.arg(skill_path)
  AND l.resource_kind=sqlc.arg(resource_kind)::text AND l.lang=sqlc.arg(lang);

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
       mvs.name, COALESCE(ls.text_content,mvs.description) AS description, m.source_host,
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
LEFT JOIN localizations ls
  ON ls.resource_kind='skill_description' AND ls.source_digest=mvs.description_digest
  AND ls.lang=sqlc.arg(lang) AND ls.result_kind='translated'
ORDER BY input.ordinal;

-- name: SkillsByPathCoordinates :many
WITH requested AS (
    SELECT package_paths.package_path, skill_paths.path, package_paths.ordinal
    FROM unnest(sqlc.arg(package_paths)::text[]) WITH ORDINALITY AS package_paths(package_path, ordinal)
    JOIN unnest(sqlc.arg(paths)::text[]) WITH ORDINALITY AS skill_paths(path, ordinal) USING (ordinal)
)
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, COALESCE(ls.text_content,mvs.description) AS description, m.source_host,
       m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM requested input
JOIN packages m ON m.path=input.package_path
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id AND mvs.path=input.path
LEFT JOIN localizations ls
  ON ls.resource_kind='skill_description' AND ls.source_digest=mvs.description_digest
  AND ls.lang=sqlc.arg(lang) AND ls.result_kind='translated'
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
SELECT DISTINCT ON (m.description_digest) 'package_description'::text AS resource_kind,
       m.path AS resource_id, m.description, m.description_digest AS content_digest,
       COALESCE(ld.source_digest, '') AS source_digest,
       COALESCE(ld.prompt_version, '') AS prompt_version
FROM packages m
LEFT JOIN localizations ld
  ON ld.resource_kind='package_description' AND ld.source_digest=m.description_digest AND ld.lang=$1
WHERE trim(m.description)<>''
UNION ALL
SELECT DISTINCT ON (mvs.description_digest) 'skill_description'::text,
       m.path || '@' || mv.version || ':' || mvs.path, mvs.description, mvs.description_digest,
       COALESCE(ld.source_digest, ''), COALESCE(ld.prompt_version, '')
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
LEFT JOIN localizations ld
  ON ld.resource_kind='skill_description' AND ld.source_digest=mvs.description_digest AND ld.lang=$1
WHERE trim(mvs.description)<>''
ORDER BY resource_kind, resource_id;

-- name: DocumentTranslationCandidates :many
WITH documents AS (
  SELECT mvs.document_digest,
         bool_or(m.current_version_id=mvs.version_id) AS is_current
  FROM skills mvs
  JOIN versions mv ON mv.id=mvs.version_id
  JOIN packages m ON m.id=mv.package_id
  WHERE mvs.document_digest<>''
  GROUP BY mvs.document_digest
)
SELECT documents.document_digest,
       COALESCE(l.source_digest,'') AS source_digest,COALESCE(l.prompt_version,'') AS stored_prompt_version
FROM documents
LEFT JOIN localizations l
  ON l.resource_kind='skill_document' AND l.source_digest=documents.document_digest AND l.lang=$1
WHERE l.source_digest IS NULL OR l.prompt_version<>sqlc.arg(target_prompt_version)
ORDER BY documents.is_current DESC,documents.document_digest
LIMIT sqlc.arg(page_limit);

-- name: SearchLocalizedSkills :many
SELECT mvs.version_id AS id, mv.package_id, m.path AS package_path,
       mvs.name, COALESCE(ls.text_content,mvs.description) AS description,
       m.source_host, m.source_path AS source_repository, mvs.path,
       mv.version AS latest_version, m.stars,
       mv.created_at, m.updated_at
FROM packages m
JOIN versions mv ON mv.id=m.current_version_id
JOIN skills mvs ON mvs.version_id=mv.id
LEFT JOIN localizations ls
  ON ls.resource_kind='skill_description' AND ls.source_digest=mvs.description_digest AND ls.lang=sqlc.arg(lang) AND ls.result_kind='translated'
LEFT JOIN localizations lm
  ON lm.resource_kind='package_description' AND lm.source_digest=m.description_digest AND lm.lang=sqlc.arg(lang) AND lm.result_kind='translated'
WHERE (sqlc.arg(exact_name)::boolean AND lower(mvs.name)=lower(sqlc.arg(query)))
OR (NOT sqlc.arg(exact_name)::boolean AND (
    lower(mvs.name) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(mvs.description) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(m.path) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(COALESCE(ls.text_content,'')) LIKE '%' || lower(sqlc.arg(query)) || '%'
    OR lower(COALESCE(lm.text_content,'')) LIKE '%' || lower(sqlc.arg(query)) || '%'
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
           mvs.name, COALESCE(ls.text_content,mvs.description) AS description,
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
    LEFT JOIN localizations ls
      ON ls.resource_kind='skill_description' AND ls.source_digest=mvs.description_digest AND ls.lang=sqlc.arg(lang) AND ls.result_kind='translated'
    LEFT JOIN localizations lm
      ON lm.resource_kind='package_description' AND lm.source_digest=m.description_digest AND lm.lang=sqlc.arg(lang) AND lm.result_kind='translated'
    WHERE (
        input.package_path<>'' AND m.path=input.package_path AND mvs.name=input.query
    ) OR (
        input.package_path='' AND (
            (input.exact_name AND lower(mvs.name)=lower(input.query))
            OR (NOT input.exact_name AND (
                lower(mvs.name) LIKE '%' || lower(input.query) || '%'
                OR lower(mvs.description) LIKE '%' || lower(input.query) || '%'
                OR lower(m.path) LIKE '%' || lower(input.query) || '%'
                OR lower(COALESCE(ls.text_content,'')) LIKE '%' || lower(input.query) || '%'
                OR lower(COALESCE(lm.text_content,'')) LIKE '%' || lower(input.query) || '%'
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
           COALESCE(ls.text_content,mvs.description) AS description,
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
    LEFT JOIN localizations ls
      ON ls.resource_kind='skill_description' AND ls.source_digest=mvs.description_digest AND ls.lang=sqlc.arg(lang) AND ls.result_kind='translated'
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
