# Content-addressed Store Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `store.go`: validates immutable artifact identity and extracted content on read, confines entries beneath the Store root, extracts archives safely, publishes entries under per-version exclusion, persists Info-defined names in provenance-aware receipts, and refreshes risk assessment metadata without changing content or provenance.
- `entry_lock.go`: provides the per-entry cross-process lock and stale-lock recovery used for lock-after-check immutable publication.
- `local.go`: imports reviewed private Local Skill directories, captures stable source-identified takeover baselines whose identity includes content, modes, and empty directories, and exports only Local-provenance entries without network access.
- `store_test.go`: specifies immutable/idempotent Hub, Local, and captured storage, full source/content/filesystem-state identity, export, risk-only assessment refresh, local-tamper and Sum rejection, archive and Skill ID traversal defense, and exact retrieval.

## Architectural Boundary

This module owns immutable local artifact persistence beneath the configured Content-addressed Store. It must not resolve user intent, mutate Agent target directories, or trust source-derived paths without validation and containment checks.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
