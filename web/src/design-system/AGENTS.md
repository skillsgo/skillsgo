# Design System/
> F3 | Parent: `web/AGENTS.md` | Workspace: `@skillsgo/web`

## Members

- `tokens.css`: canonical semantic visual values shared across product, documentation, and blog surfaces.
- `content.tsx`: editorial content patterns whose structure is stable across route types.
- `shells.tsx`: product and documentation composition shells plus the shared site footer.
- `index.ts`: intentionally small public interface for route adapters.

## Architectural Boundary

This module owns the shared visual interface for SkillsGo Web. It hides typography, spacing, page composition, and recurring editorial structure behind a small React and CSS interface. It must not own product copy, route loading, Fumadocs content queries, page-specific interaction state, or Hub domain behavior.

Routes are adapters at this seam. Fumadocs is the documentation adapter and must map onto these semantic tokens instead of creating a second visual language. Add a reusable pattern only after at least two concrete callers need the same behavior.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
