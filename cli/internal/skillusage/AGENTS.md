# CLI Skill Usage Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `agentsview.go`: is the active and sole Library usage source; it owns the private `~/.skillsgo/sessions/sessions.db` archive lifecycle, coordinates one non-blocking process-local AgentsView sync, protects SQLite sidecars, publishes the latest `CallCount` snapshot or an explicit pending state, and emits coalesced process-wide analytics revisions after successful snapshots.
- `agentsview_test.go`: specifies immediate pending results, eventual isolated archive creation, private directory permissions, the stable empty per-Agent usage shape, and monotonic analytics invalidations.
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
- `hermes.go`: queries Hermes Agent state databases read-only and counts only call-ID-correlated successful `skill_view` loads plus explicit expanded Skill-command scaffolding across the default profile and named profiles.
- `hermes_test.go`: specifies Hermes successful-load correlation, failure rejection, expanded-command attribution, Session deduplication, profile aggregation, and rolling windows.
- `openclaw.go`: incrementally indexes the active OpenClaw state directory's durable current/reset/deleted Session transcripts, preserves pending read correlation in a disposable cache, and counts only successful `read` results using the returned `SKILL.md` frontmatter name as authoritative identity.
- `openclaw_test.go`: specifies OpenClaw incidental-path and failed-read rejection, authoritative frontmatter identity, Session deduplication, archived Session inclusion, path portability, rolling windows, and append-only cache continuation.
- `gemini.go`: incrementally caches Gemini CLI Session JSONL snapshots with bounded independent-file workers, preserves trusted prefixes while marking corruption incomplete, deduplicates Sessions across files, and counts only final successful `activate_skill` states after applying transcript rewinds.
- `gemini_test.go`: specifies Gemini CLI successful-state attribution, repeated-snapshot replacement, rewind handling, configured-home resolution, incremental-cache recovery, trusted corrupt prefixes, cross-file Session deduplication, and rolling windows.
- `qwen.go`: incrementally caches Qwen Code Session JSONL with bounded independent-file workers and counts only call-ID-correlated successful `skill` results across JSONC-configured runtime roots, conservatively marking unresolved relative cross-Workspace roots incomplete.
- `qwen_test.go`: specifies Qwen Code successful-result correlation, failure rejection, JSONC and environment runtime resolution, conservative relative-root completeness, corruption completeness, Session deduplication, path portability, and rolling windows.
- `goose.go`: queries Goose Session databases read-only and counts only call-ID-correlated successful `load_skill` request/response blocks across platform-native and configured data roots.
- `goose_test.go`: specifies Goose schema guarding, successful-result correlation, failure and unmatched-response rejection, supporting-file normalization, Session deduplication, timestamp compatibility, and rolling windows.
- `vibe.go`: incrementally caches Mistral Vibe Session messages with metadata-aware signatures and bounded workers, counts only correlated structured `skill` results, and conservatively reports approximate Session-time windows or unresolved relative roots as incomplete.
- `vibe_test.go`: specifies Mistral Vibe structured-result attribution, failure rejection, metadata cache invalidation, absolute/relative root completeness, Session deduplication, and rolling Session windows.
- `pi.go`: incrementally caches Pi Session JSONL with bounded workers, preserves trusted prefixes while marking corruption incomplete, and counts successful expanded Skill commands plus correlated successful `SKILL.md` reads with authoritative frontmatter names.
- `pi_test.go`: specifies Pi direct expansion and read-result attribution, failure rejection, configured Session roots, corruption and timestamp completeness, path portability, Session deduplication, and event-level rolling windows.
- `crush.go`: queries every registered Crush project database read-only and counts only call-ID-correlated successful View results whose structured metadata identifies a Skill.
- `crush_test.go`: specifies Crush project-registry resolution, schema guarding, structured Skill-result attribution, failure and unmatched-result rejection, Session deduplication, and rolling windows.
- `paths.go`: normalizes configured Agent state paths with cross-platform user-home expansion shared by usage adapters.
- `sessions.go`: discovers recent transcript files, runs bounded independent-file workers, maintains disposable per-file/per-day incremental caches, and provides latest-observation Session deduplication plus rolling-window aggregation shared by transcript-backed usage adapters.
- `cache_replace_unix.go` and `cache_replace_windows.go`: publish unique temporary usage-cache files with platform-native replace semantics.

## Architectural Boundary

This module owns read-only interpretation of supported Agent session evidence and disposable usage caches. It must not mutate Agent logs, Skill installations, declarations, locks, or update state, and cache failures must not make Library inventory unavailable.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
