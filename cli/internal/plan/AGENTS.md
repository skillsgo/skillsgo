# Installation Plan Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `plan.go`: validates explicit location-and-Agent cells, state-bound resolutions, and shared bindings; classifies version/identity/Local Modification/trusted-risk outcomes; builds stable preflight records; and executes fully resolved target groups while updating project declarations and locks.
- `plan_test.go`: specifies strict target decoding, explicit-cell validation, state drift, shared paths, skip and conflict behavior, zero-mutation unresolved plans, trusted-risk gates, Workspace Lock previews, and target-specific execution results.

## Architectural Boundary

This module owns the CLI domain contract for one immutable artifact plus an explicit list of Installation Targets and state-bound per-target resolutions. It may resolve known Agent paths, compare copy content, expose shared physical bindings, enforce Registry-derived artifact risk confirmation, and orchestrate `install` and `project` mutations, but it must not infer a Cartesian product, localize machine output, or depend on Flutter state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
