# Update Plan Domain Map
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `update_plan.go`: validates exact managed targets, selects one immutable destination from the independently built Catalog, separates logical identity from Store coordinates, groups shared physical and Workspace bindings, previews Workspace Manifest changes, and executes state-bound target-plus-metadata updates or declaration-only reconciliation with per-target progress/results.
- `update_plan_test.go`: specifies strict hostile target decoding, the stable/prerelease/pseudo-version Catalog update matrix with downgrade prevention, captured-to-Hub replacement, and nested target-failure results at the Update Plan boundary.

## Architectural Boundary

This package owns Update Plan semantics. Cobra adapts its machine contract, while Hub, Store, install, and project packages retain their existing infrastructure responsibilities.

## Invariants

- Every request identifies one existing managed target by full artifact and target identity.
- One bounded Catalog read determines the latest immutable version for every selected Skill; Update Plans never resolve mutable source references.
- A stale Catalog may leave an installation current but can never downgrade a newer installed semantic or pseudo-version.
- A user-confirmed update can move any managed Hub installation, including one originally installed from a fixed tag or commit, to the Catalog's latest immutable version.
- Execution is bound to the reviewed immutable destination version and target state.
- Every Agent binding governed by one Workspace Manifest requirement updates as one physical mutation group.
- One failed target never prevents unrelated targets from completing.
- Workspace Manifests change only after the corresponding target switches successfully.
- A failed metadata commit restores the switched target and its prior local declarations before reporting failure.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
