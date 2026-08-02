# Agent Project Discovery Research

## Purpose

This note evaluates whether SkillsGo can seed its project registry from durable local Agent metadata without crawling arbitrary filesystem roots or reading prompt and response bodies. The evidence is limited to official source repositories and official product documentation inspected on 2026-08-02.

The preferred source is a small project registry or per-session metadata file. A session database is acceptable only when it exposes a narrow read-only query. Formats that require parsing conversation bodies, reverse-engineering editor-owned databases, or guessing a path from a one-way hash are not recommended.

## Recommended implementation order

| Tier | Agents | Discovery source |
| --- | --- | --- |
| Implement now | Gemini CLI, Kimi Code CLI, Continue, Mistral Vibe, Cline, Roo Code, Goose, OpenCode | Explicit registries, metadata indexes, or narrow session-table queries |
| Reuse compatible adapter after fixture validation | Qwen Code, Kilo Code | Qwen's project store and Kilo's OpenCode-derived store are active migrations; pin fixtures before enabling |
| Keep existing | Claude Code, Codex | Structured JSONL metadata already supported by SkillsGo |
| Do not implement yet | Cursor, Aider/AiderDesk, iFlow CLI, OpenHands, Warp, Zed, GitHub Copilot CLI | No verified stable, local, bounded path-to-project contract from first-party evidence |

All adapters should treat the source as read-only, canonicalize and validate the resulting directory, use the source record's update time for recency, and never retain session titles, prompts, messages, repository credentials, or remote identifiers.

## Agent findings

### Gemini CLI — recommend

- Official repository: `google-gemini/gemini-cli`, inspected at `f47d6c6`.
- Evidence: `packages/core/src/config/storage.ts` initializes `ProjectRegistry` at `~/.gemini/projects.json`; `packages/core/src/config/projectRegistry.ts` defines `RegistryData.projects` as an absolute project-path to short-id map. Official session documentation places chats below `~/.gemini/tmp/<project_id>/chats/`.
- Project field: each key of top-level `projects`.
- Bounded read: yes. Read one small JSON registry; no session file is required.
- Adapter: read `~/.gemini/projects.json`, collect the keys, and optionally derive activity from the mapped temp directory's mtime. This is materially safer than opening chat JSONL.

### Kimi Code CLI — recommend

- Official repository: `MoonshotAI/kimi-cli`, inspected at `4a550ef`.
- Evidence: `src/kimi_cli/share.py` defaults the share directory to `~/.kimi`; `src/kimi_cli/metadata.py` stores `kimi.json`, whose `work_dirs[]` entries contain `path`, `kaos`, and `last_session_id`. `src/kimi_cli/session.py` creates sessions through this registry.
- Project field: `work_dirs[].path`; accept only entries whose `kaos` denotes the local filesystem.
- Bounded read: yes. `~/.kimi/kimi.json` is a dedicated registry and contains no conversation body.
- Adapter: parse the registry and use its mtime, or the referenced session directory mtime, as recency.

### Continue — recommend

- Official repository: `continuedev/continue`, inspected at `5522c6f`.
- Evidence: `core/util/paths.ts` defines `~/.continue/sessions/sessions.json`; `core/util/history.ts` persists `BaseSessionMetadata` entries with `workspaceDirectory`, `dateCreated`, and `messageCount`, while full histories live in separate per-session JSON files.
- Project field: array item `workspaceDirectory`.
- Bounded read: yes. Read only `sessions.json`, never `<session-id>.json`.
- Adapter: parse the metadata list and rank by `dateCreated`; ignore empty or non-local URI values.

### Mistral Vibe — recommend

- Official repository: `mistralai/mistral-vibe`, inspected at `99a6efa`.
- Evidence: `vibe/core/config/models.py` defaults `session_logging.save_dir` to `~/.vibe/logs/session`; `vibe/core/session/session_logger.py` writes a small `meta.json` with `environment.working_directory`; `vibe/core/session/session_loader.py` reads that field independently of `messages.jsonl`.
- Project field: `session_*/meta.json` → `environment.working_directory`.
- Bounded read: yes. Each session has a separate metadata file.
- Adapter: scan recent session directories and parse only `meta.json`. Respect a user-customized save directory only when SkillsGo has an explicit configuration seam; do not parse Vibe configuration heuristically in the first version.

### Cline — recommend

