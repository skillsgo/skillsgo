# App + CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md`

This workspace owns cross-platform desktop startup smoke coverage and complete macOS, Windows, and Linux journeys that drive the rendered Flutter App against the same-repository SkillsGo CLI and a disposable Hub.

## Runtime Contract

- Build and smoke-test macOS arm64, macOS x64, Windows x64, and Linux x64 in GitHub-hosted runners; use Xvfb for Linux rendering.
- Run the complete database-backed Journey suite independently on macOS, Windows, and Linux with Flutter desktop support; render Linux through Xvfb and pin GUI-dependent macOS E2E to macOS 14 until Flutter issue #176850 is fixed upstream.
- Build the host-native CLI once through the App's normal desktop bundling phase, build one host-native Hub binary, and launch one disposable native PostgreSQL instance by default; Docker PostgreSQL remains available for local database-boundary verification where supported.
- Keep one source-fingerprinted Flutter/Xcode Runner alive across local invocations. Give each Journey a temporary HOME, SkillsGo state root, project root, Agent root, PostgreSQL schema, artifact root, Gateway, and Hub process, and close all Journey-owned resources before accepting the next command.
- Drive visible App controls and assert both rendered outcomes and final filesystem/Hub contracts.
- Never use a fake `SkillsGateway`, `SKILLSGO_CLI_PATH`, the developer's real HOME, or installed Agent directories.

## Entry Point

`run.sh` is the stable workspace command used by `make test-e2e-app`. It fingerprints the OSS App plus the same-repository CLI, Protocol, and Hub revisions, starts `app_e2e_runner_test.dart` on demand, and reuses that App process until source changes, the Runner exits, or `run.sh --shutdown` is called. Runner state lives only under ignored `app/build/e2e-runner`, binds an authenticated loopback socket, and never exposes a product HTTP service. The host owns one PostgreSQL process and compiles the Hub from the same public source tree; every command still creates an isolated schema-fixed Hub, real bundled-CLI Gateway, HOME, SkillsGo state, project, Agent, and artifact tree. Explicit Journey paths remain supported and are translated to stable Journey names by `runner_client.dart`. Dependency/compiler caches (`PUB_CACHE`, `GOMODCACHE`, and `GOCACHE`) are reused, while product state remains isolated. Only Flutter's macOS LaunchServices foreground helper may fall back to the developer login home. Linux retries a failed Flutter protocol startup once; Journey assertion failures are never retried. Set `SKILLSGO_E2E_POSTGRES_RUNTIME=docker` to use disposable Docker PostgreSQL locally where supported.

`.github/workflows/ci.yml` directly builds each maintained desktop target and runs `app/integration_test/bundled_cli_smoke_test.dart` on its native runner, then runs the complete Journey suite as separate macOS, Windows, and Linux jobs.

## Journeys

- `app/integration_test/app_e2e_suite_test.dart`: registers every maintained Journey into the default single-build Flutter test executable.
- `app/integration_test/app_e2e_runner_test.dart`: owns the versioned authenticated loopback command loop and invokes reusable Journey functions sequentially inside one built App process.
- `e2e/app/runner_client.dart`: validates the control file, sends ping, shutdown, or named-Journey NDJSON commands, and maps Runner availability and Journey results to process exit status.
- `e2e/app/runner_launcher.dart`: detaches the source-snapshotted Runner host from the invoking terminal and records its PID while the host owns private log redirection.
- `app/integration_test/bundled_cli_smoke_test.dart`: executes the production bundle's CLI startup handshake and renders the App root on each maintained desktop target.
- `app/integration_test/support/journey_runtime.dart`: owns per-Journey real Gateway, filesystem, Hub process, artifact storage, and PostgreSQL schema isolation.
- `app/integration_test/machine_failure_recovery_test.dart`: routes a rendered explicit-source request through the bundled CLI to an unreachable Hub and verifies App-owned localized recovery without raw diagnostics.
- `app/integration_test/repository_install_all_test.dart`: searches the SkillsGo-owned public versioned fixture through the disposable Hub and verifies repository-wide installation, nested resources, and complete bundled-CLI metadata.
- `app/integration_test/package_update_check_test.dart`: installs the SkillsGo-owned public fixture at v1.2.0, advances the independent Catalog to v1.3.0, and verifies the rendered Scope-by-Package update card through the bundled CLI.
- `app/integration_test/adoption_management_test.dart`: dismisses the one-time rendered adoption introduction, then manages supported existing Global and Added Project Skills through location menus, verifies exact counts before and after each scoped action, preserves the original files while the bundled CLI persists complete management metadata, and restores one real adoption backup from Settings → Managed Backups.

[PROTOCOL]: Update this map when App E2E runtime, entry points, or isolation rules change.
