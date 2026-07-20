# Installation Location Selector
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `menu_contracts.dart`: defines selector callbacks, exact existing-target exclusions, labels, and option contracts.
- `menu_anchor.dart`: owns anchored overlay placement, dismissal, focus, and trigger behavior.
- `async_location_card.dart`: renders loading, retry, and resolved selector states.
- `location_card.dart`: renders user and project locations plus Agent choices while excluding exact targets already installed by the initiating surface.
- `scope_selector.dart`: renders explicit user or project scope selection.

## Architectural Boundary

This module owns selection UI for explicit installation locations and Agents. It returns user intent to its caller and must not execute an installation, infer a project, or mutate gateway state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
