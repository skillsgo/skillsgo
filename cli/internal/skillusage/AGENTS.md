# CLI Skill Usage Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `codex.go`: incrementally indexes trusted Codex rollout evidence with bounded independent-Session workers while preserving per-Session event order, then merges explicit user-role Skill injection and call-ID-correlated successful `SKILL.md` instruction loads into disposable per-day cache buckets and returns 45/90-day aggregates.
- `codex_test.go`: specifies trusted evidence classification, false-positive rejection, pending read correlation, session-level deduplication, multi-worker-batch aggregation, rolling-window boundaries, cache reuse, and stale-session removal.
- `copilot.go`: scans GitHub Copilot CLI durable Session events and counts only explicit `skill.invoked` records with a resolved Skill path, deduplicated per Session.
- `copilot_test.go`: specifies GitHub Copilot discovery-list rejection, explicit invocation attribution, namespaced-name normalization, Session deduplication, and rolling windows.
- `claude.go`: scans Claude Code project transcripts and counts call-ID-correlated successful `Skill` tool executions plus slash commands whose matching Skill body was actually injected, normalizing plugin-qualified names to inventory Skill names.
- `claude_test.go`: specifies Claude configuration-root resolution, namespaced-name normalization, successful-tool correlation, verified slash-command injection, failure rejection, Session deduplication, and rolling-window boundaries.
- `reasonix.go`: scans Reasonix primary Session transcripts and counts only call-ID-correlated successful `read_skill`, `run_skill`, `read_only_skill`, and compatible `use_skill` tool executions.
- `reasonix_test.go`: specifies Reasonix sidecar exclusion, successful-tool correlation, failure rejection, Session deduplication, configured-home resolution, and rolling-window boundaries.
- `opencode.go`: queries only completed OpenCode Skill-tool metadata from schema-guarded read-only SQLite databases and aggregates unique Session/name observations without reading conversation content.
- `opencode_test.go`: specifies OpenCode completed-state filtering, Session deduplication, rolling windows, configured database resolution, and missing-database behavior.

## Architectural Boundary

This module owns read-only interpretation of supported Agent session evidence and disposable usage caches. It must not mutate Agent logs, Skill installations, declarations, locks, or update state, and cache failures must not make Library inventory unavailable.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
