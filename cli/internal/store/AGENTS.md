# Content-addressed Store Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `store.go`: validates immutable artifact identity and extracted content on read, confines coordinate metadata beneath the Store root, extracts archives safely, publishes entries under per-version exclusion, persists Info-defined names in provenance-aware receipts, and refreshes risk assessment metadata without changing content or provenance.
- `cas.go`: publishes read-only Hub artifact trees once under an h1-plus-envelope object key, resolves bounded coordinate references, and preserves executable-mode and empty-directory distinctions that h1 intentionally excludes.
- `gc.go`: discovers all coordinate-to-object references inside the Store and dry-runs or removes only grace-aged orphan Hub CAS objects under per-object locks.
- `entry_lock.go`: provides bounded operating-system locks for coordinate and CAS-object publication.
- `local.go`: imports reviewed private Local Skill directories, captures stable source-identified takeover baselines whose identity includes content, modes, and empty directories, and exports only Local-provenance entries without network access.
- `store_test.go`: specifies immutable/idempotent Hub, Local, and captured storage, CAS sharing and garbage collection, full source/content/filesystem-state identity, export, risk-only assessment refresh, local-tamper and Sum rejection, archive and Skill ID traversal defense, and exact retrieval.

## Architectural Boundary

This module owns immutable local artifact persistence beneath the configured Content-addressed Store. Hub coordinates may share one verified read-only object only when both h1 content and envelope state match; private Local and Captured entries remain coordinate-owned so provenance and exact takeover state cannot be collapsed. It must not resolve user intent, mutate Agent target directories, or trust source-derived paths without validation and containment checks.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
