# Update Plan Domain Map
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `update_plan.go`: validates exact managed targets, separates logical source identity from captured Store coordinates, groups shared physical and Workspace bindings, previews Workspace Manifest changes, and executes state-bound target-plus-metadata updates or declaration-only reconciliation with per-target progress/results.
- `update_plan_test.go`: specifies strict hostile target decoding, captured-to-Hub replacement, and nested target-failure results at the Update Plan boundary.

## Architectural Boundary

This package owns Update Plan semantics. Cobra adapts its machine contract, while Hub, Store, install, and project packages retain their existing infrastructure responsibilities.

## Invariants

- Every request identifies one existing managed target by full artifact and target identity.
- Each target resolves its own stored source reference.
- Fixed commits, tags, and resolved pseudo-versions never produce misleading update availability.
- Execution is bound to the reviewed immutable destination version and target state.
- Every Agent binding governed by one Workspace Manifest requirement updates as one physical mutation group.
- One failed target never prevents unrelated targets from completing.
- Workspace Manifests change only after the corresponding target switches successfully.
- A failed metadata commit restores the switched target and its prior local declarations before reporting failure.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
