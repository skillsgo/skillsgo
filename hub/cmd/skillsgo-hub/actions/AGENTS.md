# Hub Actions Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `app.go`, `app_test.go`: assemble the native Fiber application, middleware lifecycle, and top-level wiring coverage.
- `app_proxy.go`, `app_proxy_test.go`: compose source, storage, Catalog, discovery/detail, and immutable artifact protocol routes through Fiber and cover integration behavior.
- `auth.go`, `basicauth.go`, `basicauth_test.go`: configure access-control middleware and Basic Auth behavior.
- `catalog.go`: wires Catalog lifecycle and dependencies into the service.
- `catalog_api.go`, `catalog_api_test.go`: define and specify the stable public discovery, exact content-match, auditable artifact detail, pagination, ranking, and install-event JSON contract against SQLite while retaining correlated private diagnostics for safe public failures.
- `catalog_postgres_integration_test.go`: verifies pagination and empty discovery response parity through the same HTTP router against PostgreSQL.
- `catalog_protocol.go`, `catalog_protocol_test.go`: index immutable artifact metadata and bind audited Risk plus Content Digest to exact Info responses.
- `repository_protocol.go`: aggregates exact flat per-Skill Info into self-contained immutable Repository Info with one shared Ref, Commit SHA, and batch version on bare coordinates, and reports publication-cache decisions.
- `repository_publisher.go`: coordinates and logs cold one-snapshot Repository discovery, immutable conflict preflight, bounded/negative-cached upstream work, rollback, and transactional Catalog visibility.
- `repository_metadata.go`, `repository_metadata_test.go`: route Repository metadata by source host, share TTL/ETag/Singleflight/stale/backoff state through the Catalog, and implement GitHub-specific reads plus safe diagnostics without making artifact availability depend on a provider API.
- `health.go`, `readiness.go`: expose service health and readiness probes.
- `home.go`, `robots.go`, `version.go`: serve the human landing, crawler policy, and service version surfaces.
- `index.go`, `index_test.go`: assemble the configured module index behavior.
- `storage.go`: wires artifact storage providers into the service.

## Architectural Boundary

This module owns native Fiber HTTP/service composition and stable public protocol serialization. It delegates metadata behavior to `pkg/catalog`, immutable artifacts to protocol/storage packages, and configuration to `pkg/config`; it must not duplicate their domain logic, expose database-specific response shapes, or introduce standard-library handler adapters inside the application request path.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
