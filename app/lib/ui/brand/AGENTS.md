# Brand Components
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `brand_foundations.dart`: defines background, typography, spacing, status roles, and exported design-system access.
- `skill_search_field.dart`: provides the responsive, keyboard-ready Skill search control.
- `skill_cards.dart`: renders reusable Skill summaries, metadata, trust, risk, and actions.
- `skill_feedback.dart`: renders compact loading, error, empty, and status feedback.

## Architectural Boundary

This module owns reusable SkillsGo presentation identity. It consumes semantic theme tokens and domain display values; it must not own route state, persistence, discovery requests, or installation execution.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
