# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph and localized help surface, exposes the `Execute` behavior seam, emits recognized machine-mode failures, and routes Repository add/update/explicitly-confirmed-remove/install operations.
- `machine_failure.go`: translates wrapped command failures into the minimal versioned JSON or NDJSON machine document without making stderr a parsing contract.
- `machine_failure_test.go`: specifies early JSON and NDJSON failure documents through the public `Execute` seam.
- `terminal_ui.go`: resolves inherited Human UI/color policy into the shared terminal presentation Adapter.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
- `exit_code.go`, `exit_code_test.go`: classify wrapped Hub availability and timeout failures into stable process exit codes consumed by the App without parsing stderr.
- `agents.go`: exposes complete supported and installed Agent discovery through versioned JSON and grouped adaptive Human output.
- `agents_test.go`: specifies the stable App-facing Agent discovery machine contract.
- `show.go`: implements `show` for direct, read-only Repository summaries, named Skill metadata, and exact-path Skill content with immutable source identity plus provider-neutral Hub product metadata.
- `show_test.go`: specifies `show` Go-compatible latest resolution, Package description preservation, exact Package-member selection, stable JSON, missing-member failure, and the no-local-write boundary.
- `product_reads.go`: exposes top-level single-query or strict file/stdin batch Skill `find` plus `hub info` and `hub check` reads, including optional exact-name/Source restriction and description locale forwarding, while hiding Hub routes and query parameters behind CLI domain language.
- `product_reads_test.go`: specifies single and batch Find, ordered batch hydration, and grouped Hub service inspection through Execute.
- `catalog_update_check.go`, `catalog_update_check_test.go`: expose and specify the bounded read-only `hub check-update` App machine command that compares installed Library-entry versions with one Package-fresh latest candidate resolved once per Package.
- `cloud_reporting.go`: publishes best-effort post-commit installation facts directly to the Cloud origin declared by a Cloud-mode Hub without changing local installation outcomes.
- `list.go`: owns the sole installed-Skill listing command and adapts mode-free Repository-managed/external inventory v7 into stable JSON plus path-rich adaptive Human output, defaulting to the current Workspace.
- `list_test.go`: specifies Repository ID plus Skill Name aggregation, External inventory-key separation, default-Workspace and explicit-scope read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `verification.go`, `verification_test.go`: expose and specify read-only reconciled installation verification plus direct declaration/target explanations through `verify` and `why`.
- `takeover.go`: implements the public `adopt` command by planning explicitly selected skills.sh Global/Workspace lock-backed External copies and, after `--yes`, verifying each copy against its exact immutable Repository member before adopting the complete Repository through the ordinary add transaction and recoverably removing the External directory.
- `takeover_test.go`: specifies `adopt` Repository-member adoption, mismatch refusal without managed state, malformed lock retention, provider identity, localized help, and required execution arguments through `Execute`.
- `management_plan.go`: adapts repeatable flat exact-target flags into top-level External Remove planning JSON and `--yes`-confirmed Human, JSON, or NDJSON execution progress/results.
- `management_plan_test.go`: specifies state-bound exact External removal and absence of removed `manage`, `use`, `init`, and `inventory` commands.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized root command help.
- `repository_add.go`: orchestrates one root Repository Info/ZIP download, explicit member/Agent/project selection, Scope Package Store/Projection preparation, and the App-facing Repository-install result through the shared Repository mutation commit state machine.
- `repository_update.go`: confirms and applies one declared or all scope-installed Repository coordinate changes, binds each mutation to current YAML/Lock state, verifies the existing Package Store/Projections, and atomically replaces complete coordinates while preserving selected members and Agents.
- `repository_remove.go`: verifies the authoritative local Package Store and atomically removes selected root/nested members from every declared Agent projection without Hub access or Local Modification overwrite.
- `repository_add_test.go`, `module_store_test.go`: specify Repository selector matching plus the public exact-version Workspace Package Store journey, including the Repository removal confirmation gate.
- `repository_test_helpers_test.go`: provides shared Repository protocol fixtures for command-level tests.
- `workspace_integrity.go`: validates complete immutable resource evidence before atomically extending every destination Workspace Sum and publishing exact Info Cache entries for all installation entry points.
- `workspace_restore.go`: performs conflict-safe idempotent Workspace/Global ensure from strict YAML/Lock, restoring absent Package Store from exact Proxy resources and absent projections from verified Package Store without selector resolution, update, pruning, or overwrite.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, stable availability exit codes, and orchestration at the executable boundary. It delegates Agent, Hub, project, Repository mutation, Scope Package Store, and installation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
