# CLI Skill Usage Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `codex.go`: incrementally indexes Codex rollout Skill activation evidence into disposable per-day cache buckets and returns 45/90-day aggregates.
- `codex_test.go`: specifies session-level deduplication, rolling-window boundaries, cache reuse, and stale-session removal.

## Architectural Boundary

This module owns read-only interpretation of supported Agent session evidence and disposable usage caches. It must not mutate Agent logs, Skill installations, declarations, locks, or update state, and cache failures must not make Library inventory unavailable.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
