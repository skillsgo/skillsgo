# Hub Catalog Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `catalog.go`: exposes the Catalog API, reusable Repository Release aggregate validation, Ent persistence, the shared PostgreSQL pgx pool, Repository-scoped source-metadata cache state, visibility-aware search, immutable Releases, ordered Skill membership, and pagination.
- `backfill.go`: owns durable Repository Backfill Run business state, active-work deduplication, heartbeat recovery for running work, River-aware orphan reconciliation candidates for queued work, state transitions, bounded diagnostics, exact-publication commit checks, and atomic PostgreSQL Run-plus-River enqueue scopes.
- `migrations.go`: executes embedded, checksummed, ordered Atlas SQL migrations and serializes PostgreSQL migration runs.
- `migrations/`: contains reviewed, checksummed migrations per database, including the pre-release baseline, Historical Publication visibility, Backfill Run state, Repository metadata evolution, the destructive legacy-history reset for the h1 Sum cutover, and database-specific full-text search resources.
- `migrate/main.go`: authors named Ent/Atlas schema diffs against disposable development databases.
- `pgxent/`: adapts caller-owned native pgx transactions to generated Ent clients so domain writes and River enqueueing can share one transaction; application code must enter through `Catalog.WithPostgresTx` or `Catalog.WithPostgresTxOptions` rather than constructing transaction ownership ad hoc.
- `ent/schema/`: defines the authoritative Ent entity model, including presentation-only localized descriptions and Skill membership versions with Repository-relative paths but no duplicated artifact fields; generated siblings under `ent/` are reproducible build output.
- `catalog_test.go`: specifies the SQLite behavior contract, including migration history, Repository ID plus Skill Name identity, downstream assessment persistence, search fields, and pagination.
- `postgres_integration_test.go`: verifies search and downstream assessment persistence against an opt-in real PostgreSQL service.

## Architectural Boundary

This module owns searchable public Skill metadata, provider-neutral Repository metadata cache state, and schema evolution. Ent Schema is the structural source of truth; versioned SQL is the reviewed deployment artifact, with explicit dialect SQL reserved for search capabilities. It must not own install events, aggregate rankings, artifact bytes, HTTP rendering, local installation inspection, or App presentation concepts. Search must preserve equivalent public semantics across SQLite and PostgreSQL.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
