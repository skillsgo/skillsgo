# Target Operations Domain Map
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `management_plan.go`: resolves flat exact-path arguments, validates managed or External targets, recovers exact artifact coordinates from Installation Receipts, groups physical aliases, binds reviewed state, and executes Remove, Repair, or explicit External removal with target-specific results.
- `management_plan_test.go`: specifies strict hostile input decoding, action validation, and nested target-failure results.

## Architectural Boundary

This package owns exact target-operation semantics. It delegates filesystem mutation to install and trash, Workspace metadata changes to project, and read-only health classification to inventory.

## Invariants

- External Installations may enter only for exact-path Remove; they never gain declarations or Repair actions.
- Healthy targets may be removed only through exact target identity.
- Unhealthy targets never enter destructive Remove; they expose Repair only when recoverable.
- Execution is bound to the reviewed receipt, Workspace metadata, and filesystem state.
- Removing one binding never removes physical content still used by another copy/symlink binding.
- Store artifacts are retained; this flow never performs implicit pruning.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
