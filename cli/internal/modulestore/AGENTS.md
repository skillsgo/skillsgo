# Scope Module Store Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `transaction.go`: verifies and prepares one complete Module Artifact as a symlink-safe Scope Module Store plus deterministic per-Agent Module Projections, baseline-checks controlled replacements/removals including complete dependency deletion, then commits, finalizes, or rolls back owned paths.
- `module.go`: verifies an authoritative coordinate Module Store including safe internal symlinks against its locked Module Sum, reconstructs the canonical Module ZIP, and read-only compares selected-member Projections against immutable membership without inferring publication membership.
- `transaction_test.go`: specifies full-tree Module Store retention, safe internal symlink restoration, root/nested selective visibility, idempotency, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.

## Architectural Boundary

This module owns filesystem-safe Module Store extraction, locked Module Store verification, and deterministic Agent Projection construction/replacement/removal. It accepts already resolved immutable Module identity and explicit membership/selection; it must not contact Hub, parse Workspace YAML, infer Agent choices, overwrite Local Modifications, create symlinks that resolve outside the current Module, or update dependency declarations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
