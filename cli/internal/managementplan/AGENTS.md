# Target Management Plan Domain Map
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `management_plan.go`: validates exact managed or External targets, classifies safe actions, binds reviewed state, and executes Remove, Repair, Stop Managing, or explicit External removal with target-specific results.
- `management_plan_test.go`: specifies strict hostile input decoding and action validation.

## Architectural Boundary

This package owns Target Management Plan semantics. It delegates filesystem mutation to install, Workspace metadata changes to project, and read-only health classification to inventory.

## Invariants

- External Installations may enter only for exact-path Remove; they never gain declarations, Repair, or Stop Managing actions.
- Healthy targets may be removed only through exact target identity.
- Unhealthy targets never enter destructive Remove; they expose Repair when recoverable and Stop Managing otherwise.
- Stop Managing removes ownership metadata without changing target content.
- Execution is bound to the reviewed receipt, Workspace metadata, and filesystem state.
- Store artifacts are retained; this flow never performs implicit pruning.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
