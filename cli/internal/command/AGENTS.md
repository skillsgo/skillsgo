# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph, exposes the `Execute` behavior seam, adapts unified inventory into `list`, and reports legacy Human operations through terminal UI documents/events.
- `terminal_ui.go`: resolves inherited Human UI/color policy into the shared terminal presentation Adapter.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
- `diagnostics.go`: exposes versioned, read-only local Store health for App integration and adaptive terminal diagnostics.
- `diagnostics_test.go`: specifies Store diagnostics schema, readability states, and non-mutating inspection.
- `exit_code.go`, `exit_code_test.go`: classify wrapped Hub availability and timeout failures into stable process exit codes consumed by the App without parsing stderr.
- `agents.go`: exposes complete supported and installed Agent discovery through versioned JSON and grouped adaptive Human output.
- `agents_test.go`: specifies the stable App-facing Agent discovery machine contract.
- `export.go`: exports one private Local Skill artifact with machine confirmation or adaptive Human progress, without Hub access.
- `inventory.go`: adapts the managed/external inventory domain report into stable JSON and grouped adaptive Human output.
- `inventory_test.go`: specifies Skill ID aggregation, External inventory-key separation, read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `list_test.go`: specifies that global listing uses unified inventory and includes externally installed Agent Skills.
- `installation_plan.go`: adapts strict repeated target JSON, resolves Hub artifacts or existing private Local Store artifacts, refreshes cached immutable assessments, maps `--yes` to automatic replacement, and emits stable preflight JSON or adaptive Human/NDJSON execution progress.
- `installation_plan_test.go`: specifies explicit multi-location/Agent plans, refreshed trusted-risk gates, state-bound resolutions, skip behavior, hostile structured inputs, Workspace Manifest previews, partial failure retention, and per-target NDJSON through `Execute`.
- `management_plan.go`: adapts strict repeated exact-target JSON into Target Management Plan preflight JSON and adaptive Human, JSON, or NDJSON execution progress/results.
- `management_plan_test.go`: specifies exact managed and External removal, unsafe-remove blocking, Repair, content-preserving Stop Managing, Workspace ownership cleanup, Store retention, and machine output through `Execute`.
- `update_plan.go`: adapts explicit target Update Plan preflight JSON and adaptive Human, JSON, or NDJSON execution progress/results, returning process failure when any structured target result fails.
- `update_plan_test.go`: specifies that canonical Workspace requirements remain pinned and never subscribe to later movable-ref changes.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized root and Local export command help.
- `install_flow_test.go`: exercises legacy installation, immutable Manifest pinning after selector resolution, update, and restoration through `Execute`.
- `repository_add.go`: orchestrates whole-Repository Info selection, checksum verification, Store admission, Agent projection, and one-requirement Manifest persistence.
- `repository_add_test.go`: specifies Repository selector matching and per-selector Version Query precedence.
- `workspace_restore.go`: restores exact direct requirements from Workspace Sum, immutable Info Cache, Store, and current Agent roots without a lockfile.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, stable availability exit codes, and orchestration at the executable boundary. It delegates Agent, Hub, Store, project, and installation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
