# Hub Actions Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `app.go`, `app_test.go`: assemble the native Fiber application, middleware lifecycle, and top-level wiring coverage.
- `app_proxy.go`, `app_proxy_test.go`: compose source, storage, Catalog, discovery/detail, and immutable artifact protocol routes through Fiber and cover integration behavior.
- `auth.go`, `basicauth.go`, `basicauth_test.go`: configure access-control middleware and Basic Auth behavior.
- `catalog.go`: wires Catalog lifecycle and dependencies into the service.
- `catalog_api.go`, `catalog_api_test.go`: define and specify the stable public discovery, exact content-match, auditable artifact detail, pagination, ranking, and install-event JSON contract against SQLite.
- `catalog_postgres_integration_test.go`: verifies pagination and empty discovery response parity through the same HTTP router against PostgreSQL.
- `catalog_protocol.go`, `catalog_protocol_test.go`: index immutable artifact metadata and bind audited Risk plus Content Digest to exact Info responses.
- `repository_protocol.go`: aggregates exact per-Skill Info into self-contained immutable Repository Info on bare coordinates.
- `repository_publisher.go`: coordinates cold one-snapshot Repository discovery, immutable member storage, and Catalog visibility.
- `repository_metadata.go`: reads best-effort GitHub repository popularity metadata without making artifact availability depend on GitHub's API.
- `health.go`, `readiness.go`: expose service health and readiness probes.
- `home.go`, `robots.go`, `version.go`: serve the human landing, crawler policy, and service version surfaces.
- `index.go`, `index_test.go`: assemble the configured module index behavior.
- `storage.go`: wires artifact storage providers into the service.

## Architectural Boundary

This module owns native Fiber HTTP/service composition and stable public protocol serialization. It delegates metadata behavior to `pkg/catalog`, immutable artifacts to protocol/storage packages, and configuration to `pkg/config`; it must not duplicate their domain logic, expose database-specific response shapes, or introduce standard-library handler adapters inside the application request path.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
