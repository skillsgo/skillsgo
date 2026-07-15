# Installation Materialization Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `installer.go`: materializes immutable artifacts as symlinks or copies, computes unambiguous copy-directory and exact target-state digests, and writes target receipts.
- `inventory.go`: reads target receipts, includes immutable identity digests for plan authorization, and reconciles active filesystem bindings.
- `target.go`: validates path-safe Skill names and resolves Agent, scope, mode, and Skill identity into exact target paths.
- `update.go`: atomically switches tracked targets and explicitly resolved collisions or Local Modifications with rollback backups.
- `*_test.go`: specifies each public module seam with filesystem fixtures.

## Architectural Boundary

This module owns physical Installation Target mutation and receipt state. It accepts already resolved target paths and explicit replacement authority; it must not infer user intent, fetch Registry artifacts, localize machine output, or make App policy decisions.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
