# CLI Inventory Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `inventory.go`: reconciles Registry/Local managed receipts, explicit Workspace declarations, known Agent target paths, target health, and copy-mode Local Modifications into the stable Library report.
- `external.go`: discovers path-identified External Installations through read-only scans of installed Agents' known directories and explicit project roots.

## Architectural Boundary

This module owns read-only Library reconciliation and stable inventory domain records. It may inspect only canonical Store receipts, explicit Workspace state, and known Agent directories; it must not mutate Skill content, create receipts, contact a Registry, or serialize localized CLI output.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
