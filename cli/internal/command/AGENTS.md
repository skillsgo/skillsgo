# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph, exposes the `Execute` behavior seam, emits recognized machine-mode failures, adapts unified inventory into `list`, wires safe cache lifecycle commands, and reports legacy Human operations through terminal UI documents/events.
- `machine_failure.go`: translates wrapped command failures into the minimal versioned JSON or NDJSON machine document without making stderr a parsing contract.
- `machine_failure_test.go`: specifies early JSON and NDJSON failure documents through the public `Execute` seam.
- `terminal_ui.go`: resolves inherited Human UI/color policy into the shared terminal presentation Adapter.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
- `diagnostics.go`: exposes versioned, read-only local Store health for App integration and adaptive terminal diagnostics.
- `diagnostics_test.go`: specifies Store diagnostics schema, readability states, and non-mutating inspection.
- `cache.go`, `cache_test.go`: expose and specify exact immutable verified cache warming without target installation plus dry-run-by-default, grace-bounded, reference-aware Hub CAS object garbage collection through the public Execute seam.
- `exit_code.go`, `exit_code_test.go`: classify wrapped Hub availability and timeout failures into stable process exit codes consumed by the App without parsing stderr.
- `agents.go`: exposes complete supported and installed Agent discovery through versioned JSON and grouped adaptive Human output.
- `agents_test.go`: specifies the stable App-facing Agent discovery machine contract.
- `info.go`: exposes direct, read-only Repository or Skill JSON with immutable source identity plus provider-neutral Hub product metadata, including Repository descriptions required by App cards.
- `info_test.go`: specifies explicit head/release resolution, Repository description preservation, exact Repository-batch member selection, stable JSON, missing-member failure, and the no-local-write boundary.
- `product_reads.go`: exposes top-level Skill `find`/`detail` reads plus grouped `hub info`/`hub check` service inspection, including optional description locale forwarding, while hiding Hub routes and query parameters behind CLI domain language.
- `product_reads_test.go`: specifies top-level Skill reads, ordered batch hydration, and grouped Hub service inspection through Execute.
- `catalog_update_check.go`, `catalog_update_check_test.go`: expose and specify one bounded read-only App machine command that compares installed Library-entry versions with Repository-fresh head/release candidates resolved once per Repository.
- `cloud_reporting.go`: publishes best-effort post-commit installation facts directly to the Cloud origin declared by a Cloud-mode Hub without changing local installation outcomes.
- `export.go`: exports one private Local Skill artifact with machine confirmation or adaptive Human progress, without Hub access.
- `inventory.go`: adapts the managed/external inventory domain report into stable JSON and grouped adaptive Human output.
- `inventory_test.go`: specifies Skill ID aggregation, External inventory-key separation, read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `verification.go`, `verification_test.go`: expose and specify read-only reconciled installation verification plus direct declaration/target explanations through `verify` and `why`.
- `takeover.go`: preflights explicitly selected skills.sh user/Workspace lock-backed External copies into a bounded, expiring, lock-identity- and filesystem-state-bound plan with exact per-location counts, then registers authorized unchanged candidates as captured Store baselines plus exact target Receipt and declaration state, returning named per-item outcomes without Hub access or target materialization.
- `takeover_test.go`: specifies read-only preflight, plan-bound execution, exact User/Workspace counts, scope isolation, XDG, provider-aware and record-isolated lock parsing, lock-ref changes, malformed and bounded ephemeral plans, divergent-copy, identical-baseline, safe-alias, partial-success, schema, localization, idempotency, target-byte preservation, and managed-inventory Batch Takeover behavior through `Execute`.
- `list_test.go`: specifies that global listing uses unified inventory and includes externally installed Agent Skills.
- `installation_plan.go`: adapts strict repeated target JSON, resolves Hub artifacts or existing private Local Store artifacts, persists verified Repository/Skill integrity for every declaration root, refreshes cached immutable assessments, keeps confirmation separate from explicit replacement authority, and emits direct Human or JSON execution results.
- `installation_plan_test.go`: specifies explicit multi-location/Agent plans, complete Workspace Manifest/Sum persistence, refreshed trusted-risk gates, state-bound resolutions, skip behavior, hostile structured inputs, partial failure retention, and per-target NDJSON through `Execute`.
- `management_plan.go`: adapts repeatable flat exact-target flags into top-level Remove/Repair preflight JSON and adaptive Human, JSON, or NDJSON execution progress/results.
- `management_plan_test.go`: specifies exact managed and External removal, unsafe-remove blocking, Repair, Workspace ownership cleanup, Store retention, and complete JSON/NDJSON failure documents before non-zero `Execute` results.
- `update_plan.go`: adapts explicit target Update Plan preflight JSON and adaptive Human, JSON, or NDJSON execution progress/results, returning process failure when any structured target result fails.
- `update_plan_test.go`: specifies pinned canonical Workspace requirements plus complete JSON/NDJSON nested failure documents before non-zero `Execute` results.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized root and Local export command help.
- `install_flow_test.go`: retains the migration inventory of existing installation, update, and restoration journeys that must be adapted to Repository Vendor architecture.
- `repository_add.go`: orchestrates one root Repository Info/ZIP download, explicit member/Agent selection, Scope Vendor/Projection preparation, paired YAML/Lock persistence, idempotency, and rollback.
- `repository_remove.go`: verifies the authoritative local Vendor and atomically removes selected root/nested members from every declared Agent projection without Hub access or Local Modification overwrite.
- `repository_add_test.go`, `repository_vendor_test.go`: specify Repository selector matching plus the public exact-version Workspace Vendor journey.
- `workspace_integrity.go`: validates complete immutable resource evidence before atomically extending every destination Workspace Sum and publishing exact Info Cache entries for all installation entry points.
- `workspace_restore.go`: performs conflict-safe idempotent Workspace/User ensure from strict YAML/Lock, restoring absent Vendor from exact Proxy resources and absent projections from verified Vendor without selector resolution, update, pruning, or overwrite.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, stable availability exit codes, and orchestration at the executable boundary. It delegates Agent, Hub, Store, project, and installation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
