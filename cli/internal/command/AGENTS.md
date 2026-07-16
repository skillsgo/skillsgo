# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph and exposes the `Execute` behavior seam.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
- `diagnostics.go`: exposes versioned, read-only local Store health for App integration and terminal diagnostics.
- `diagnostics_test.go`: specifies Store diagnostics schema, readability states, and non-mutating inspection.
- `exit_code.go`, `exit_code_test.go`: classify wrapped Hub availability and timeout failures into stable process exit codes consumed by the App without parsing stderr.
- `agents.go`: exposes complete supported and installed Agent discovery through versioned JSON and localized human output.
- `agents_test.go`: specifies the stable App-facing Agent discovery machine contract.
- `adoption.go`: adapts exact External Installation preflight and explicit Hub-association or Local-import actions into stable JSON.
- `adoption_test.go`: specifies exact content matching, immutable Hub confirmation, content preservation, offline Local import/export, and Local installation reuse through `Execute`.
- `export.go`: exports one private Local Skill artifact to an explicit destination without Hub access.
- `inventory.go`: adapts the managed/external inventory domain report into stable JSON and localized human CLI output.
- `inventory_test.go`: specifies aggregation, External identity separation, read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `installation_plan.go`: adapts strict repeated target/state-bound resolution JSON, resolves Hub artifacts or existing private Local Store artifacts, refreshes cached immutable assessments, and turns risk confirmation flags into stable preflight JSON plus execution-progress NDJSON.
- `installation_plan_test.go`: specifies explicit multi-location/Agent plans, refreshed trusted-risk gates, state-bound resolutions, skip behavior, hostile structured inputs, Workspace Lock previews, partial failure retention, and per-target NDJSON through `Execute`.
- `management_plan.go`: adapts strict repeated exact-target JSON into Target Management Plan preflight JSON and Remove/Repair/Stop Managing progress/result NDJSON.
- `management_plan_test.go`: specifies exact-target removal, unsafe-remove blocking, Repair, content-preserving Stop Managing, Workspace ownership cleanup, Store retention, and machine output through `Execute`.
- `update_plan.go`: adapts explicit target Update Plan preflight JSON and progress/result NDJSON at the command boundary.
- `update_plan_test.go`: specifies per-target source resolution, pinned-commit exclusion, exact-target updates, Workspace Lock ordering, partial success, and failed-only retries through `Execute`.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized root, External Adoption, and Local export command help.
- `install_flow_test.go`: exercises legacy installation, update, and restoration through `Execute`.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, stable availability exit codes, and orchestration at the executable boundary. It delegates Agent, Hub, Store, project, and installation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
