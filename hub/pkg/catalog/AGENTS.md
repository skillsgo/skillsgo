# Hub Catalog Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `catalog.go`: exposes the Catalog API, uses Ent for entity persistence, and owns dialect-specific discovery, install aggregation, pagination, and ranking queries.
- `migrations.go`: executes embedded, checksummed, ordered Atlas SQL migrations and serializes PostgreSQL migration runs.
- `migrations/`: contains one reviewed pre-release baseline migration per database, including database-specific full-text search resources.
- `migrate/main.go`: authors named Ent/Atlas schema diffs against disposable development databases.
- `ent/schema/`: defines the authoritative Ent entity model; generated siblings under `ent/` are reproducible build output.
- `catalog_test.go`: specifies the SQLite behavior contract, including migration history, canonical Skill IDs, exact content matching, immutable audit evidence, search fields, pagination, and ranking windows.
- `postgres_integration_test.go`: verifies discovery, immutable audit persistence, and aggregation parity against an opt-in real PostgreSQL service.

## Architectural Boundary

This module owns searchable public Skill metadata, schema evolution, and aggregate install statistics. Ent Schema is the structural source of truth; versioned SQL is the reviewed deployment artifact, with explicit dialect SQL reserved for search and aggregation capabilities. The module must not store artifact bytes, render HTTP responses, inspect local installations, or depend on App presentation concepts. Search and ranking queries must preserve equivalent public semantics across SQLite and PostgreSQL.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
