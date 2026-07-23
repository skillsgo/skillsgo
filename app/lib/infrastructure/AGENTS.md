# App Infrastructure Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `real_skills_gateway.dart`: defines the production `SkillsGateway` adapter, shared state, platform pickers, and internal capability composition.
- `io_process_runner.dart`: executes the bundled CLI with structured arguments, bounded runtime, optional stdout events, and typed output.
- `real_skills_gateway_codec.dart`: owns strict machine-protocol decoding, argument encoding, schema validation, and bounded local Skill inspection.
- `real_skills_gateway_cli.dart`: owns bundled CLI detection, startup handshake validation, developer override persistence, and command execution.
- `real_skills_gateway_preferences.dart`: owns App preferences, Mandatory Onboarding state, one-time Batch Takeover introduction state, Added Project references, Hub origin and `hub info` runtime discovery, risk policy, and App-version lookup.
- `real_skills_gateway_discovery.dart`: owns locale-aware `find` search, direct Cloud ranking reads with ordered Hub batch hydration, explicit-source classification for equivalent GitHub aliases and Git coordinates, and remote Skill detail decoding.
- `real_skills_gateway_inventory.dart`: owns Agent inspection, local Library inventory, exact Batch Takeover planning and scope-bound execution, and local Skill detail.
- `real_skills_gateway_installation.dart`: groups Installation Requests by declaration scope, invokes exact Repository Vendor add through the bundled CLI, decodes Vendor/Projection results, and owns Local Skill export.
- `real_skills_gateway_execution.dart`: owns shared affected-binding integrity and ordered NDJSON progress/final-payload execution envelopes for target mutations.
- `real_skills_gateway_target_management.dart`: owns reviewed Remove and Repair preflight, execution, and progress translation.
- `real_skills_gateway_updates.dart`: owns state-bound Repository-coordinate update preflight, execution, progress projection onto Library targets, and one Catalog-only batch update check across the current Library.
- `real_skills_gateway_failures.dart`: owns versioned machine-failure and process-exit translation.
- `project_icon_resolver.dart`: resolves and caches bounded, safe Added Project identity assets with deterministic fallback.

## Architectural Boundary

This module adapts operating-system processes, preferences, directory pickers, direct Cloud ranking reads, and bounded filesystem inspection to the App domain. Hub and local business operations cross the bundled CLI machine protocol; Cloud-only product reads may use the Cloud origin declared by `hub info`. No capability may call Hub HTTP directly or parse human-oriented CLI output.

`RealSkillsGateway` is the external seam. Its private capability mixins are internal implementation partitions and may share adapter state, but each owns one coherent change axis and remains below the workspace file-size limit.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
