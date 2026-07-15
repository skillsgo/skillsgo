# Update Plan Domain Map

## Members

- `update_plan.go`: validates exact managed targets, resolves each target's movable source reference, excludes pinned commits, groups shared physical and Workspace bindings, previews Workspace Lock changes, and executes state-bound updates or lock-only reconciliation with per-target progress/results.
- `update_plan_test.go`: specifies strict hostile target decoding at the Update Plan boundary.

## Architectural Boundary

This package owns Update Plan semantics. Cobra adapts its machine contract, while Registry, Store, install, and project packages retain their existing infrastructure responsibilities.

## Invariants

- Every request identifies one existing managed target by full artifact and target identity.
- Each target resolves its own stored source reference.
- Fixed commits and tags never produce misleading update availability.
- Execution is bound to the reviewed immutable destination version and target state.
- Every Agent binding governed by one Workspace Lock entry updates as one physical mutation group.
- One failed target never prevents unrelated targets from completing.
- Workspace Locks change only after the corresponding target switches successfully.
- A failed Workspace Lock write can be retried without replacing an already switched target.

## Maintenance

Update this map whenever the package contract or members change.
