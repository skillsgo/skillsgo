# Hub Actions Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `app.go`, `app_test.go`, `app_postgres_integration_test.go`: assemble and verify the native Fiber application, River or synchronous task runtime, periodic business tasks, PostgreSQL boot/restart with queued-job recovery, middleware lifecycle, and top-level wiring.
- `background_tasks.go`, `background_tasks_test.go`: define and verify first-class River JobArgs, stable observable kinds, payload validation, timeout behavior, and domain-handler adapters for Source Repository metadata and translation.
- `app_proxy.go`, `app_proxy_test.go`: compose source, storage, Catalog, discovery/detail, OpenAPI, and immutable artifact protocol routes through Fiber and cover integration behavior.
- `basicauth.go`, `basicauth_test.go`, `admin_auth_test.go`: configure global versus administration-scoped HTTP Basic Auth behavior; source publication remains credential-free while GitHub tokens are metadata-API-only.
- `catalog.go`: wires Catalog lifecycle and dependencies into the service.
- `catalog_api.go`, `catalog_api_test.go`: expose `GET /api/v1/skills/find` with zero-based page/per-page requests, greedy one-extra-row has-more responses, and optional Package summary projection after CLI-owned explicit-source resolution; also own dedicated candidate Find, exact-path ordered batch-card hydration, and latest update checks with correlated private diagnostics.
- `openapi.go`, `api_operations.go`, `api_examples.go`, `openapi_test.go`, `assets/`: use Huma as a typed OpenAPI 3.1 projection over native Fiber handlers, derive non-cacheable component schemas from Hub and Protocol DTOs, provide coherent real-world mattpocock/skills examples, guard product-route coverage, serve a self-hosted Scalar reference with compressed immutable assets, honor deployment prefixes, and prevent legacy route names from returning to the document.
- `skill_card_projection.go`: owns ordered Catalog-to-public Skill-card projection, shared trust/image mapping, localized search-card composition, and opportunistic stale Repository metadata refresh used by thin HTTP handlers.
- `info.go`: exposes the minimal public deployment mode and optional Cloud origin declared by validated Hub configuration.
- `catalog_postgres_integration_test.go`: verifies pagination and empty discovery response parity through the same HTTP router against PostgreSQL.
- `package_protocol.go`: serves persisted Package Info and ZIP resources on canonical Package Paths, triggers exact cold publication, rejects nested Skill artifact coordinates, and reports publication-cache decisions.
- `package_skill.go`: serves one exact Skill path under a canonical Package Version, resolves movable queries to immutable versions, and independently overlays localized description and display-document projections when `lang` is present.
- `package_publisher.go`: validates one complete Package Artifact, computes description/document digests and source language once at publication, prepares typed immutable Package Info plus content-addressed Skill source objects, coordinates bounded and negative-cached Source Repository work, and notifies best-effort metadata enrichment after current publication.
- `package_publication_commit.go`: owns retry-safe immutable Artifact then content-addressed Skill-source residency followed by atomic Catalog visibility, retaining failed-publication orphans for safe later residency GC instead of racing with concurrent publishers.
- `module_version_query.go`, `module_version_query_test.go`: resolve typed movable Version Queries once into immutable Package Version Records through the Package-scoped query API.
- `package_backfill.go`, `package_backfill_test.go`, `package_backfill_postgres_integration_test.go`: validate and expose bounded `/api/v1/admin/package-backfills` batches, persist one independent Run per Package, execute deterministic semantic-version history through River, retain bounded diagnostics, and verify transactional restart/multi-instance behavior.
- `repository_metadata.go`, `repository_metadata_test.go`: route Repository About descriptions and popularity metadata by source host, attempt initial enrichment without blocking publication success, serve stale Catalog state while submitting durable metadata refresh work, share TTL/ETag/Singleflight/backoff state, and implement sticky GitHub-token failover plus safe diagnostics without making request availability depend on a provider API.
- `health.go`, `readiness.go`: expose service health and readiness probes.
- `home.go`, `robots.go`, `version.go`: serve the human landing, crawler policy, and service version surfaces.
- `storage.go`, `storage_test.go`: wire artifact storage providers into the service, including first-class Cloudflare R2 configuration through the shared S3-compatible backend.

## Architectural Boundary

This module owns native Fiber HTTP/service composition and stable public protocol serialization. Shared wire DTOs belong to `/protocol/api`; this module delegates metadata behavior to `pkg/catalog`, immutable artifacts to Protocol/storage packages, and configuration to `pkg/config`. It must not duplicate their domain logic, expose database-specific response shapes, or introduce standard-library handler adapters inside the application request path.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
