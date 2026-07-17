# Installation Plan Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `plan.go`: validates explicit location-and-Agent cells and shared bindings; classifies version/Skill ID/Local Modification/trusted-risk outcomes; pins resolved immutable versions in declarations; turns affirmative add requests into in-place replacements; builds stable preflight records; and executes target groups with structured progress while retaining unrelated successes.
- `plan_test.go`: specifies strict target decoding, explicit-cell validation, state drift, shared paths, affirmative same-name replacement, skip and conflict behavior, trusted-risk gates, Workspace Manifest previews, and resilient target-specific progress/results.

## Architectural Boundary

This module owns the CLI domain contract for one immutable artifact plus an explicit list of Installation Targets and state-bound per-target resolutions. It may resolve known Agent paths, compare copy content, expose shared physical bindings, enforce Hub-derived artifact risk confirmation, and orchestrate `install` and `project` mutations, but it must not infer a Cartesian product, localize machine output, or depend on Flutter state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
