# CLI Command Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `root.go`: constructs the public Cobra command graph and localized help surface, exposes stdin-capable `Execute` behavior seams, emits recognized machine-mode failures, and routes Package add/update/explicitly-confirmed-remove/install operations.
- `server.go`, `server_test.go`: provide and specify the sequential versioned NDJSON CLI Server used by the App to reuse one process and its HTTP transport while isolating request failures.
- `machine_failure.go`: translates wrapped command failures into the minimal versioned JSON or NDJSON machine document without making stderr a parsing contract.
- `machine_failure_test.go`: specifies early JSON and NDJSON failure documents through the public `Execute` seam.
- `terminal_ui.go`: resolves inherited Human UI/color policy into the shared terminal presentation Adapter.
- `args.go`: normalizes compatible multi-value flag syntax before Cobra parses arguments.
- `exit_code.go`, `exit_code_test.go`: classify wrapped Hub availability and timeout failures into stable process exit codes consumed by the App without parsing stderr.
- `agents.go`: exposes complete supported and installed Agent discovery through versioned JSON and grouped adaptive Human output.
- `agents_test.go`: specifies the stable App-facing Agent discovery machine contract.
- `show.go`: implements `show` for direct, read-only Package summaries and exact-path Skill content with immutable source identity; discovery and name lookup belong to `find`.
- `show_test.go`: specifies `show` Go-compatible latest resolution, Package description preservation, exact Package-member selection, stable JSON, missing-member failure, and the no-local-write boundary.
- `product_reads.go`: exposes top-level Skill `find`, same-Origin `rankings`, `hub check`, and strict file/stdin source-language `hub find-candidates` reads; single Find classifies all explicit Package aliases through the CLI Source parser, resolves the selected Package query once, preserves its immutable version through product Find, and leaves keyword and candidate Find Catalog-only.
- `project_registry.go`, `project_registry_test.go`: expose and specify explicit Managed Workspace registration, removal, and stable machine listing over the `projects` section of CLI-owned user configuration.
- `product_reads_test.go`: specifies single and batch Find, immutable explicit-source resolution, ordered batch hydration, and grouped Hub service inspection through Execute.
- `hub_reporting.go`: publishes best-effort post-commit installation facts directly to the current Hub's always-present event route without deployment discovery or changes to local installation outcomes.
- `list.go`: owns the sole installed-Skill listing command, supplies the read-through Package Provider for exact metadata cache reconstruction, and adapts Package-managed/external inventory v7 into stable JSON plus path-rich Human output.
- `list_test.go`: specifies Package ID plus Skill Name aggregation, External inventory-key separation, default-Workspace and explicit-scope read-only inspection, target health, Workspace reconciliation, and the explicit-project privacy boundary.
- `verification.go`, `verification_test.go`: expose and specify read-only reconciled installation verification plus direct declaration/target explanations through `verify` and `why`.
- `adoption.go`: implements the App-facing stdin-JSON `adopt` command by validating reviewed External paths, preparing exact Package members through the ordinary add path without filesystem publication, then appending External retirement to the same Package mutation Plan so commit, rollback, Workspace publication, and final Trash disposal share one boundary.
- `adoption_test.go`: specifies exact Package-member adoption, skills.sh and physical-root symlink topologies, reviewed conflicting Package-path replacement, existing managed coordinates, independent failure groups, crash-safe restoration, committed cleanup failure semantics, successful External disposal, and strict request validation through `Execute`.
- `management_plan.go`: adapts repeatable flat exact-target flags into top-level External Remove planning JSON and `--yes`-confirmed Human, JSON, or NDJSON execution progress/results.
- `management_plan_test.go`: specifies state-bound exact External removal and absence of removed `manage`, `use`, `init`, and `inventory` commands.
- `version.go`: serves the human version output and versioned App startup handshake.
- `args_test.go`: covers public argument normalization and environment-gated test Agent behavior.
- `i18n_test.go`: covers localized root command help.
- `package_add.go`: resolves and prepares one shared Scope-local Package mutation, lets dry-run discard that exact Plan, and atomically replaces complete Scope Package Trees, member Projections, YAML, and Lock state.
- `package_reconcile_inputs.go`: normalizes shared Package Scope paths, validates Workspace state, resolves persisted Skill selectors, and builds physical Agent Projections without owning command policy or transaction execution.
- `package_reconciler.go`: owns the command-internal desired-state engine that turns resolved current/desired Package coordinates, Projections, and optional Workspace state into one prepared Package mutation shared by add, update, install, and adopt-through-add, with an ordinary commit wrapper for non-preview callers.
- `package_update.go`: previews or confirms Package-granularity non-decreasing updates, rebuilds exact metadata/content through the Provider, binds mutations to YAML/Lock state, protects Scope Trees and member Projections, and reports complete outcomes.
- `package_update_test.go`: specifies canonical semantic and pseudo-version update direction, including same-version replay and downgrade rejection.
- `package_remove.go`: rebuilds exact current Git content through the Provider and atomically reconciles the Scope Package Tree and selected member Projections without Local Modification overwrite.
- `package_add_test.go`, `module_store_test.go`, `package_projection_test.go`: specify Package selectors, Scope Trees, member symlinks, cache reconstruction, update impact, atomic switching/rollback, and removal confirmation.
- `package_test_helpers_test.go`: provides shared Package protocol fixtures for command-level tests.
- `workspace_integrity.go`: validates complete immutable resource evidence before atomically extending every destination Workspace Sum and publishing exact Info Cache entries for all installation entry points.
- `workspace_restore.go`: adapts declaration-driven install into the shared reconciler, rebuilding exact metadata/Git caches, missing Scope Trees, and member Projections without movable resolution, declaration changes, pruning, or overwrite.
- `version_test.go`: specifies CLI identity and App protocol compatibility through `Execute`.

## Architectural Boundary

This module owns CLI command composition, argument handling, stable machine output, stable availability exit codes, and orchestration at the executable boundary. It delegates Agent, Hub, Package Provider, project, Scope Tree, Projection, and mutation mechanics to their owning packages and must not expose localized human output as an App integration contract.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
