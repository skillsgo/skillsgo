# App Domain Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `skills_gateway.dart`: defines the stable application-facing Gateway interface and re-exports the complete domain vocabulary for compatibility.
- `system_models.dart`: owns cross-journey status enums, exact update availability candidates, appearance settings, process contracts, command results, and typed failures.
- `discovery_models.dart`: owns public Skill summaries, repository metadata, discovery pages, auditable files, and risk evidence.
- `installation_models.dart`: owns Installation Request target selection, execution results, failures, and stable target identity.
- `update_models.dart`: owns reviewed Update Plans, target results, execution summaries, and progress.
- `target_management_models.dart`: owns reviewed managed Repository-member and External Installation removal plans, execution results, and progress.
- `library_models.dart`: owns Agent catalogs, Added Projects, onboarding state, Skill detail, unified Library entries, and Batch Takeover scope/plan/result values.
- `presentation_language.dart`: owns the persisted Presentation Locale value and BCP 47 content tag resolution.

## Architectural Boundary

This module owns App-facing product vocabulary and behavior-free contracts. Focused model files may depend on lower-level model files in the order `system -> discovery/installation -> update/target-management/library`; they must not depend on Flutter, infrastructure, persistence, process implementations, or UI state.

`skills_gateway.dart` is the stable import seam for existing callers. New domain behavior belongs in the focused model that owns its invariants rather than accumulating in the compatibility barrel.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
