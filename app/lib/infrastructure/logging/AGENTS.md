# App Logging Module
> F3 | Parent: `/app/lib/infrastructure/AGENTS.md` | Workspace: `skillsgo`

## Members

- `app_logger.dart`: owns the package:logging integration, App session and operation correlation, centralized sanitization, bounded structure-preserving JSON previews, recent/live entries, and file/console dispatch.
- `human_log_formatter.dart`: owns the fixed-order human-readable text and pretty-printed JSON response previews shared by disk persistence and the live viewer.
- `rolling_text_log_sink.dart`: owns serialized text append, size rotation, seven-day retention, legacy JSONL removal, and total-directory capacity enforcement.

## Architectural Boundary

This module owns local App observability mechanics. Callers emit categorized structured events and must not write log files, serialize private payloads, parse persisted logs for live UI, or implement independent retention policies. Logging failure must never change product behavior.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
