# App UI Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `app_shell.dart`: renders the desktop shell with persistent, user-themeable folder-tab destination navigation and stateful Discover collections, native Material Installation, Update, Target Management, and External Adoption flows with exact-target selection, progress, offline recovery alerts, and results; searchable Hub/Local/External multi-target Library/detail that survives Hub outages; Local export; project and Agent views; operations; and Settings journeys.
- `agent_logo.dart`: centralizes Agent ID-to-SVG identity mapping and the themed initial fallback shared by installation and Library navigation.
- `bloom_color_picker/`: vendors and extends Portal Labs' MIT-licensed Bloom interaction with explicit named brand presets and desktop hover labels.
- `discrete_tabs/`: vendors and adapts Portal Labs' MIT-licensed bounce-expanding, shimmer-label pill tabs for accessible appearance-mode selection.
- `brand.dart`: owns Light and Dark Material 3 `fidelity` scheme generation from the persisted seed, defines semantic SkillsGo color roles, and composes native Flutter primitives with reusable discovery cards, trust/risk indicators, fields, status elements, and empty states.
- `brand_theme_presets.dart`: owns the fixed, source-traceable Simple Icons palette used to seed user-selected desktop themes.
- `color_scheme_inspector.dart`: renders the read-only Settings developer inspector for every generated Material 3 ColorScheme role, semantic pair, and representative native component.
- `install_location_popover.dart`: provides the shared anchored user-level/project-level installation selector used by discovery cards and Skill detail.
- `install_location_island/`: vendors and adapts Portal Labs' Todo List Interaction into the composable installation scope, project, and Agent selector.
- `nested_navigation.dart`: renders the shared accessible side rail, selected capsule motion, and desktop rail/content layout.
- `native_components.dart`: provides the Material-only desktop component layer for buttons, cards, dialogs, fields, alerts, progress, toggles, dividers, and tooltips.
- `primary_folder_shell.dart`: adapts Portal Labs' MIT-licensed FolderTabs shape and spring motion into an accessible, full-height SkillsGo shell that preserves destination page state.
- `skill_markdown_view.dart`: centralizes selectable Skill Markdown rendering, Material 3 semantic styling, document spacing, tables, code, quotations, and safe external links.

## Architectural Boundary

This module owns rendered product behavior, navigation state, accessibility semantics, localization selection, and Burrow-inspired presentation. It consumes `SkillsGateway` domain contracts and must not implement Hub HTTP, process execution, Store behavior, or local filesystem mutation.

Theme preference persistence crosses this boundary only through `SkillsGateway`. Ordinary UI widgets consume `ThemeData.colorScheme`; they must not derive independent palettes, access persistence directly, or replace semantic roles with fixed light/dark colors.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
