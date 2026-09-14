# Bloom Picker Implementation
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `picker_state.dart`: owns controlled selection, hover labels, keyboard behavior, and animation state.
- `picker_surface.dart`: composes the closed picker and visual selection surface.
- `open_content.dart`: renders expanded presets, hue choices, and interaction affordances.
- `lightness_slider.dart`: renders and controls lightness selection.
- `painters_and_curves.dart`: provides bounded custom painters and motion curves.

## Architectural Boundary

This module is the internal implementation of the vendored Bloom interaction. It may adapt the interaction to SkillsGo themes and accessibility, but its public API remains owned by the parent library and upstream attribution must remain intact.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
