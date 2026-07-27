# Scope Package Store Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `transaction.go`: verifies and prepares one complete Package Artifact as a symlink-safe Scope Package Store plus deterministic per-Agent Package Projections, baseline-checks controlled replacements/removals including complete dependency deletion, then commits, finalizes, or rolls back owned paths.
- `package.go`: verifies an authoritative coordinate Package Store including safe internal symlinks against its locked Package Sum, reconstructs the canonical Package ZIP, and read-only compares selected-member Projections against immutable membership without inferring publication membership.
- `transaction_test.go`: specifies full-tree Package Store retention, safe internal symlink restoration, root/nested selective visibility, idempotency, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.

## Architectural Boundary

This module owns filesystem-safe Package Store extraction, locked Package Store verification, and deterministic Agent Projection construction/replacement/removal. It accepts already resolved immutable Package identity and explicit membership/selection; it must not contact Hub, parse Workspace YAML, infer Agent choices, overwrite Local Modifications, create symlinks that resolve outside the current Package, or update dependency declarations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
