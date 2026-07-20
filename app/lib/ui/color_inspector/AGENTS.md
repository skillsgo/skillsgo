# Color Scheme Inspector
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `inspector_screen.dart`: composes the standalone developer-only color inspection screen.
- `token_grid.dart`: arranges semantic color tokens for comparison.
- `color_role_card.dart`: renders one role, value, foreground pairing, and contrast sample.
- `component_preview.dart`: previews representative Material and SkillsGo components.
- `color_models.dart`: defines small inspector-only role descriptors.

## Architectural Boundary

This module is a development aid for inspecting generated themes. It may render design tokens but must not become a production Settings route or define new product color semantics.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
