# Library Journey
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `library_screen_core.dart`: owns Library lifecycle, navigation state, exact takeover-count presentation, controller subscriptions, and destination composition.
- `library_body.dart`: selects loading, content, empty, and failure bodies without discarding valid stale inventory.
- `library_filters.dart`: renders location, Agent, provenance, and search filters.
- `library_selection.dart`: owns filtered selection, select-all, batch actions, and toolbar motion.
- `library_actions.dart`: coordinates refresh, project, plan-authorized takeover, exact-candidate update, and target actions.
- `batch_takeover_presentation.dart`: renders the localized modal hardware-console Batch Takeover surface with input isolation, symmetric dismissal motion, a deterministic Tetris story that places confirmed skills before four distinct LED pain-point pieces, complete planned-row clearing, in-board settlement, retry, and reduced-motion behavior.
- `adoption_review.dart`: keeps the feature-gated External group alive across normal and Adoption Review modes, runs one exact-name bounded CLI-mediated batch Source Find with App-owned description ranking, and presents user-selected Source plus the latest eligible version without invoking mutation contracts.
- `portal_split_button.dart`: contains the narrowly adapted Portal Labs 0.34.0 motion that morphs the persistent management action into Confirm while revealing and retracting Cancel.
- `installed_skill_groups.dart`: groups logical Skills and their location-aware targets.
- `installed_skill_rows.dart`: renders installed entries, provenance, diagnostics, and row actions.
- `local_detail_core.dart`: owns local-detail loading, retry, target operations, and enrichment lifecycle.
- `local_detail_rendering.dart`: renders local detail, metadata, targets, and failure recovery.

## Architectural Boundary

This module owns the local-first Library presentation and selection model. Hub enrichment may add metadata but must never replace local inventory, reset the selected location, or authorize mutation without an exact CLI-backed target.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
