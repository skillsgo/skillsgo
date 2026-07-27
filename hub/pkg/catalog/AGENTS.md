# Hub Catalog Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `catalog.go`: exposes the Catalog API, reusable Package Version aggregate validation, the shared schema-fixed PostgreSQL pgx pool with public extension fallback, Package-scoped source-metadata cache state, content-addressed global localization identity, name-first language-consistent Find, exact-path ordered batch hydration, immutable Versions, and ordered Skill membership with persisted source-language provenance.
- `backfill.go`: owns durable Package Backfill Run business state, active-work deduplication, heartbeat recovery for running work, River-aware orphan reconciliation candidates for queued work, state transitions, bounded diagnostics, exact-publication commit checks, and atomic PostgreSQL Run-plus-River enqueue scopes.
- `migrations.go`: installs shared PostgreSQL extension prerequisites in `public`, executes embedded checksummed Atlas SQL migrations in the configured application schema, and serializes migration runs.
- `migrations/postgres/`: contains the reviewed, checksummed Atlas migration history, including immutable Package Versions, complete Version membership and source-language provenance, Backfill Run state, Package metadata, presentation localization outcomes, and PostgreSQL search resources.
- `queries/`: contains the maintained sqlc query source; SQL used by Catalog business operations belongs here except connection-scoped PostgreSQL advisory locks.
- `catalogsqlc/`: contains reproducible sqlc-generated pgx/v5 query code and must not be edited manually.
- `catalog_test.go`, `postgres_integration_test.go`: specify the PostgreSQL behavior contract with Testcontainers, including the three-table baseline, Package Path plus Skill Name aggregation coordinates, path-unique same-name snapshots, deterministic name-query defaults, immutable Version ownership, historical membership, current projection, Find ordering/fields, and pagination.
- `postgres_integration_test.go`: verifies Package Version publication and current-member lookup against real PostgreSQL.

## Architectural Boundary

This module owns searchable public Skill metadata, immutable Package Version records and membership, provider-neutral Package metadata cache state, globally deduplicated presentation localization outcomes keyed by source digest, and schema evolution. `packages`, `versions`, and version-owned `skills` are the three core identity tables. A Package stores its canonical Path, Source Host, and host-relative Source Path; cross-entity projections expose that identity as Package Path. Package is the version and artifact boundary; a Skill snapshot belongs to one Version but has no independent version, Sum, ZIP, licensing metadata, or publication lifecycle. PostgreSQL Atlas migrations are the schema source of truth, sqlc queries are the maintained data-access source, and pgx is the only runtime database interface. The configured schema owns Catalog, River, and migration-history tables; database-level extension objects live in `public` and remain visible through the pool search path. Catalog and River share the same pool and caller-owned pgx transaction where atomicity is required. It must not own install events, aggregate rankings, artifact bytes, HTTP rendering, local installation inspection, or App presentation concepts.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
