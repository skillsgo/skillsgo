# Scope Package Store Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `transaction.go`: verifies and prepares one complete Package Artifact as a symlink-safe Scope Package Store plus stable canonical-name Agent Skill links, migrates legacy coordinate projections, baseline-checks replacements/removals, accepts narrowly explicit reviewed-conflict replacement authorization, then commits, finalizes, or rolls back owned paths.
- `package.go`: verifies an authoritative coordinate Package Store including safe internal symlinks against its locked Package Sum, reconstructs the canonical Package ZIP, and verifies direct Agent Skill links against immutable members.
- `transaction_test.go`: specifies full-tree Package Store retention, direct canonical-name Skill links, Package-relative resource preservation, idempotency, legacy migration, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.

## Architectural Boundary

This module owns filesystem-safe Package Store extraction, locked Package Store verification, and deterministic direct Agent Skill link construction/replacement/removal. It accepts already resolved immutable Package identity, canonical member names, explicit membership/selection, and an explicit caller-owned replacement authorization; it must not contact Hub, parse Workspace YAML, infer Agent choices, overwrite Local Modifications without that authorization, link outside the current Scope Package Store, or update dependency declarations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
