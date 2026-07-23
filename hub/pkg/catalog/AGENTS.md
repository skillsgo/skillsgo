# Hub Catalog Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `catalog.go`: exposes the Catalog API, reusable Repository Release aggregate validation, Ent persistence, the shared PostgreSQL pgx pool, Repository-scoped source-metadata cache state, visibility-aware search, immutable Releases, ordered Skill membership, and pagination.
- `backfill.go`: owns durable Repository Backfill Run business state, active-work deduplication, heartbeat recovery for running work, River-aware orphan reconciliation candidates for queued work, state transitions, bounded diagnostics, exact-publication commit checks, and atomic PostgreSQL Run-plus-River enqueue scopes.
- `migrations.go`: executes embedded, checksummed, ordered Atlas SQL migrations and serializes PostgreSQL migration runs.
- `migrations/`: contains the reviewed, checksummed pre-release baseline for each database, including immutable Repository Releases, complete Release membership, Backfill Run state, Repository metadata, localized descriptions, and database-specific search resources.
- `migrate/main.go`: authors named Ent/Atlas schema diffs against disposable development databases.
- `pgxent/`: adapts caller-owned native pgx transactions to generated Ent clients so domain writes and River enqueueing can share one transaction; application code must enter through `Catalog.WithPostgresTx` or `Catalog.WithPostgresTxOptions` rather than constructing transaction ownership ad hoc.
- `ent/schema/`: defines the authoritative Ent entity model: Repository owns immutable Releases, each Release owns its complete ordered member set, Skill is the current searchable projection, and localized descriptions remain presentation-only; generated siblings under `ent/` are reproducible build output.
- `catalog_test.go`: specifies the SQLite behavior contract, including clean migration history, Repository ID plus Skill Name identity, immutable Release ownership, historical membership, current projection, search fields, and pagination.
- `postgres_integration_test.go`: verifies Repository Release publication and current-member lookup against an opt-in real PostgreSQL service.

## Architectural Boundary

This module owns searchable public Skill metadata, immutable Repository Release records and membership, provider-neutral Repository metadata cache state, and schema evolution. Repository is the version and artifact boundary; a Skill row must not own a version, Sum, ZIP, or independent release lifecycle. Ent Schema is the structural source of truth; versioned SQL is the reviewed deployment artifact, with explicit dialect SQL reserved for search capabilities. It must not own install events, aggregate rankings, risk assessments, artifact bytes, HTTP rendering, local installation inspection, or App presentation concepts. Search must preserve equivalent public semantics across SQLite and PostgreSQL.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
