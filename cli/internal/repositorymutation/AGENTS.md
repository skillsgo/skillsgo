# Repository Mutation Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `mutation.go`: owns ordered commit, immutable pre-publication writes, Workspace state publication, reverse rollback, and post-commit cleanup for one Repository dependency mutation.
- `mutation_test.go`: specifies commit ordering, reverse filesystem rollback, Workspace publication failure, and cleanup error semantics.

## Architectural Boundary

This module owns the local commit state machine shared by Repository add, update, remove, restore, and takeover-through-add. It coordinates already prepared filesystem transactions, immutable Info cache writes, and paired Workspace publication, but must not resolve Hub selectors, choose Skills or Agents, or construct Scope Vendor projections. Reverse rollback applies to prepared filesystem transactions; immutable cache writes are safe idempotent residue.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
