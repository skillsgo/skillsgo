# CLI Terminal UI Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `terminalui.go`: defines the small Document and Operation interfaces and selects Interactive or Plain rendering from terminal capabilities and policy.
- `render.go`: renders static Human documents with responsive Lip Gloss styling or deterministic plain text.
- `progress.go`: renders operation events through Bubble Tea in interactive terminals and append-only milestones in CI, pipes, and logs.
- `terminalui_test.go`: specifies automatic mode selection, CI and NO_COLOR fallback, deterministic documents, and append-only operation progress.

## Architectural Boundary

This module owns Human terminal presentation, terminal capability detection, responsive styling, and live progress. It consumes already-structured facts and operation events; it must not own command orchestration, domain decisions, filesystem mutation, Hub access, localization, or JSON/NDJSON machine contracts.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
