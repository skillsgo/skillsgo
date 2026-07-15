# Registry Actions Module
> F3 | Parent: `/registry/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/registry`

## Members

- `app.go`, `app_test.go`: assemble the Registry HTTP application and cover top-level wiring.
- `app_proxy.go`, `app_proxy_test.go`: wire the inherited artifact proxy surface and its integration behavior.
- `auth.go`, `basicauth.go`, `basicauth_test.go`: configure access-control middleware and Basic Auth behavior.
- `catalog.go`: wires Catalog lifecycle and dependencies into the service.
- `catalog_api.go`, `catalog_api_test.go`: define and specify the stable public discovery, detail, pagination, ranking, and install-event JSON contract against SQLite.
- `catalog_postgres_integration_test.go`: verifies pagination and empty discovery response parity through the same HTTP router against PostgreSQL.
- `catalog_protocol.go`, `catalog_protocol_test.go`: index immutable artifact metadata after successful protocol resolution.
- `health.go`, `readiness.go`: expose service health and readiness probes.
- `home.go`, `robots.go`, `version.go`: serve the human landing, crawler policy, and service version surfaces.
- `index.go`, `index_test.go`: assemble the configured module index behavior.
- `storage.go`: wires artifact storage providers into the service.

## Architectural Boundary

This module owns HTTP/service composition and stable public protocol serialization. It delegates metadata behavior to `pkg/catalog`, immutable artifacts to protocol/storage packages, and configuration to `pkg/config`; it must not duplicate their domain logic or expose database-specific response shapes.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
