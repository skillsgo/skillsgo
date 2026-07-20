# App Test Support
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `fake_process_runner.dart`: provides ordered process expectations for CLI adapter contract suites.
- `fake_skills_gateway.dart`: exposes the composed controllable `SkillsGateway` test double.
- `fake_gateway/`: partitions the fake by shared state, system/discovery, inventory, installation, target management, and update capabilities.
- `skill_fixtures.dart`: owns canonical immutable SkillDetail transformations and successful command fixtures.
- `widget_test_helpers.dart`: provides shared rendered-test finders, semantic matchers, contrast helpers, and re-exports canonical fixtures.

## Architectural Boundary

This module owns reusable deterministic test doubles and presentation assertions. It may model production contracts but must not duplicate production protocol parsing or hide journey-specific expectations inside shared helpers.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
