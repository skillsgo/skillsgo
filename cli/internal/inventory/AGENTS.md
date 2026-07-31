# CLI Inventory Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `inventory.go`: composes Package-managed and External state, target health, local source evidence, and Discovery-Root-derived visibility into the mode-free inventory v8 Library report.
- `package_reconciliation.go`: resolves exact locked metadata through the read-through Provider, verifies Scope Package Trees and member-symlink Projections, and optionally reacquires content for explicit verification commands.
- `visibility_test.go`: specifies Discovery-Root-derived Agent visibility without introducing managed targets or persisted visibility state.
- `external.go`: discovers path-identified External Installations and safe physical aliases through read-only scans of installed Agents' known Discovery Roots and explicit project roots.
- `external_provenance.go`: resolves bounded offline skills.sh lock, ClawHub origin, and Skill-root Git evidence into confirmed, import-only, conflict, or unknown External source records.
- `external_provenance_test.go`: specifies source normalization, channel-only imports, conflicts, unknown state, scope-aware locks, and credential-safe deterministic evidence.

## Architectural Boundary

This module owns Library reconciliation and stable inventory records. It may request exact locked metadata or verification content through the Package Provider and inspect declarations, locks, Scope Package Trees, Projections, and known Agent directories; it must not mutate Skill content, resolve movable versions, or serialize localized CLI output.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
