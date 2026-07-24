# Hub Catalog Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `catalog.go`: exposes the Catalog API, reusable Repository Release aggregate validation, the shared PostgreSQL pgx pool, Repository-scoped source-metadata cache state, name-first locale-consistent Find with optional exact-name restriction, immutable Releases, ordered Skill membership, and pagination.
- `backfill.go`: owns durable Repository Backfill Run business state, active-work deduplication, heartbeat recovery for running work, River-aware orphan reconciliation candidates for queued work, state transitions, bounded diagnostics, exact-publication commit checks, and atomic PostgreSQL Run-plus-River enqueue scopes.
- `migrations.go`: executes embedded, checksummed, ordered Atlas SQL migrations and serializes PostgreSQL migration runs.
- `migrations/postgres/`: contains the reviewed, checksummed Atlas migration history, including immutable Repository Releases, complete Release membership, Backfill Run state, Repository metadata, localized descriptions, and PostgreSQL search resources.
- `queries/`: contains the maintained sqlc query source; SQL used by Catalog business operations belongs here except connection-scoped PostgreSQL advisory locks.
- `catalogsqlc/`: contains reproducible sqlc-generated pgx/v5 query code and must not be edited manually.
- `catalog_test.go`, `postgres_integration_test.go`: specify the PostgreSQL behavior contract with Testcontainers, including migration history, Repository ID plus Skill Name logical coordinates, path-unique same-name metadata, deterministic coordinate defaults, immutable Release ownership, historical membership, current projection, Find ordering/fields, and pagination.
- `postgres_integration_test.go`: verifies Repository Release publication and current-member lookup against real PostgreSQL.

## Architectural Boundary

This module owns searchable public Skill metadata, immutable Repository Release records and membership, provider-neutral Repository metadata cache state, and schema evolution. Repository is the version and artifact boundary; a Skill row must not own a version, Sum, ZIP, or independent release lifecycle. PostgreSQL Atlas migrations are the schema source of truth, sqlc queries are the maintained data-access source, and pgx is the only runtime database interface. Catalog and River share the same pool and caller-owned pgx transaction where atomicity is required. It must not own install events, aggregate rankings, risk assessments, artifact bytes, HTTP rendering, local installation inspection, or App presentation concepts.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
