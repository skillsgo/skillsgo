# App UI Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `app_shell.dart`: gates clean installs through Mandatory Onboarding, then composes the desktop shell, primary destination navigation, App-scoped appearance state, and CLI recovery banner.
- `ui_support.dart`: centralizes localized failure copy, status labels, target identities, folder-theme conversion, and small operation-result primitives shared by independent journey libraries.
- `bidirectional_content.dart`: detects the direction of independently authored content embedded in localized UI.
- `app_providers.dart`: defines the application-scoped Riverpod dependency boundary for `SkillsGateway`.
- `agent_catalog_controller.dart`: owns the App-scoped stale-while-revalidate Agent catalog, periodic refresh, lifecycle-safe single-flight loading, and mutation invalidation.
- `appearance_controller.dart`: owns immutable App appearance and language settings plus their optimistic persistence through Riverpod.
- `discover_controller.dart`: owns immutable, race-safe Discover route and Repository-summary caches, search, locale reload, loading, errors, and pagination through Riverpod.
- `discover_screen.dart` and `discover/`: expose the Discover destination while hiding leaderboard search, collection rendering, navigation recovery, desktop refresh, and Repository identity behind one screen library.
- `install_operation_controller.dart`: owns the compact Installation Request interface, per-Skill and Repository-member sequencing, aggregate execution success, and error state through a Riverpod family.
- `installation_flows.dart` and `installation/`: expose remote detail, installation selection, Update, Target Management, progress, result, and retry surfaces as one independent journey library.
- `library_controller.dart`: owns immutable Library content, stable Entry queries, targeted post-mutation reconciliation, initial-load, stale-refresh, independent Batch Takeover planning, and load-error transitions through Riverpod.
- `library_screen.dart` and `library/`: expose the unified Library journey while hiding inventory rendering, filters, selection state, local detail, exact External removal, Batch Takeover, and Repository target actions behind one screen library.
- `language_identity_icon.dart`: centralizes presentation-language identity, locally vendored Circle Flags asset mapping, and the system-language fallback shared by language selectors.
- `agent_logo.dart`: centralizes Agent ID-to-SVG identity mapping and the themed initial fallback shared by installation and Library navigation.
- `bloom_color_picker/`: vendors and extends Portal Labs' MIT-licensed Bloom interaction with explicit named brand presets and desktop hover labels.
- `discrete_tabs/`: vendors and adapts Portal Labs' MIT-licensed bounce-expanding, shimmer-label pill tabs for Discover collections and appearance-mode selection.
- `design_system/`: owns the Primer-inspired semantic token interface, Radix Sand spatial primitives, Folder hierarchy, and Material 3 adapter that derives only interaction accents from the persisted seed.
- `brand.dart` and `brand/`: expose SkillsGo visual foundations and reusable Skill cards, search, feedback, trust, risk, and empty-state primitives.
- `brand_theme_presets.dart`: owns the fixed, source-traceable Simple Icons palette used to seed user-selected desktop themes.
- `color_scheme_inspector.dart` and `color_inspector/`: retain the standalone developer inspector for generated Material 3 roles; it is intentionally not routed into user Settings.
- `install_location_popover.dart` and `install_location/`: expose the shared anchored installation selector while hiding menu anchoring, async loading, scope selection, and location cards.
- `install_location_island/`: vendors and adapts Portal Labs' Todo List Interaction into the composable installation scope, project, and Agent selector.
- `nested_navigation.dart` and `navigation/`: render the accessible side rail, item densities, fixed sections, selected capsule motion, desktop layout, destination-wide foreground surfaces, and reduced-motion-aware secondary-body entrances.
- `onboarding_screen.dart` and `onboarding/`: expose the blocking two-step clean-install journey while hiding welcome, Agent inventory, project selection, and project-row rendering.
- `native_components.dart` and `native/`: expose the Material-only desktop component layer while partitioning buttons/loading, cards/selection, and feedback/input controls.
- `primary_folder_shell.dart`: adapts Portal Labs' MIT-licensed FolderTabs shape and spring motion into an accessible, full-height SkillsGo shell that preserves destination page state.
- `physics_collision_field.dart`: vendors and adapts Portal Labs' Physics Collision Card into a deterministic, reduced-motion-aware interaction primitive for explanatory product scenes.
- `archive_folder/`: vendors Portal Labs' Archive Folder, ArchiveItem, and style, adding structured front copy, an arbitrary front-surface child slot, and opt-in fixed label geometry for reusable product content.
- `project_identity_icon.dart`: renders cached high-confidence Added Project icons with deterministic project-name monogram fallback across project selectors.
- `settings_screen.dart` and `settings/`: expose personalization, reminders, Agent detection/recovery, integration, and advanced settings as one independent screen library.
- `target_management_controller.dart`: owns immutable Target Management execution, progress, result, and error state through an auto-disposed Riverpod family.
- `update_operation_controller.dart`: owns immutable per-Skill Update execution, progress, result, error, and failed-target retry state through Riverpod.
- `skill_markdown_view.dart`: centralizes selectable Skill Markdown rendering, Material 3 semantic styling, document spacing, tables, code, quotations, and safe external links.
- `stacked_toast.dart`: vendors Portal Labs' stacked spring interaction and adapts it into compact, theme-aware, lightweight transient operation feedback.
- `subscription_segmented_switch.dart`: vendors the Portal Labs Subscription Pricing Picker period toggle as a controlled, HugeIcons-based two-option Library filter.

