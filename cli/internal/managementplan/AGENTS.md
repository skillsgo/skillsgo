# External Target Operations Domain Map
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `management_plan.go`: resolves flat exact-path arguments only against External inventory, binds reviewed filesystem state, and executes recoverable removal with target-specific progress/results.
- `management_plan_test.go`: specifies strict mode-free decoding, successful recoverable removal, and changed-target refusal.

## Architectural Boundary

This package owns exact External target removal semantics. It delegates recoverable filesystem disposal to trash and read-only discovery to inventory.

## Invariants

- Only External Installations may enter this flow; Repository-managed coordinates use Repository remove transactions.
- Execution is bound to the reviewed filesystem state.
- Removal is recoverable through the platform Trash or Recycle Bin.
- This flow never creates declarations, locks, Vendors, Projections, Receipts, or Store objects.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