- Official repository: `cline/cline`, inspected at `1654517`.
- Evidence: `apps/vscode/src/sdk/legacy-state-reader.ts` defines the shared data root priority and defaults to `~/.cline/data`, with history at `state/taskHistory.json`; `apps/vscode/src/sdk/cline-session-factory.ts` persists `HistoryItem.cwdOnTaskInitialization`. Source comments state that all platforms migrate to the shared file-backed store.
- Project field: history item `cwdOnTaskInitialization`.
- Bounded read: yes. The task-history index is separate from `tasks/<id>/` conversation artifacts.
- Adapter: read `~/.cline/data/state/taskHistory.json`. A compatibility fallback may inspect VS Code's `saoudrizwan.claude-dev` global-storage history, but it should be isolated as a legacy path and covered by platform fixtures.

### Roo Code — recommend

- Official repository: `RooCodeInc/Roo-Code`, inspected at `b867ec9`.
- Evidence: `src/core/task-persistence/TaskHistoryStore.ts` documents and reads `globalStorage/tasks/_index.json`; `src/core/task-persistence/taskMetadata.ts` requires `workspace`; `src/core/task/Task.ts` persists the task cwd into that field.
- Project field: index item `workspace`.
- Bounded read: yes. `_index.json` is an explicit metadata index, while task messages remain in per-task artifacts.
- Adapter: enumerate known official editor global-storage roots and parse only `tasks/_index.json`. Keep the editor-path matrix explicit because Roo is an extension rather than a standalone home-directory owner.

### Goose — recommend

- Official repository: `block/goose`, inspected at `20bb609`.
- Evidence: `crates/goose/src/config/paths.rs` derives the application data directory (on macOS, the backward-compatible `Block/goose` application-data location); `crates/goose/src/session/session_manager.rs` stores `sessions/sessions.db`, whose `sessions` table has `working_dir` and `updated_at` columns.
- Project field: SQL `sessions.working_dir`.
- Bounded read: yes, through a read-only SQLite connection and `SELECT working_dir, MAX(updated_at) ... GROUP BY working_dir`. No message table is needed.
- Adapter: account for `GOOSE_PATH_ROOT` only if it is available to the SkillsGo process; otherwise inspect the platform-default data root. Open the database read-only and tolerate WAL activity.

### OpenCode — recommend with a database-version guard

- Official repository: `anomalyco/opencode`, inspected at `1882c33`.
- Evidence: `packages/core/src/global.ts` uses the XDG data directory under `opencode`; `packages/core/src/database/database.ts` selects `opencode.db` for production channels; `packages/core/src/session/sql.ts` defines `session.directory` and `session.time_updated`.
- Project field: SQL `session.directory`.
- Bounded read: yes, through a read-only SQLite query over the session table only.
- Adapter: discover the platform XDG data location, verify the `session` table and required columns, then query distinct directories ordered by `MAX(time_updated)`. If the schema is absent or channel-specific database naming is unknown, skip safely instead of probing message storage.

### Qwen Code — fixture first

- Official repository: `QwenLM/qwen-code`, inspected at `563f744`.
- Evidence: `packages/channels/base/src/paths.ts` defines `~/.qwen`; `packages/core/src/config/storage.ts` maps a cwd-derived project id to `~/.qwen/projects/<id>`; official daemon documentation describes workspace-qualified session stores below each project's `chats/` directory.
- Project field: no first-party, dedicated global path registry was confirmed in the inspected version. The project directory name is derived from cwd, but relying on that encoding without an explicit decode contract would be brittle.
- Bounded read: potentially, if a current session JSONL metadata header contains cwd, but this needs a checked fixture.
- Recommendation: do not enable by assumption. Add a real current-version fixture and prove a metadata-only, bounded extraction, or wait for a path registry. Do not copy Gemini's adapter merely because the projects are historically related.

### Kilo Code — fixture first

- Official repository: `Kilo-Org/kilocode`, inspected at `c554409`.
- Evidence: the repository contains an OpenCode-derived runtime with the same session `directory` concept, while `packages/kilo-vscode/src/legacy-migration` still imports editor global-storage task data. This is an active persistence migration rather than one stable public layout.
- Project field: likely OpenCode session `directory`; legacy VS Code records may expose cwd/workspace through migrated task metadata.
- Bounded read: technically yes, but the authoritative store and application data root vary by product generation.
- Recommendation: add only after collecting current desktop/CLI fixtures and identifying a version marker. Avoid reading both stores indiscriminately, which would duplicate or resurrect migrated projects.

### Claude Code — existing support

- First-party on-disk contract observed by SkillsGo: `~/.claude/projects/**/*.jsonl` records expose top-level `cwd` on typed session events.
- Project field: top-level `cwd` on an Agent-identified record.
- Bounded read: yes, when reading a bounded record rather than a complete transcript.
- Recommendation: retain the current adapter and fixture coverage. Do not infer cwd from the encoded parent directory name.

### Codex — existing support

