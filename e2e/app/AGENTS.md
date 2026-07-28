# App + CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md`

This workspace owns macOS desktop journeys that drive the rendered Flutter App against a real SkillsGo CLI and a disposable Hub.

## Runtime Contract

- Run only on macOS with Flutter desktop support.
- Build the current Darwin CLI once through the App's normal Xcode bundling phase, build one current native Darwin Hub binary, and launch one disposable native PostgreSQL instance by default; Docker PostgreSQL remains available for local database-boundary verification.
- Run the maintained aggregate entry in one Flutter/Xcode test executable. Give each Journey a temporary HOME, SkillsGo state root, project root, Agent root, PostgreSQL schema, artifact root, and Hub process while retaining schemas until suite teardown.
- Drive visible App controls and assert both rendered outcomes and final filesystem/Hub contracts.
- Never use a fake `SkillsGateway`, `SKILLSGO_CLI_PATH`, the developer's real HOME, or installed Agent directories.

## Entry Point

`run.sh` is the stable workspace command used by `make test-e2e-app`. It owns suite-scoped PostgreSQL and Hub-binary setup, then runs `app/integration_test/app_e2e_suite_test.dart` once so Flutter, Xcode, and the bundled CLI compile once. Each registered Journey starts a schema-fixed Hub process and real CLI Gateway with independent directories. Explicit absolute Journey paths may be passed for focused verification. Set `SKILLSGO_E2E_POSTGRES_RUNTIME=docker` to use disposable Docker PostgreSQL locally.

## Journeys

- `app/integration_test/app_e2e_suite_test.dart`: registers every maintained Journey into the default single-build Flutter test executable.
- `app/integration_test/support/journey_runtime.dart`: owns per-Journey real Gateway, filesystem, Hub process, artifact storage, and PostgreSQL schema isolation.
- `app/integration_test/machine_failure_recovery_test.dart`: routes a rendered explicit-source request through the bundled CLI to an unreachable Hub and verifies App-owned localized recovery without raw diagnostics.
- `app/integration_test/repository_install_all_test.dart`: searches the SkillsGo-owned public versioned fixture through the disposable Hub and verifies repository-wide installation, nested resources, and complete bundled-CLI metadata.
- `app/integration_test/catalog_update_check_test.dart`: installs the SkillsGo-owned public fixture at v1.2.0, advances the independent Catalog to v1.3.0, and verifies rendered update availability through the bundled CLI.
- `app/integration_test/adoption_management_test.dart`: dismisses the one-time rendered adoption introduction, then manages supported existing Global and Added Project Skills through location menus, verifies exact counts before and after each scoped action, and preserves the original files while the bundled CLI persists complete management metadata.

[PROTOCOL]: Update this map when App E2E runtime, entry points, or isolation rules change.
