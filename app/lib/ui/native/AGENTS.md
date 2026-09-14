# Native Component Layer
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `buttons_and_loading.dart`: provides buttons, progress, skeleton, and loading primitives.
- `cards_and_selection.dart`: provides cards, checkboxes, radio-style selection, and toggles.
- `feedback_and_inputs.dart`: provides fields, dialogs, alerts, dividers, tooltips, and feedback surfaces.

## Architectural Boundary

This module owns reusable Material 3 composition and accessibility behavior. Components consume semantic tokens and callbacks; they must not embed product journeys, persistence, or gateway calls.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
