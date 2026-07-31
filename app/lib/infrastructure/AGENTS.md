# App Infrastructure Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `desktop_skills_gateway.dart`: defines the production `SkillsGateway` adapter, stdin-capable CLI seam, shared state, platform pickers, internal capability composition, and the shared App-side protocol-decode failure telemetry boundary.
- `app_updater.dart`: adapts the community `velopack_flutter` bridge over Velopack 1.2.0 into the App's early runtime and update/restart seam, with a loopback-only unsigned rehearsal source for CI.
- `bundled_cli_locator.dart`: defines the shared macOS, Windows, and Linux bundle-layout contract used to locate the packaged CLI.
- `io_process_runner.dart`: executes one-shot CLI probes and owns the long-lived NDJSON CLI Server session with request correlation, bounded runtime, crash fan-out, optional stdout events, process-scope isolation, and sanitized completion telemetry used by real-process E2E journeys.
- `desktop_skills_gateway_codec.dart`: owns centralized versioned/machine-document envelope validation, minimal Package-install receipt validation, strict payload decoding for read/planning contracts, argument encoding, and bounded local Skill inspection.
- `desktop_skills_gateway_cli.dart`: owns coalesced non-destructive bundled CLI detection, startup handshake validation, developer override persistence, lazy CLI Server creation/replacement, command execution, and one-shot transport recovery for explicitly safe reads.
- `desktop_skills_gateway_preferences.dart`: owns App preferences including one-time randomized wallpaper selection, persisted update-check cache, Mandatory Onboarding state, CLI user-config project adaptation, the single Hub Origin and health check, risk policy, and App-version lookup.
- `desktop_skills_gateway_discovery.dart`: forwards search and ranking reads through the long-lived CLI Server using the current Hub Origin and presentation language, owns bounded-chunk candidate Find, decodes optional Package summaries and canonical pagination, and uses exact-path `show` only for remote Skill detail.
- `desktop_skills_gateway_inventory.dart`: owns Agent inspection, local Library inventory, and local Skill detail.
- `desktop_skills_gateway_installation.dart`: groups ordinary Installation Requests by declaration scope, invokes exact-path Package Store add directly for the user-selected Package version, accepts the CLI's minimal Package-install success receipt without reinterpreting projections, sends one reviewed stdin-JSON Adoption request, and reports App-side protocol failures through the shared telemetry boundary.
- `desktop_skills_gateway_execution.dart`: owns shared affected-binding integrity and ordered NDJSON progress/final-payload execution envelopes for target mutations.
- `desktop_skills_gateway_target_management.dart`: owns managed Package-member and External Installation removal planning, execution, and progress translation.
- `desktop_skills_gateway_updates.dart`: delegates exact Package updates to the CLI, validates response identity, and decodes one cross-Scope dry-run into Scope-by-Package preview state.
- `desktop_skills_gateway_failures.dart`: owns versioned machine-failure and process-exit translation.
- `project_icon_resolver.dart`: resolves and caches bounded, safe Added Project identity assets with deterministic fallback.
- `mermaid_script_cache.dart`: asynchronously prefetches the immutable CDN-hosted Mermaid.js gzip payload at App startup, verifies its SHA-256 identity, atomically persists it in the platform cache directory, retries failed downloads on first use, and decompresses it only when rendering begins.
- `logging/`: owns App-wide structured event correlation, centralized privacy redaction, JSONL rotation, seven-day retention, and bounded local diagnostics storage.

## Architectural Boundary

This module adapts operating-system processes, native App update mechanics, preferences, directory pickers, immutable CDN renderer assets, bounded filesystem inspection, and App-owned local diagnostic logging to the App domain. Every Hub and local business operation crosses the bundled CLI machine protocol; Velopack update feeds are a release-delivery concern rather than Hub business data. No capability may call Hub HTTP directly or parse human-oriented CLI output.

`DesktopSkillsGateway` is the external seam. Its private capability mixins are internal implementation partitions and may share adapter state, but each owns one coherent change axis and remains below the workspace file-size limit.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
