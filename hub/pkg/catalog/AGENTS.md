# Hub Catalog Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `catalog.go`: exposes the Catalog API, uses Ent for entity persistence, owns the shared pgx pool in PostgreSQL mode, owns Repository-scoped source-metadata cache state, and provides visibility-aware discovery, immutable version, install aggregation, pagination, and ranking queries.
- `backfill.go`: owns durable Repository Backfill Run business state, active-work deduplication, heartbeat recovery for running work, River-aware orphan reconciliation candidates for queued work, state transitions, bounded diagnostics, exact-publication commit checks, and atomic PostgreSQL Run-plus-River enqueue scopes.
- `migrations.go`: executes embedded, checksummed, ordered Atlas SQL migrations and serializes PostgreSQL migration runs.
- `provider_sync.go`: owns crawl-generation fencing tokens, complete crawl snapshots, page checkpoints, and external counter observations beneath River scheduling.
- `provider_sync_test.go`: verifies stale-generation rejection, takeover cleanup, completed-window idempotency, and complete publication.
- `migrations/`: contains reviewed, checksummed migrations per database, including the pre-release baseline, Historical Publication visibility, Backfill Run state, Repository metadata evolution, the destructive legacy-history reset for the h1 Sum cutover, and database-specific full-text search resources.
- `migrate/main.go`: authors named Ent/Atlas schema diffs against disposable development databases.
- `pgxent/`: adapts caller-owned native pgx transactions to generated Ent clients so domain writes and River enqueueing can share one transaction; application code must enter through `Catalog.WithPostgresTx` or `Catalog.WithPostgresTxOptions` rather than constructing transaction ownership ad hoc.
- `ent/schema/`: defines the authoritative Ent entity model, including presentation-only localized descriptions; generated siblings under `ent/` are reproducible build output.
- `catalog_test.go`: specifies the SQLite behavior contract, including migration history, canonical Skill IDs, exact content matching, downstream assessment persistence, search fields, pagination, and ranking windows.
- `postgres_integration_test.go`: verifies discovery, downstream assessment persistence, and aggregation parity against an opt-in real PostgreSQL service.

## Architectural Boundary

This module owns searchable public Skill metadata, provider-neutral Repository metadata cache state, schema evolution, and aggregate install statistics. Ent Schema is the structural source of truth; versioned SQL is the reviewed deployment artifact, with explicit dialect SQL reserved for search and aggregation capabilities. The module must not store artifact bytes, render HTTP responses, inspect local installations, or depend on App presentation concepts. Search and ranking queries must preserve equivalent public semantics across SQLite and PostgreSQL.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
