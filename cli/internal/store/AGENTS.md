# Content-addressed Store Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `store.go`: validates immutable artifact identity and extracted content on read, confines entries beneath the Store root, extracts archives safely, persists provenance-aware receipts, and refreshes risk assessment metadata without changing content or provenance.
- `local.go`: imports reviewed private Local Skill directories as immutable Store entries and exports only Local-provenance entries without network access.
- `store_test.go`: specifies immutable/idempotent Hub and Local storage, export, risk-only assessment refresh, local-tamper and content-digest rejection, archive and Skill ID traversal defense, and exact retrieval.

## Architectural Boundary

This module owns immutable local artifact persistence beneath the configured Content-addressed Store. It must not resolve user intent, mutate Agent target directories, or trust source-derived paths without validation and containment checks.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
