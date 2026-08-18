# CLI Inventory Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `inventory.go`: composes Package-managed and External state, optional lock-backed Adoption hints, target health, Discovery-Root-derived visibility, and caller-supplied local usage totals with explicit pending and evidence-availability states into the mode-free inventory v8 Library report.
- `package_reconciliation.go`: resolves exact locked metadata through the read-through Provider, verifies Scope Package Trees and member-symlink Projections, and optionally reacquires content for explicit verification commands.
- `visibility_test.go`: specifies Discovery-Root-derived Agent visibility without introducing managed targets or persisted visibility state.
- `usage_test.go`: specifies unique Agent-visible usage attribution and evidence availability without assigning ambiguous same-name evidence to multiple entries.
- `external.go`: discovers path-identified External Installations and safe physical aliases through read-only scans of installed Agents' known Discovery Roots and explicit project roots.
- `external_adoption.go`: reads bounded supported skills.sh global and Workspace locks plus per-Skill ClawHub origin records, then attaches one agreeing canonical Package hint for Adoption candidate prioritization without changing External ownership.

## Architectural Boundary

This module owns Library reconciliation and stable inventory records. It may request exact locked metadata or verification content through the Package Provider and inspect declarations, locks, Scope Package Trees, Projections, and known Agent directories; it must not mutate Skill content, resolve movable versions, or serialize localized CLI output.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
