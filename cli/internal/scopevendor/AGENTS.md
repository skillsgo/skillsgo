# Scope Vendor Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `transaction.go`: verifies and prepares one complete Repository Artifact as an ordinary-file Scope Vendor plus deterministic per-Agent Repository Projections, baseline-checks controlled replacements, then commits, finalizes, or rolls back owned paths.
- `vendor.go`: verifies an authoritative coordinate Vendor against its locked Repository Sum and reconstructs the canonical Repository ZIP for offline projection changes without inferring publication membership.
- `transaction_test.go`: specifies full-tree Vendor retention, root/nested selective visibility, ordinary-file portability, idempotency, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.

## Architectural Boundary

This module owns filesystem-safe Repository Vendor extraction, locked Vendor verification, and deterministic Agent Projection construction/replacement/removal. It accepts already resolved immutable Repository identity and explicit membership/selection; it must not contact Hub, parse Workspace YAML, infer Agent choices, overwrite Local Modifications, create symlinks, or update dependency declarations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
