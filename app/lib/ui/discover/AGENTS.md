# Discover Journey
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `discover_screen_core.dart`: owns route-local state, controller subscriptions, lifecycle, and the public destination widget.
- `discover_rendering.dart`: renders collection, query, repository, loading, empty, and failure states.
- `discover_navigation.dart`: owns detail transitions, focus restoration, repository routing, and installation entry points.
- `desktop_discover_scroller.dart`: implements bounded desktop pull-to-refresh behavior and scroll coordination.
- `repository_source_header.dart`: renders auditable repository identity and source metadata.

## Architectural Boundary

This module owns the Discover presentation journey. It consumes Riverpod controllers and public installation surfaces, preserves route-local state, and must not execute CLI commands, persist preferences, or own installation mutations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
