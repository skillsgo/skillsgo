# Library Journey
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `library_screen_core.dart`: owns Library lifecycle, navigation state, exact takeover-count presentation, controller subscriptions, and destination composition.
- `library_body.dart`: selects loading, content, empty, and failure bodies without discarding valid stale inventory.
- `library_filters.dart`: renders location, Agent, provenance, and search filters.
- `library_selection.dart`: owns filtered selection, select-all, batch actions, and toolbar motion.
- `library_actions.dart`: coordinates refresh, project, plan-authorized takeover, export, update, and target actions.
- `batch_takeover_presentation.dart`: renders the localized, responsive Batch Takeover dialog whose Before/After story opens both folders after confirmation, flies only confirmed successes into an orderly managed grid, and preserves retry and reduced-motion behavior.
- `installed_skill_groups.dart`: groups logical Skills and their location-aware targets.
- `installed_skill_rows.dart`: renders installed entries, provenance, diagnostics, and row actions.
- `local_detail_core.dart`: owns local-detail loading, retry, target operations, and enrichment lifecycle.
- `local_detail_rendering.dart`: renders local detail, metadata, targets, and failure recovery.

## Architectural Boundary

This module owns the local-first Library presentation and selection model. Hub enrichment may add metadata but must never replace local inventory, reset the selected location, or authorize mutation without an exact CLI-backed target.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
