# Installation Plan Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `plan.go`: validates explicit location-and-Agent cells, builds stable target preflight records, and executes independent target groups while updating project declarations and locks.
- `plan_test.go`: specifies strict target decoding, explicit-cell validation, skip behavior, Workspace Lock previews, and target-specific execution results.

## Architectural Boundary

This module owns the CLI domain contract for one immutable artifact plus an explicit list of Installation Targets. It may resolve known Agent paths and orchestrate `install` and `project` mutations, but it must not infer a Cartesian product, localize machine output, or depend on Flutter state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
