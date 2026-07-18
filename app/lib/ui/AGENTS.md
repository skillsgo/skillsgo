# App UI Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `app_shell.dart`: composes the desktop shell, primary destination navigation, App-scoped appearance state, CLI recovery banner, and shared UI helpers consumed by the split feature parts.
- `app_providers.dart`: defines the application-scoped Riverpod dependency boundary for `SkillsGateway`.
- `appearance_controller.dart`: owns immutable App appearance settings and their optimistic persistence through Riverpod.
- `discover_controller.dart`: owns immutable, race-safe Discover route caches, search, loading, errors, and pagination through Riverpod.
- `discover_screen.dart`: renders the Discover destination, search and collection routes, detail transitions, and installation entry points as an `app_shell.dart` library part.
- `install_operation_controller.dart`: owns immutable per-Skill direct installation execution and error state through a Riverpod family.
- `installation_flows.dart`: renders remote Skill detail plus direct confirmed Installation, Update, Target Management, risk, progress, result, and retry flows as an `app_shell.dart` library part.
- `library_controller.dart`: owns immutable Library content plus initial-load, stale-refresh, and load-error transitions through Riverpod.
- `library_screen.dart`: renders the unified, full-width Library journey with composable update, Agent, and project filters, Added Projects, exact External removal, Local detail, export, and installation targets as an `app_shell.dart` library part.
- `agent_logo.dart`: centralizes Agent ID-to-SVG identity mapping and the themed initial fallback shared by installation and Library navigation.
- `bloom_color_picker/`: vendors and extends Portal Labs' MIT-licensed Bloom interaction with explicit named brand presets and desktop hover labels.
- `discrete_tabs/`: vendors and adapts Portal Labs' MIT-licensed bounce-expanding, shimmer-label pill tabs for Discover collections and appearance-mode selection.
- `design_system/`: owns the Primer-inspired semantic token interface, Radix Sand spatial primitives, Folder hierarchy, and Material 3 adapter that derives only interaction accents from the persisted seed.
- `brand.dart`: defines the full-window photographic background behind Folder, typography, and stable status roles; exports the SkillsGo design-system interface; and composes native Flutter primitives with reusable discovery cards, trust/risk indicators, fields, status elements, and empty states.
- `brand_theme_presets.dart`: owns the fixed, source-traceable Simple Icons palette used to seed user-selected desktop themes.
- `color_scheme_inspector.dart`: renders the read-only Settings developer inspector for every generated Material 3 ColorScheme role, semantic pair, and representative native component.
- `install_location_popover.dart`: provides the shared anchored user-level/project-level installation selector used by discovery cards and Skill detail.
- `install_location_island/`: vendors and adapts Portal Labs' Todo List Interaction into the composable installation scope, project, and Agent selector.
- `nested_navigation.dart`: renders the shared accessible side rail, selected capsule motion, and desktop rail/content layout.
- `native_components.dart`: provides the Material-only desktop component layer for buttons, cards, dialogs, fields, alerts, progress, toggles, dividers, and tooltips.
- `primary_folder_shell.dart`: adapts Portal Labs' MIT-licensed FolderTabs shape and spring motion into an accessible, full-height SkillsGo shell that preserves destination page state.
- `settings_screen.dart`: renders the complete Settings journey including appearance, Agents, Hub origin, storage, risk policy, and About routes as an `app_shell.dart` library part.
- `target_management_controller.dart`: owns immutable Target Management execution, progress, result, and error state through an auto-disposed Riverpod family.
- `update_operation_controller.dart`: owns immutable per-Skill Update execution, progress, result, error, and failed-target retry state through Riverpod.
- `skill_markdown_view.dart`: centralizes selectable Skill Markdown rendering, Material 3 semantic styling, document spacing, tables, code, quotations, and safe external links.

## Architectural Boundary

This module owns rendered product behavior, navigation state, accessibility semantics, localization selection, and Burrow-inspired presentation. It consumes `SkillsGateway` domain contracts and must not implement Hub HTTP, process execution, Store behavior, or local filesystem mutation.

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
