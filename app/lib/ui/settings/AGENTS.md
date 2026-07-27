# Settings Journey
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `settings_screen_core.dart`: owns settings-route state, lifecycle, local Library refresh feedback, and secondary-body composition.
- `settings_sections.dart`: renders the General, Reminders, Agents, and Advanced route structure, including Onboarding re-entry, local Library refresh, and the final Mermaid gallery entry.
- `mermaid_gallery.dart`: renders 32-type native and Beautiful Mermaid/fallback comparisons plus an official Mermaid.js 11.16.0 gallery backed by the App's single shared WebView queue.
- `appearance_settings.dart`: renders folder theme, appearance mode, wallpaper, and related controls.
- `integration_settings.dart`: renders CLI, Hub Origin, storage, reminders, and recovery controls.
- `language_selector.dart`: renders and persists Presentation Locale selection.
- `agent_status_row.dart`: renders one detected or supported Agent state.

## Architectural Boundary

This module owns settings presentation and immediate user feedback. Preference and integration mutations cross `SkillsGateway`; widgets must not access SharedPreferences, HTTP, processes, or filesystem state directly.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
