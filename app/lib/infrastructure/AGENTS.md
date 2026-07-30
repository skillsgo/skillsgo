# App Infrastructure Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `real_skills_gateway.dart`: defines the production `SkillsGateway` adapter, stdin-capable CLI seam, shared state, platform pickers, internal capability composition, and the shared App-side protocol-decode failure telemetry boundary.
- `bundled_cli_locator.dart`: defines the shared macOS, Windows, and Linux bundle-layout contract used to locate the packaged CLI.
- `io_process_runner.dart`: executes one-shot CLI probes and owns the long-lived NDJSON CLI Server session with request correlation, bounded runtime, crash fan-out, optional stdout events, process-scope isolation, and sanitized completion telemetry used by real-process E2E journeys.
- `real_skills_gateway_codec.dart`: owns centralized versioned/machine-document envelope validation, minimal Package-install receipt validation, strict payload decoding for read/planning contracts, argument encoding, and bounded local Skill inspection.
- `real_skills_gateway_cli.dart`: owns coalesced non-destructive bundled CLI detection, startup handshake validation, developer override persistence, lazy CLI Server creation/replacement, command execution, and one-shot transport recovery for explicitly safe reads.
- `real_skills_gateway_preferences.dart`: owns App preferences including one-time randomized wallpaper selection, persisted update-check cache, Mandatory Onboarding state, CLI user-config project adaptation, independent Hub/Cloud origins and health checks, risk policy, and App-version lookup.
- `real_skills_gateway_discovery.dart`: forwards every search input unchanged through current-language CLI `find`, owns bounded-chunk candidate Find and system-proxy-aware platform-native Cloud-composed ranking reads, decodes optional Package summaries and canonical pagination, and uses exact-path `show` only for remote Skill detail.
- `real_skills_gateway_inventory.dart`: owns Agent inspection, local Library inventory, and local Skill detail.
- `real_skills_gateway_installation.dart`: groups ordinary Installation Requests by declaration scope, invokes exact-path Package Store add directly for the user-selected Package version, accepts the CLI's minimal Package-install success receipt without reinterpreting projections, sends one reviewed stdin-JSON Adoption request, and reports App-side protocol failures through the shared telemetry boundary.
- `real_skills_gateway_execution.dart`: owns shared affected-binding integrity and ordered NDJSON progress/final-payload execution envelopes for target mutations.
- `real_skills_gateway_target_management.dart`: owns managed Package-member and External Installation removal planning, execution, and progress translation.
- `real_skills_gateway_updates.dart`: delegates exact Package updates to the CLI, validates response identity, and decodes one cross-Scope dry-run into Scope-by-Package preview state.
- `real_skills_gateway_failures.dart`: owns versioned machine-failure and process-exit translation.
- `project_icon_resolver.dart`: resolves and caches bounded, safe Added Project identity assets with deterministic fallback.
- `mermaid_script_cache.dart`: asynchronously prefetches the immutable CDN-hosted Mermaid.js gzip payload at App startup, verifies its SHA-256 identity, atomically persists it in the platform cache directory, retries failed downloads on first use, and decompresses it only when rendering begins.
- `logging/`: owns App-wide structured event correlation, centralized privacy redaction, JSONL rotation, seven-day retention, and bounded local diagnostics storage.

## Architectural Boundary

This module adapts operating-system processes, preferences, directory pickers, direct Cloud-composed ranking reads, immutable CDN renderer assets, bounded filesystem inspection, and App-owned local diagnostic logging to the App domain. Hub and local business operations cross the bundled CLI machine protocol; Cloud ranking reads use the independently persisted Cloud origin. No capability may call Hub HTTP directly or parse human-oriented CLI output.

`RealSkillsGateway` is the external seam. Its private capability mixins are internal implementation partitions and may share adapter state, but each owns one coherent change axis and remains below the workspace file-size limit.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
