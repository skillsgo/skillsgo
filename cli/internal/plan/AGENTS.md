# Installation Plan Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `plan.go`: prepares process-local explicit location-and-Agent mutations, classifies version/Skill ID/Local Modification/trusted-risk outcomes, pins resolved immutable versions in declarations, turns affirmative add requests into in-place replacements, and applies target groups with compensation while retaining unrelated successes.
- `plan_test.go`: specifies strict target decoding, supported-but-not-installed Agents, explicit-cell validation, state drift, shared paths, affirmative same-name replacement, skip and conflict behavior, trusted-risk gates, and resilient target-specific results.

## Architectural Boundary

This module owns process-local preparation and application for one immutable artifact plus an explicit list of Installation Targets. It may resolve supported Agent paths regardless of current Agent installation, compare copy content, enforce Hub-derived artifact risk confirmation, and orchestrate compensated `install` and `project` mutations, but it must not expose a user-facing review protocol, infer a Cartesian product, localize machine output, or depend on Flutter state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
