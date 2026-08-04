# CLI Skill Usage Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `codex.go`: incrementally indexes trusted Codex rollout evidence with bounded independent-Session workers while preserving per-Session event order, then merges explicit user-role Skill injection and call-ID-correlated successful `SKILL.md` instruction loads into disposable per-day cache buckets and returns 45/90-day aggregates.
- `codex_test.go`: specifies trusted evidence classification, false-positive rejection, pending read correlation, session-level deduplication, multi-worker-batch aggregation, rolling-window boundaries, cache reuse, and stale-session removal.

## Architectural Boundary

This module owns read-only interpretation of supported Agent session evidence and disposable usage caches. It must not mutate Agent logs, Skill installations, declarations, locks, or update state, and cache failures must not make Library inventory unavailable.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
