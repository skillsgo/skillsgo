# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph, exposes the `Execute` behavior seam, emits recognized machine-mode failures, adapts unified inventory into `list`, and routes Repository add/update/remove/install operations.
- `machine_failure.go`: translates wrapped command failures into the minimal versioned JSON or NDJSON machine document without making stderr a parsing contract.
- `machine_failure_test.go`: specifies early JSON and NDJSON failure documents through the public `Execute` seam.
- `terminal_ui.go`: resolves inherited Human UI/color policy into the shared terminal presentation Adapter.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
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
- `inventory.go`: adapts mode-free Repository-managed/external inventory v6 into stable JSON and grouped adaptive Human output.
- `inventory_test.go`: specifies Skill ID aggregation, External inventory-key separation, read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `verification.go`, `verification_test.go`: expose and specify read-only reconciled installation verification plus direct declaration/target explanations through `verify` and `why`.
- `takeover.go`: preflights explicitly selected skills.sh User/Workspace lock-backed External copies into a bounded, expiring, lock-identity- and filesystem-state-bound plan with exact per-location counts, then verifies each unchanged copy against its exact immutable Repository member and adopts the complete Repository through the ordinary add transaction before recoverably removing the External directory.
- `takeover_test.go`: specifies exact Repository-member adoption, mismatch refusal without managed state, malformed lock retention, provider identity, localized help, and required execution arguments through `Execute`.
- `list_test.go`: specifies that global listing uses unified inventory and includes externally installed Agent Skills.
- `management_plan.go`: adapts repeatable flat exact-target flags into top-level Remove/Repair preflight JSON and adaptive Human, JSON, or NDJSON execution progress/results.
- `management_plan_test.go`: specifies state-bound exact External removal and absence of the obsolete `manage` command.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized root and Local export command help.
- `repository_add.go`: orchestrates one root Repository Info/ZIP download, explicit member/Agent/project selection, Scope Vendor/Projection preparation, paired YAML/Lock persistence, idempotency, rollback, and the App-facing Repository-install machine result.
- `repository_update.go`: preflights one declared Repository coordinate change, binds it to current YAML/Lock state, verifies the existing Vendor/Projections, and atomically replaces the complete coordinate while preserving selected members and Agents.
- `repository_remove.go`: verifies the authoritative local Vendor and atomically removes selected root/nested members from every declared Agent projection without Hub access or Local Modification overwrite.
- `repository_add_test.go`, `repository_vendor_test.go`: specify Repository selector matching plus the public exact-version Workspace Vendor journey.
- `repository_test_helpers_test.go`: provides shared Repository protocol fixtures for command-level tests.
- `workspace_integrity.go`: validates complete immutable resource evidence before atomically extending every destination Workspace Sum and publishing exact Info Cache entries for all installation entry points.
- `workspace_restore.go`: performs conflict-safe idempotent Workspace/User ensure from strict YAML/Lock, restoring absent Vendor from exact Proxy resources and absent projections from verified Vendor without selector resolution, update, pruning, or overwrite.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, stable availability exit codes, and orchestration at the executable boundary. It delegates Agent, Hub, Store, project, and installation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
