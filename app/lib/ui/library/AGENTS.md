# Library Journey
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `library_screen_core.dart`: owns Library lifecycle, Global/Project location navigation, empty-project entry, icon-only local-inventory refresh, reviewed Adoption execution state, controller subscriptions, and destination composition.
- `library_body.dart`: selects loading, content, empty, and failure bodies without discarding valid stale inventory, composes installed groups, and renders one-at-a-time Package update cards without batch update controls.
- `library_filters.dart`: renders location, Agent, provenance, and search filters.
- `library_selection.dart`: owns the All/SkillsGo Managed/Other Installation/Updates view filter toggle, filtered selection, select-all, batch removal actions, and toolbar motion.
- `library_actions.dart`: coordinates refresh, all-provenance Global and Project location projections, plan-authorized adoption, direct Package update followed by inventory and App-scoped update-cache refresh, and exact removal actions.
- `batch_adoption_presentation.dart`: renders the localized modal hardware-console Batch Adoption surface with input isolation, symmetric dismissal motion, a borderless pending queue, a deterministic Tetris story that places confirmed skills before four distinct LED pain-point pieces, complete planned-row clearing, in-board settlement, retry, and reduced-motion behavior.
- `adoption_review.dart`: keeps the External sliver group alive across normal and Adoption Review modes, pins its single morphing action group while managed rows scroll, restricts exact-name candidate Find by a supported lock-backed Package hint when available, displays server confidence without client reordering, confirms the installation and management side effects before handoff, and hands the reviewed Source, version, and original targets to the console execution flow.
- `portal_split_button.dart`: adapts Portal Labs 0.34.0 `SplitButtonInteraction` into the controlled persistent management action, preserving localized review callbacks and stable hit regions for Confirm and Cancel.
- `installed_skill_groups.dart`: groups logical Skills and their location-aware targets and renders Scope-specific Package update cards with preview impact.
- `installed_skill_rows.dart`: renders installed entries, provenance, diagnostics, and row actions.
- `local_detail_core.dart`: owns local-detail loading, adoption-backup discovery and restore confirmation, cached update consumption, post-mutation refresh, retry, target operations, and enrichment lifecycle.
- `local_detail_rendering.dart`: renders local detail, metadata, adoption-backup recovery status, targets, and failure recovery.

## Architectural Boundary

This module owns the local-first Library presentation and selection model. Hub enrichment may add metadata but must never replace local inventory, reset the selected location, or authorize mutation without an exact CLI-backed target.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
