# Installation Vocabulary Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `scope.go`: defines User/Workspace installation scopes and validates path-safe Skill names used by takeover locks.
- `state_digest.go`: computes deterministic filesystem state tokens for External takeover/removal review binding.

## Architectural Boundary

This module owns only minimal vocabulary shared by Repository and External workflows. Repository ordinary-file Vendor/Projection mutation belongs to `scopevendor`; this module must not materialize Skills, create links, persist state, fetch Hub artifacts, or infer App policy.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
