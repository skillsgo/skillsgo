# CLI Inventory Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `inventory.go`: composes Repository-managed and External state, target health, and Discovery-Root-derived visibility into the mode-free inventory v6 Library report.
- `repository.go`: reconciles strict YAML/Lock dependencies, scoped immutable Repository Info, verified Vendor, deterministic Projections, selected Skill members, and Local Modifications without Hub access.
- `visibility_test.go`: specifies Discovery-Root-derived Agent visibility without introducing managed targets or persisted visibility state.
- `external.go`: discovers path-identified External Installations and safe physical aliases through read-only scans of installed Agents' known Discovery Roots and explicit project roots.

## Architectural Boundary

This module owns read-only Library reconciliation and stable inventory domain records. It may inspect only user/project Repository declarations and locks, immutable scoped Repository Info, Vendor/Projection state, and known Agent directories; it must not mutate Skill content, contact a Hub, or serialize localized CLI output.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
