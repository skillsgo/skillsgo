# SkillsGateway Test Double
> F3 | Parent: `/app/test/support/AGENTS.md` | Workspace: `skillsgo`

## Members

- `fake_gateway_core.dart`: owns constructor controls, shared scenario state, onboarding, one-time takeover-introduction preferences, projects, and canonical fixtures.
- `fake_gateway_system.dart`: implements CLI detection, discovery, remote detail, and system status behavior.
- `fake_gateway_inventory.dart`: implements installed inventory, local detail, and update-state inspection behavior.
- `fake_gateway_installation.dart`: implements Repository installation planning and execution behavior.
- `fake_gateway_target_management.dart`: implements exact target management and batch takeover behavior.
- `fake_gateway_updates.dart`: implements update planning, execution, progress, and failed-target retry behavior.

## Architectural Boundary

This module is a composable in-memory implementation of the public `SkillsGateway` contract for tests. Capability mixins share only scenario controls from the core and must not perform real process, network, preference, or filesystem work.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
