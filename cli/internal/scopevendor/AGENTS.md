# Scope Vendor Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `transaction.go`: verifies and prepares one complete Repository Artifact as an ordinary-file Scope Vendor plus deterministic per-Agent Repository Projections, then commits or rolls back only paths created by that transaction.
- `transaction_test.go`: specifies full-tree Vendor retention, selected-Skill visibility, ordinary-file portability, idempotency, Local Modification refusal, and rollback.

## Architectural Boundary

This module owns filesystem-safe Repository Vendor extraction and deterministic Agent Projection construction. It accepts already resolved immutable Repository identity and explicit membership/selection; it must not contact Hub, parse Workspace YAML, infer Agent choices, overwrite Local Modifications, create symlinks, or update dependency declarations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
