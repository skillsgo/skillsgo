# Library Selection UI Design QA

- Source visual truth: `/var/folders/71/_sx7yq7932b3nsf8dxhxwkdr0000gn/T/codex-clipboard-7d34be64-3ce4-4cbb-aeec-ca8278ba3982.png`
- Implementation screenshot: `/tmp/skillsgo-library-unselected.png`
- Viewport: macOS desktop, 1970 × 1286 display capture; SkillsGo window approximately 1460 × 970
- State: Library content with no selected rows; selected-row behavior and floating action-bar visibility are covered by the Library widget tests

## Full-view comparison evidence

The implementation follows the source's primary visual structure: a flat page-backed list, compact two-line Skill identities, leading checkboxes, one-pixel row separators, right-aligned Agent coverage, and no per-row status or overflow action. SkillsGo intentionally retains repository grouping, the existing search/filter header, and the product Folder shell because the requested change does not alter information architecture.

## Focused region comparison evidence

The list region was inspected at native desktop scale. Names retain a semibold hierarchy, descriptions truncate to one line, checkboxes align on a stable leading track, and Agent marks occupy a separate right-side region. The selected state uses a restrained surface tint and a three-pixel primary leading rule. The floating selection bar uses the source's bottom-centered capsule composition while exposing only the existing Update, Manage Targets, and exact External Removal journeys.

## Required fidelity surfaces

- Fonts and typography: Existing SkillsGo fonts are retained intentionally; name weight, description size, line height, and truncation match the reference hierarchy.
- Spacing and layout rhythm: Rows are compact and separator-driven. Repository headers add deliberate grouping not present in the reference matrix. Bottom list padding prevents the floating action bar from obscuring the final row.
- Colors and visual tokens: All surfaces, focus/selection accents, disabled actions, and dividers use the existing Material 3 and SkillsGo semantic roles in place of copied fixed dark colors.
- Image quality and asset fidelity: Existing Agent and repository assets are reused at native resolution; no placeholder or code-drawn assets were introduced.
- Copy and content: Existing localized Update, Manage Targets, and Remove language is preserved. New selection-count and clear-selection copy is localized in English and Simplified Chinese.

## Findings

- No actionable P0, P1, or P2 differences remain.
- P3: Repository avatars and headers create more vertical grouping than the source matrix. This is intentional because repository grouping remains part of the existing Library information architecture.
- P3: The retained SkillsGo Folder shell makes the overall frame visually heavier than the reference. The list surface itself matches the requested density and operation model.

## Interaction verification

- Selecting a Library row reveals the floating selection bar.
- Clearing selection removes the bar.
- Update is disabled when no selected entry has an available update.
- Update and Manage Targets reuse the existing per-entry preflight and exact-target dialogs.
- External-only selection labels the management action as Remove.
- Reduced-motion mode removes the selected-row transition.
- Flutter analysis and the complete App test suite pass.

## Comparison history

1. Initial implementation: the list matched the flat-row direction, but the floating selection bar could cover the final list row and external-only selection used the generic Manage Targets label.
2. Final implementation: dynamic bottom padding was added and external-only selection now preserves the localized Remove label.

final result: passed
