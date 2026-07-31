# Settings Journey
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `settings_screen_core.dart`: owns settings-route state, lifecycle, explicit App-update phase/result/error state, local Library refresh and diagnostic-log feedback, and secondary-body composition.
- `settings_sections.dart`: renders the General, Reminders, Agents, and Advanced route structure, including App updates, Onboarding re-entry, local Library refresh, bounded diagnostic-log controls, and the final Mermaid gallery entry.
- `app_update_settings.dart`: renders the production App-binary update status and explicit check/apply-and-restart actions independently from Package updates.
- `diagnostic_log_viewer.dart`: renders the bounded newest-first human-readable live diagnostic stream with filtering, search, pause/follow, local clear, mutation-safe per-entry copying, and latest-entry recovery.
- `mermaid_gallery.dart`: renders a 32-type official Mermaid.js 11.16.0 audit gallery backed by the App's single shared WebView queue.
- `appearance_settings.dart`: renders folder theme, appearance mode, wallpaper, and related controls.
- `integration_settings.dart`: renders CLI, the single Hub Origin, storage, reminders, and recovery controls.
- `language_selector.dart`: renders and persists Presentation Locale selection.
- `agent_status_row.dart`: renders one detected or supported Agent state.

## Architectural Boundary

This module owns settings presentation and immediate user feedback. Preference and integration mutations cross `SkillsGateway`; widgets must not access SharedPreferences, HTTP, processes, or filesystem state directly.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
