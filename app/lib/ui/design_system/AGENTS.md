# SkillsGo Design System
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `radix_palette.dart`: provides the source-pinned Radix Colors 3.0.0 Sand neutral scales plus status Container, Solid, and Foreground tones used by SkillsGo themes.
- `skills_color_tokens.dart`: records the Primer Primitives 11.9.0 provenance and defines Primer-inspired semantic color roles, including the Folder hierarchy, as a Flutter `ThemeExtension`.
- `skills_component_tokens.dart`: maps Primer 11.9.0 control, button, card, overlay, side-navigation, and focus state conventions into reusable SkillsGo component tokens.
- `skills_theme.dart`: builds the complete SkillsGo `ThemeData`, deriving only accent roles from the user seed and mapping stable product tokens into Material 3 roles.

## Architectural Boundary

This module owns the visual token contract for SkillsGo. Callers choose a seed and brightness, then consume semantic roles; they must not derive independent palettes or depend on Radix scale positions directly. The user seed controls identity and interaction emphasis, while neutral spatial hierarchy, readable foregrounds, and status meaning remain stable. Upstream palette values and semantic references must be taken from pinned official releases with license and integrity metadata recorded in `THIRD_PARTY_NOTICES.md`.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
