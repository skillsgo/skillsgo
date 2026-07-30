# App + CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md`

This workspace owns cross-platform desktop startup smoke coverage and complete macOS, Windows, and Linux journeys that drive the rendered Flutter App against a real SkillsGo CLI and a disposable Hub.

## Runtime Contract

- Build and smoke-test macOS arm64, macOS x64, Windows x64, and Linux x64 in GitHub-hosted runners; use Xvfb for Linux rendering.
- Run the complete database-backed Journey suite independently on macOS, Windows, and Linux with Flutter desktop support; render Linux through Xvfb.
- Build the host-native CLI once through the App's normal desktop bundling phase, build one host-native Hub binary, and launch one disposable native PostgreSQL instance by default; Docker PostgreSQL remains available for local database-boundary verification where supported.
- Run the maintained aggregate entry in one Flutter/Xcode test executable. Give each Journey a temporary HOME, SkillsGo state root, project root, Agent root, PostgreSQL schema, artifact root, and Hub process while retaining schemas until suite teardown.
- Drive visible App controls and assert both rendered outcomes and final filesystem/Hub contracts.
- Never use a fake `SkillsGateway`, `SKILLSGO_CLI_PATH`, the developer's real HOME, or installed Agent directories.

## Entry Point

`run.sh` is the stable workspace command used by `make test-e2e-app`. It detects the host desktop target, owns suite-scoped PostgreSQL and Hub-binary setup, then runs `app/integration_test/app_e2e_suite_test.dart` once so Flutter and the bundled CLI compile once per platform. Each registered Journey starts a schema-fixed Hub process and real CLI Gateway with independent directories. Explicit absolute Journey paths may be passed for focused verification. Linux retries the Flutter test process once in a fresh suite runtime only when Flutter exits with protocol status 79. macOS retries once only when Flutter reports that it could not foreground the test App. Journey assertion failures are never retried. Set `SKILLSGO_E2E_POSTGRES_RUNTIME=docker` to use disposable Docker PostgreSQL locally where supported.

`.github/workflows/ci.yml` directly builds each maintained desktop target and runs `app/integration_test/bundled_cli_smoke_test.dart` on its native runner, then runs the complete Journey suite as separate macOS, Windows, and Linux jobs.

## Journeys

- `app/integration_test/app_e2e_suite_test.dart`: registers every maintained Journey into the default single-build Flutter test executable.
- `app/integration_test/bundled_cli_smoke_test.dart`: executes the production bundle's CLI startup handshake and renders the App root on each maintained desktop target.
- `app/integration_test/support/journey_runtime.dart`: owns per-Journey real Gateway, filesystem, Hub process, artifact storage, and PostgreSQL schema isolation.
- `app/integration_test/machine_failure_recovery_test.dart`: routes a rendered explicit-source request through the bundled CLI to an unreachable Hub and verifies App-owned localized recovery without raw diagnostics.
- `app/integration_test/repository_install_all_test.dart`: searches the SkillsGo-owned public versioned fixture through the disposable Hub and verifies repository-wide installation, nested resources, and complete bundled-CLI metadata.
- `app/integration_test/package_update_check_test.dart`: installs the SkillsGo-owned public fixture at v1.2.0, advances the independent Catalog to v1.3.0, and verifies the rendered Scope-by-Package update card through the bundled CLI.
- `app/integration_test/adoption_management_test.dart`: dismisses the one-time rendered adoption introduction, then manages supported existing Global and Added Project Skills through location menus, verifies exact counts before and after each scoped action, and preserves the original files while the bundled CLI persists complete management metadata.

[PROTOCOL]: Update this map when App E2E runtime, entry points, or isolation rules change.
