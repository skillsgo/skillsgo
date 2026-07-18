# Logging
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `log.go`: constructs the Hub logger and selects the runtime output handler.
- `entry.go` and `entry_slog.go`: define the structured Entry interface and its slog-backed implementation.
- `log_context.go`: carries correlated log entries through request and background contexts.
- `format.go`: implements plain, JSON, and cloud-compatible output formatting.
- `redact.go`: removes credentials from structured attributes and formatted messages before emission.
- `log_test.go`: verifies formatting, filtering, fields, and credential redaction.

## Architectural Boundary

This module owns the Hub's logging abstraction, output formatting, contextual correlation, and last-line credential redaction. Callers own event selection and domain fields; this module must not log request bodies, artifact content, complete configuration values, or raw credentials.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
