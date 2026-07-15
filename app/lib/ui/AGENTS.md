# App UI Module
> F3 | Parent: `/app/AGENTS.md` | Workspace: `skillsgo`

## Members

- `app_shell.dart`: renders the desktop shell and stateful Discover collections, explicit shadcn_ui Installation Plan matrix/conflict-risk preflight/live progress/failed-only retry, searchable managed/external multi-target Library/detail, project and Agent views, operations, and Settings journeys.
- `brand.dart`: composes shadcn_ui primitives with reusable SkillsGo tokens, discovery cards, trust/risk indicators, fields, status elements, and empty states.
- `nested_navigation.dart`: renders the shared accessible side rail, selected capsule motion, and desktop rail/content layout.

## Architectural Boundary

This module owns rendered product behavior, navigation state, accessibility semantics, localization selection, and Burrow-inspired presentation. It consumes `SkillsGateway` domain contracts and must not implement Registry HTTP, process execution, Store behavior, or local filesystem mutation.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