## Architectural Boundary

This module owns rendered product behavior, navigation state, accessibility semantics, localization selection, and Burrow-inspired presentation. It consumes `SkillsGateway` domain contracts and must not implement Hub HTTP, process execution, Repository persistence, or local filesystem mutation.

Theme preference persistence crosses this boundary only through `SkillsGateway`. Ordinary UI widgets consume `ThemeData.colorScheme` or `SkillsColorTokens`; they must not derive independent palettes, access persistence directly, or replace semantic roles with fixed light/dark colors.

## Async Rendering Contract

Every asynchronous UI owner must model and render these states explicitly:

| State | Required rendering |
| --- | --- |
| `initialLoading` | Render a skeleton that matches the final region's geometry; keep shell navigation and safe actions enabled. |
| `content` | Render the last valid value without progress decoration. |
| `refreshing` | Keep the last valid value mounted and add a restrained, localized refresh signal. Never flash back to a skeleton. |
| `empty` | Render a deliberate empty state only after a successful load proves that no items exist. |
| `error` | Keep valid stale content when possible; otherwise render localized recovery with an explicit retry action. |

Implementation rules:

- Skeletons are reusable semantic components from the native component layer, use neutral design tokens, preserve final radii and spacing, respect reduced motion, and are excluded from the accessibility tree. The containing region announces one localized loading label.
- Discovery cold loads use card-shaped skeletons with the same responsive grid as real Skill cards. Pagination and collection refresh retain existing cards.
- Library cold loads use row/card skeletons for local CLI inspection. Re-detection and Hub enrichment retain the last local inventory.
- Skill detail renders summary-known identity and navigation immediately; instructions, evidence, files, installation targets, and repository data may load as independent skeleton regions.
- Installation surfaces open on the initiating frame using known Skill summary data. Agent targets, Added Projects, risk policy, remote detail, and repository Skills load inside the surface; optional repository enumeration cannot block location selection.
- Avoid global modal spinners when the final layout is known. Avoid skeletons for sub-150 ms local state changes, button presses, or mutations with determinate progress.
- Tests must assert skeleton geometry keys, next-frame surface visibility, stale-content preservation, localized loading/error semantics, and replacement without layout overflow. Animation tests must also cover `MediaQuery.disableAnimations`.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
