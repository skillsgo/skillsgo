# Registry Catalog Module
> F3 | Parent: `/registry/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/registry`

## Members

- `catalog.go`: owns SQLite/PostgreSQL metadata persistence, full-text discovery, install aggregation, pagination, and ranking queries.
- `catalog_test.go`: specifies the SQLite behavior contract, including canonical identity, search fields, pagination, and ranking windows.
- `postgres_integration_test.go`: verifies the same discovery and aggregation contract against an opt-in real PostgreSQL service.

## Architectural Boundary

This module owns searchable public Skill metadata and aggregate install statistics. It must not store artifact bytes, render HTTP responses, inspect local installations, or depend on App presentation concepts. Search and ranking queries must preserve equivalent public semantics across SQLite and PostgreSQL.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
