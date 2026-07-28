# Managed Scope Registry Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `registry.go`: owns the user-level, atomic, deterministic registry of explicitly managed Workspace roots.
- `registry_test.go`: specifies canonicalization, idempotent registration, removal, and stable persistence.

## Architectural Boundary

This module owns explicit Managed Workspace identity for cross-Scope CLI operations and App Added Projects. It must not scan for Workspaces, inspect Package declarations, mutate Workspace state, or own App presentation metadata.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
