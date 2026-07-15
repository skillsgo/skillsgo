# App UI Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `app_shell.dart`: renders the desktop shell and stateful Search, Ranking, Trending, Hot, Library, auditable detail, operation, and Settings journeys.
- `brand.dart`: composes shadcn_ui primitives with reusable SkillsGo tokens, discovery cards, trust/risk indicators, fields, status elements, and empty states.
- `nested_navigation.dart`: renders the shared accessible side rail, selected capsule motion, and desktop rail/content layout.

## Architectural Boundary

This module owns rendered product behavior, navigation state, accessibility semantics, localization selection, and Burrow-inspired presentation. It consumes `SkillsGateway` domain contracts and must not implement Registry HTTP, process execution, Store behavior, or local filesystem mutation.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
