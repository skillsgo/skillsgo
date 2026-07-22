# Hub Actions Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `app.go`, `app_test.go`, `app_postgres_integration_test.go`: assemble and verify the native Fiber application, River or synchronous task runtime, periodic business tasks, PostgreSQL boot/restart with queued-job recovery, middleware lifecycle, and top-level wiring.
- `background_tasks.go`, `background_tasks_test.go`: define and verify first-class River JobArgs, stable observable kinds, source/maintenance workload placement, payload validation, uniqueness fields, retry limits, and domain-handler adapters for artifact stash, Repository metadata/prewarm, and translation.
- `app_proxy.go`, `app_proxy_test.go`: compose source, storage, Catalog, discovery/detail, and immutable artifact protocol routes through Fiber and cover integration behavior.
- `basicauth.go`, `basicauth_test.go`, `admin_auth_test.go`: configure global versus administration-scoped HTTP Basic Auth behavior; source publication remains credential-free while GitHub tokens are metadata-API-only.
- `catalog.go`: wires Catalog lifecycle and dependencies into the service.
- `catalog_api.go`, `catalog_api_test.go`: expose stable public search, ordered batch Skill-card hydration, shared Protocol batch-update and content-match DTOs, immutable artifact detail, and pagination while retaining correlated private diagnostics for safe public failures.
- `info.go`: exposes the minimal public deployment mode and optional Cloud origin declared by validated Hub configuration.
- `catalog_postgres_integration_test.go`: verifies pagination and empty discovery response parity through the same HTTP router against PostgreSQL.
- `catalog_protocol.go`, `catalog_protocol_test.go`: index immutable artifact metadata and bind Sum to exact Info responses without placing deferred Risk/audit projections into authenticated bytes.
- `repository_protocol.go`: aggregates exact flat per-Skill Info into self-contained immutable Repository Info with one shared Ref, Commit SHA, and batch version on bare coordinates, and reports publication-cache decisions.
- `repository_publisher.go`: coordinates and logs cold one-snapshot Repository discovery, immutable conflict preflight, bounded/negative-cached upstream work, rollback, and transactional Catalog visibility.
- `repository_backfill.go`, `repository_backfill_test.go`, `repository_backfill_postgres_integration_test.go`: validate and expose bounded administration Backfill batches, persist one independent Run per Repository, execute deterministic semantic-version history through River, retain bounded diagnostics, and verify transactional restart/multi-instance behavior.
- `repository_metadata.go`, `repository_metadata_test.go`: route Repository About descriptions and popularity metadata by source host, serve stale Catalog state while submitting durable refresh and prewarm work, share TTL/ETag/Singleflight/backoff state, and implement sticky GitHub-token failover plus safe diagnostics without making request availability depend on a provider API.
- `health.go`, `readiness.go`: expose service health and readiness probes.
- `home.go`, `robots.go`, `version.go`: serve the human landing, crawler policy, and service version surfaces.
- `index.go`, `index_test.go`: assemble the configured module index behavior.
- `storage.go`: wires artifact storage providers into the service.

## Architectural Boundary

This module owns native Fiber HTTP/service composition and stable public protocol serialization. Shared wire DTOs belong to `/protocol/api`; this module delegates metadata behavior to `pkg/catalog`, immutable artifacts to Protocol/storage packages, and configuration to `pkg/config`. It must not duplicate their domain logic, expose database-specific response shapes, or introduce standard-library handler adapters inside the application request path.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
