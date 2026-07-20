# App Infrastructure Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `real_skills_gateway.dart`: defines the production `SkillsGateway` adapter, shared state, platform pickers, and internal capability composition.
- `io_process_runner.dart`: executes the bundled CLI with structured arguments, bounded runtime, optional stdout events, and typed output.
- `real_skills_gateway_codec.dart`: owns strict machine-protocol decoding, argument encoding, schema validation, and bounded local Skill inspection.
- `real_skills_gateway_cli.dart`: owns bundled CLI detection, startup handshake validation, developer override persistence, and command execution.
- `real_skills_gateway_preferences.dart`: owns App preferences, Mandatory Onboarding state, Added Project references, Hub origin, risk policy, and storage diagnostics.
- `real_skills_gateway_discovery.dart`: owns locale-aware discovery, explicit-source fallback, and remote Skill detail decoding.
- `real_skills_gateway_inventory.dart`: owns Agent inspection, local Library inventory, exact Batch Takeover planning and scope-bound execution, and local Skill detail.
- `real_skills_gateway_installation.dart`: owns Installation Request execution, compatibility installation, and Local Skill export.
- `real_skills_gateway_execution.dart`: owns shared affected-binding integrity and ordered NDJSON progress/final-payload execution envelopes for target mutations.
- `real_skills_gateway_target_management.dart`: owns reviewed Remove and Repair preflight, execution, and progress translation.
- `real_skills_gateway_updates.dart`: owns reviewed update preflight, execution, progress translation, and update checks.
- `real_skills_gateway_failures.dart`: owns versioned machine-failure and process-exit translation.
- `project_icon_resolver.dart`: resolves and caches bounded, safe Added Project identity assets with deterministic fallback.

## Architectural Boundary

This module adapts operating-system processes, preferences, directory pickers, and bounded filesystem inspection to the App domain. All Hub and local business operations cross the bundled CLI machine protocol; no capability may add direct Hub HTTP access or parse human-oriented output.

`RealSkillsGateway` is the external seam. Its private capability mixins are internal implementation partitions and may share adapter state, but each owns one coherent change axis and remains below the workspace file-size limit.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
