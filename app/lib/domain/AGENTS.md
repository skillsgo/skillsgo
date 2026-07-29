# App Domain Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `skills_gateway.dart`: defines the stable application-facing Gateway interface, including batch Package-scoped Find and atomic Package installation, and re-exports the complete domain vocabulary.
- `system_models.dart`: owns cross-journey metric enums, exact update availability candidates and their persisted App cache, appearance settings, one-shot and long-lived stdin-capable CLI process contracts, command results, and typed failures.
- `discovery_models.dart`: owns public Skill summaries, canonical page/per-page/has-more pagination, batch Package-scoped Find queries/results, logical coordinates and exact `Skill.path` installation selectors, Package metadata, discovery pages, and auditable files.
- `installation_models.dart`: owns Installation Request target selection, execution results, failures, and stable target identity without duplicating CLI Package-version policy.
- `target_management_models.dart`: owns reviewed managed Package-member and External Installation removal plans, execution results, and progress.
- `library_models.dart`: owns Agent catalogs, Added Projects, onboarding state, Skill detail, unified Library entries, and Batch Adoption scope/plan/result values.
- `presentation_language.dart`: owns the persisted Presentation Language value and supported canonical `lang` resolution.
- `skill_coordinate.dart`: owns Package Path plus Skill Name value equality and collision-safe internal keys shared across App journeys.

## Architectural Boundary

This module owns App-facing product vocabulary and behavior-free contracts. Focused model files may depend on lower-level model files in the order `system -> discovery/installation -> update/target-management/library`; they must not depend on Flutter, infrastructure, persistence, process implementations, or UI state.

`skills_gateway.dart` is the stable import seam for callers. New domain behavior belongs in the focused model that owns its invariants rather than accumulating in the re-export barrel.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