- First-party on-disk contract observed by SkillsGo: `~/.codex/sessions/**/*.jsonl` starts with a typed `session_meta` record whose `payload.cwd` identifies the working directory.
- Project field: `type == "session_meta"` → `payload.cwd`.
- Bounded read: yes, with a bounded decoder sized for the metadata record; no response item is needed.
- Recommendation: retain the current adapter and its oversized-metadata regression test.

### Aider and AiderDesk — do not support yet

- Official Aider repository: `Aider-AI/aider`, inspected at `5dc9490`.
- Evidence: Aider resolves the current Git root in `aider/main.py` and writes chat history in user-selected or project-oriented files, but the inspected source exposes no global recent-project registry containing an absolute path. Git and shell `cwd` usages are runtime behavior, not durable discovery metadata.
- Bounded read: no verified global metadata source.
- Recommendation: do not crawl for `.aider*` files and do not parse chat logs. AiderDesk requires separate first-party source evidence before support.

### iFlow CLI — do not support yet

- Official repository: `iflow-ai/iflow-cli`, inspected at `4642808`.
- Evidence: the official repository currently contains documentation and installers, not the runtime source. Official docs describe project-hash-scoped paths such as `~/.iflow/tmp/<project_hash>`, but no reversible path registry or metadata-only cwd record.
- Bounded read: not proven.
- Recommendation: wait for an official source or documented project registry. Do not guess that its Gemini-derived storage remains wire-compatible.

### OpenHands — do not use for local path discovery

- Official repository: `All-Hands-AI/OpenHands` (existing local checkout inspected).
- Evidence: `openhands/storage/data_models/conversation_metadata.py` stores `selected_repository` and branch, not a host cwd; `openhands/storage/locations.py` places metadata below `sessions/<id>/metadata.json`. Runtime workspace mount paths describe sandbox topology rather than a durable user project path.
- Bounded read: metadata is bounded, but it does not provide the required local path.
- Recommendation: do not turn remote repository identifiers into guessed filesystem paths.

### GitHub Copilot CLI — do not support yet

- Official repository: `github/copilot-cli`, inspected at `2392889`.
- Evidence: this distribution repository contains binaries/install assets rather than runtime source. Its official changelog states that sessions are under `~/.copilot/session-state`, that working directories persist, and that the resume picker displays them, but it does not specify a stable record schema.
- Bounded read: not proven from first-party source.
- Recommendation: wait for a documented SDK listing method or an open record schema. Do not reverse-engineer opaque state files.

### Cursor — do not support yet

- Cursor is not represented by a first-party open runtime repository with a documented local session-to-workspace schema.
- Editor workspace databases and VS Code-derived state may expose paths, but they are editor internals, not an Agent metadata contract.
- Recommendation: do not query Cursor's internal SQLite/state databases until Cursor documents a stable local API or schema.

### Warp — do not support yet

- Warp does not publish a first-party open runtime with a documented durable Agent session cwd schema.
- Recommendation: do not infer projects from shell history or terminal launch directories; those are broader than Agent activity and create privacy and relevance problems.

### Zed — do not use the editor database as Agent evidence

- Official repository: `zed-industries/zed`, inspected at `ce6f3af`.
- Zed persists editor workspaces/worktrees, and its source contains database-backed workspace restoration. That identifies editor projects, not necessarily projects used with Zed's Agent, and the schema is an internal editor migration surface.
- Recommendation: do not include it in Agent-derived cold start. If SkillsGo later adds an explicit "import editor workspaces" feature, evaluate Zed's workspace database under that separate user-visible contract.

## Privacy and performance boundary

The first implementation should prefer the five JSON metadata sources (Gemini, Kimi, Continue, Vibe, and Cline/Roo indexes), then add the two SQLite adapters (Goose and OpenCode) behind schema checks. Growing JSON indexes must be streamed entry by entry, so a valid entry at the end is not dropped and memory scales with one record rather than the complete registry; per-session metadata directories should be bounded by age but not silently truncated within the selected time window. SQLite queries must be read-only, select only the path and activity columns, and use grouping/ordering in the database.

"Complete" means complete for all metadata records inside the configured recency window, not complete transcript ingestion. A malformed or inaccessible source must be skipped independently so one Agent cannot prevent other Agents from seeding projects.

## Shallow clones used

The following official repositories were shallow-cloned under `/Users/freeman/Documents/Codes/research-agent-*` for this research: OpenCode, Gemini CLI, Kimi Code CLI, Continue, Cline, Roo Code, Kilo Code, Goose, Aider, Qwen Code, iFlow CLI, Mistral Vibe, Zed, and GitHub Copilot CLI. An existing local OpenHands checkout was inspected. These checkouts are research inputs only and are not build dependencies of SkillsGo.
