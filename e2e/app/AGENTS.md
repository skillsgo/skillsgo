# App + CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md`

This workspace owns macOS desktop journeys that drive the rendered Flutter App against a real SkillsGo CLI and a disposable Hub.

## Runtime Contract

- Run only on macOS with Flutter desktop support.
- Build the current Darwin CLI only through the App's normal Xcode bundling phase and launch the Hub from the clean `Dockerfile` image.
- Give each journey a temporary HOME, SkillsGo state root, project root, and Agent root.
- Drive visible App controls and assert both rendered outcomes and final filesystem/Hub contracts.
- Never use a fake `SkillsGateway`, `SKILLSGO_CLI_PATH`, the developer's real HOME, or installed Agent directories.

## Entry Point

`run.sh` is the stable workspace command used by `make test-e2e-app`. It owns cross-product setup and runs every maintained `app/integration_test/*_test.dart` journey in an independent temporary home inside the real Flutter workspace. Explicit absolute journey paths may be passed for focused verification.

## Journeys

- `app/integration_test/machine_failure_recovery_test.dart`: routes a rendered explicit-source request through the bundled CLI to an unreachable Hub and verifies App-owned localized recovery without raw diagnostics.
- `app/integration_test/repository_install_all_test.dart`: searches the SkillsGo-owned public versioned fixture through the disposable Hub and verifies repository-wide installation, nested resources, and complete bundled-CLI metadata.
- `app/integration_test/catalog_update_check_test.dart`: installs the SkillsGo-owned public fixture at v1.2.0, advances the independent Catalog to v1.3.0, and verifies rendered update availability through the bundled CLI.
- `app/integration_test/takeover_management_test.dart`: dismisses the one-time rendered takeover introduction, then manages supported existing user and Added Project Skills through location menus, verifies exact counts before and after each scoped action, and preserves the original files while the bundled CLI persists complete management metadata.

[PROTOCOL]: Update this map when App E2E runtime, entry points, or isolation rules change.
