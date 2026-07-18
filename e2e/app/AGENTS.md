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

`run.sh` is the stable workspace command used by `make test-e2e-app`. It owns cross-product setup and runs every maintained `app/integration_test/*_test.dart` journey inside the real Flutter workspace.

## Journeys

- `app/integration_test/machine_failure_recovery_test.dart`: routes a rendered explicit-source request through the bundled CLI to an unreachable Hub and verifies App-owned localized recovery without raw diagnostics.
- `app/integration_test/repository_install_all_test.dart`: searches a public GitHub Repository through the disposable Hub and verifies that the repository-wide action opens the rendered installation-location surface backed by the real CLI catalog.

[PROTOCOL]: Update this map when App E2E runtime, entry points, or isolation rules change.
