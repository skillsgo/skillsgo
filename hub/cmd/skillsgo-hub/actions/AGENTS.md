# Hub Actions Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `app.go`, `app_runtime.go`, `app_test.go`, `app_postgres_integration_test.go`: express and verify native Fiber top-level assembly, reverse-order idempotent ownership of isolated foreground/background PostgreSQL Catalog pools and the River or synchronous task runtime, PostgreSQL boot/restart with queued-job recovery, middleware lifecycle, and failure rollback.
- `background_tasks.go`, `background_tasks_test.go`: define and verify first-class River JobArgs, stable observable kinds, payload validation, dispatcher versus single-localization timeout behavior, and domain-handler adapters for Source Repository metadata and translation.
- `translation_jobs.go`: assembles translation workers and registers description/document dispatch, execution, terminal failure handling, and periodic scheduling outside the top-level App flow.
- `app_proxy.go`, `app_proxy_test.go`: compose source discovery, Artifact Store, Catalog, OpenAPI, Package metadata, and Skill-content routes through Fiber and cover integration behavior.
- `basicauth.go`, `basicauth_test.go`, `admin_auth_test.go`: configure global versus administration-scoped HTTP Basic Auth behavior; source publication remains credential-free while GitHub tokens are metadata-API-only.
- `catalog_api.go`, `catalog_api_test.go`: expose `GET /api/v1/skills/find` with zero-based page/per-page requests, greedy one-extra-row has-more responses, and language-localized immutable Package Publication projection with source-description fallback after CLI-owned explicit-source resolution; ordinary search remains current-Catalog-only. They also own source-description-by-default candidate Find with optional presentation localization, exact-path ordered batch-card hydration, set-based Catalog-only Package update checks, and correlated private diagnostics.
- `openapi.go`, `api_operations.go`, `api_examples.go`, `openapi_test.go`, `assets/`: use Huma as a typed OpenAPI 3.1 projection over native Fiber handlers, derive non-cacheable component schemas from Hub and Protocol DTOs, provide coherent real-world mattpocock/skills examples, guard product-route coverage, serve a self-hosted Scalar reference with compressed immutable assets, honor deployment prefixes, and prevent legacy route names from returning to the document.
- `skill_card_projection.go`: owns ordered Catalog-to-public Skill-card projection, shared trust/image mapping, localized search plus exact-path batch-card composition, and opportunistic stale Repository metadata refresh used by thin HTTP handlers.
- `info.go`: exposes the minimal public deployment mode and optional Cloud origin declared by validated Hub configuration.
- `catalog_postgres_integration_test.go`: verifies pagination and empty discovery response parity through the same HTTP router against PostgreSQL.
- `package_protocol.go`: merges Catalog publication history with source Tags, serves Catalog-built Package Info with static Git Artifact Repository URLs, triggers exact cold publication, and rejects nested Skill artifact coordinates.
- `package_skill.go`: serves one exact Skill path under a canonical Package Version, resolves movable queries to immutable versions, and independently overlays localized description and display-document projections when `lang` is present.
- `package_publisher.go`: validates one complete Package Artifact, computes description/document digests and source language once at publication, prepares typed immutable Package Info plus content-addressed Skill source objects, coordinates bounded and negative-cached Source Repository work, and notifies best-effort metadata enrichment after current publication.
- `package_publication_commit.go`, `package_publication_commit_test.go`: own retry-safe Git Repository then content-addressed Skill-source residency followed by atomic Catalog visibility, using the advisory-lock connection for the publication transaction and retaining failed-publication orphans for later residency GC.
- `module_version_query.go`, `module_version_query_test.go`: resolve typed movable Version Queries once into immutable Package Version Records through the Package-scoped query API.
- `package_backfill.go`, `package_backfill_test.go`: validate and expose bounded `/api/v1/admin/package-backfills` batches, persist one independent Run per Package, execute at most twenty highest semantic Tags or no-Tag recent default-branch pseudo-versions through River, and retain bounded diagnostics.
- `repository_metadata.go`, `repository_metadata_test.go`: route Repository About descriptions and popularity metadata by source host, attempt initial enrichment without blocking publication success, serve stale Catalog state while submitting durable metadata refresh work, share TTL/ETag/Singleflight/backoff state, and implement sticky GitHub-token failover plus safe diagnostics without making request availability depend on a provider API.
- `health.go`, `readiness.go`: expose service health and readiness probes.
- `home.go`, `robots.go`, `version.go`: serve the human landing, crawler policy, and service version surfaces.
- `storage.go`, `storage_test.go`: wire artifact storage providers into the service, including first-class Cloudflare R2 configuration through the shared S3-compatible backend.

## Architectural Boundary

This module owns native Fiber HTTP/service composition and stable public protocol serialization. Shared wire DTOs belong to `/protocol/api`; this module delegates metadata behavior to `pkg/catalog`, immutable artifacts to Protocol/storage packages, and configuration to `pkg/config`. It must not duplicate their domain logic, expose database-specific response shapes, or introduce standard-library handler adapters inside the application request path.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
