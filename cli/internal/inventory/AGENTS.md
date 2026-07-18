# CLI Inventory Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `inventory.go`: reconciles user/project declarations, locks, Store artifacts, local manifest descriptions, known Agent target paths, target health, copy-mode Local Modifications, and Discovery-Root-derived visibility into the inventory v5 Library report.
- `health_test.go`: specifies canonical and Agent-projection health classification, including legacy Store-direct links and damaged filesystem states.
- `visibility_test.go`: specifies Discovery-Root-derived Agent visibility without introducing managed targets or persisted visibility state.
- `external.go`: discovers path-identified External Installations and their manifest names/descriptions through read-only scans of installed Agents' known directories and explicit project roots.

## Architectural Boundary

This module owns read-only Library reconciliation and stable inventory domain records. It may inspect only user/project declarations, locks, canonical Store artifact metadata, and known Agent directories; it must not mutate Skill content, contact a Hub, or serialize localized CLI output.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
