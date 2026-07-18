# Installation Materialization Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `installer.go`: materializes immutable artifacts into the scope's `.agents/skills` canonical directory, projects Agent-specific symlinks or explicit copies, compensates newly created paths when declaration persistence fails, validates content-matched existing directories, and computes stable filesystem digests.
- `inventory.go`: represents declaration-derived installations and prevalidates safe exact-target removal, including aliased-parent projections, without maintaining a parallel ownership record.
- `target.go`: validates path-safe Skill names and resolves Agent, scope, mode, and Skill ID into exact target paths.
- `update.go`: atomically switches tracked targets, retains rollback backups through declaration persistence, and handles explicitly resolved collisions or Local Modifications.
- `*_test.go`: specifies each public module seam with filesystem fixtures, including shared-target retention, Local Modification blocking, and content-preserving receipt cleanup.

## Architectural Boundary

This module owns canonical Skill materialization, Agent-facing Installation Target mutation, and receipt-derived state. It accepts already resolved canonical and target paths plus explicit replacement authority; it must not infer user intent, fetch Hub artifacts, localize machine output, or make App policy decisions.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
