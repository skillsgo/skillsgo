# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph and exposes the `Execute` behavior seam.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
- `diagnostics.go`: exposes versioned, read-only local Store health for App integration and terminal diagnostics.
- `diagnostics_test.go`: specifies Store diagnostics schema, readability states, and non-mutating inspection.
- `agents.go`: exposes complete supported and installed Agent discovery through versioned JSON and localized human output.
- `agents_test.go`: specifies the stable App-facing Agent discovery machine contract.
- `inventory.go`: adapts the managed/external inventory domain report into stable JSON and localized human CLI output.
- `inventory_test.go`: specifies aggregation, External identity separation, read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `installation_plan.go`: adapts strict repeated target/state-bound resolution JSON, refreshes cached immutable assessments, and turns risk confirmation flags into stable preflight JSON plus execution-progress NDJSON.
- `installation_plan_test.go`: specifies explicit multi-location/Agent plans, refreshed trusted-risk gates, state-bound resolutions, skip behavior, hostile structured inputs, Workspace Lock previews, partial failure retention, and per-target NDJSON through `Execute`.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized public command help.
- `install_flow_test.go`: exercises installation and restoration through `Execute`.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, and orchestration at the executable boundary. It delegates Agent, Registry, Store, project, and installation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
