# App UI Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsplay`

## Members

- `app_shell.dart`: renders the desktop shell and current Discover, Library, detail, operation, and Settings journeys.
- `brand.dart`: defines reusable SkillsPlay visual tokens, backgrounds, cards, buttons, fields, status elements, and empty states.

## Architectural Boundary

This module owns rendered product behavior, navigation state, accessibility semantics, localization selection, and Burrow-inspired presentation. It consumes `SkillsGateway` domain contracts and must not implement Registry HTTP, process execution, Store behavior, or local filesystem mutation.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
