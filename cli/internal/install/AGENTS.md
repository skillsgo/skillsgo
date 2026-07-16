# Installation Materialization Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `installer.go`: materializes immutable artifacts as symlinks or copies, adopts content-matched existing directories without replacement, computes unambiguous copy-directory and exact target-state digests, and writes baseline-bound target receipts.
- `inventory.go`: reads target receipts, includes immutable identity digests for plan authorization, prevalidates safe exact-target removal, and can forget ownership receipts without changing target content.
- `target.go`: validates path-safe Skill names and resolves Agent, scope, mode, and Skill identity into exact target paths.
- `update.go`: atomically switches tracked targets and explicitly resolved collisions or Local Modifications with rollback backups.
- `*_test.go`: specifies each public module seam with filesystem fixtures, including shared-target retention, Local Modification blocking, and content-preserving receipt cleanup.

## Architectural Boundary

This module owns physical Installation Target mutation and receipt state. It accepts already resolved target paths and explicit replacement authority; it must not infer user intent, fetch Hub artifacts, localize machine output, or make App policy decisions.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
