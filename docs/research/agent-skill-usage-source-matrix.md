# Agent Skill Usage Source Matrix

Verified on 2026-08-10 against the 77 entries in
[`cli/internal/agent/catalog.go`](../../cli/internal/agent/catalog.go).

## Decision

SkillsGo should not equate a public repository, Skill discovery, or a textual
mention of a Skill with a trustworthy invocation. A new usage collector is
eligible only when the Agent has all of the following:

1. first-party source or documentation that defines the on-disk state;
2. a cross-platform way to resolve that state without guessing a Unix path on
   Windows;
3. durable evidence of a successful Skill activation, such as a completed
   Skill tool call or a call-ID-correlated successful `SKILL.md` read;
4. a Session identity and a durable event or Session timestamp that permits
   Session-level deduplication and defensible 45/90-day windows. Any upstream
   format that lacks event timestamps must be documented as approximate.

This standard deliberately rejects telemetry counters, discovery lists,
prompt-time Skill advertisements, raw user text, and failed tool attempts.

## Recommended implementation batches

| Batch | Agent | Official source | License and clone status | Durable evidence | 45/90-day confidence |
| --- | --- | --- | --- | --- | --- |
| Existing | Codex | [openai/codex](https://github.com/openai/codex/tree/b545c9404101) | Apache-2.0; shallow clone allowed | Rollout JSONL: explicit Skill injection or successful call-ID-correlated `SKILL.md` read | Implemented, high |
| Existing | Claude Code | [official documentation](https://code.claude.com/docs/en/skills) and published local transcript contract | Product source is not generally open; no source clone dependency | Project transcript JSONL: successful `Skill` tool execution or verified slash-command injection | Implemented, high |
| Existing | GitHub Copilot CLI | [github/copilot-cli](https://github.com/github/copilot-cli/tree/2392889bf7d2) | Source-available under GitHub Copilot CLI License, not OSI open source; shallow clone allowed for inspection | Durable `skill.invoked` Session events with resolved paths | Implemented, high |
| Existing | OpenCode | [anomalyco/opencode](https://github.com/anomalyco/opencode/tree/1882c33827cf) | MIT; shallow clone allowed | Completed Skill-tool metadata in SQLite | Implemented, high |
| Existing | Reasonix | [esengine/DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix/tree/eb06c32366da) | MIT; shallow clone allowed | Successful `read_skill`, `run_skill`, `read_only_skill`, or compatible `use_skill` calls | Implemented, high |
| Existing | Hermes Agent | [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent/tree/03fa32c92dd4) | MIT; shallow clone allowed | `state.db` messages: successful `skill_view` correlation or explicit expanded Skill scaffold | Implemented, high |
| Existing | OpenClaw | [openclaw/openclaw](https://github.com/openclaw/openclaw/tree/f8b7e18ee835) | MIT; shallow clone allowed | Current/reset/deleted Session JSONL: successful correlated `SKILL.md` read | Implemented, high |
| Implemented | Gemini CLI | [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli/tree/f47d6c6f7a13) | Apache-2.0; shallow clone allowed | Project chat JSONL snapshots persist the final `activate_skill(name)` state. The collector applies repeated-message replacement and rewind semantics, then counts only final `status=success` states. | High; exact event timestamp |
| Implemented | Qwen Code | [QwenLM/qwen-code](https://github.com/QwenLM/qwen-code/tree/563f7443296e) | Apache-2.0; shallow clone allowed | Runtime project chat JSONL uses a first-class `skill` tool with a validated Skill name ([SkillTool](https://github.com/QwenLM/qwen-code/blob/563f7443296e/packages/core/src/tools/skill.ts)). The collector correlates each call ID with a successful persisted result, including subagent Sessions, and resolves selected Workspace `runtimeOutputDir` overrides. | High; exact result timestamp |
| Implemented | Goose | [block/goose](https://github.com/block/goose/tree/20bb609c68f9) | Apache-2.0; shallow clone allowed | Platform data directory contains `sessions/sessions.db`; `messages` stores `session_id`, role, `content_json`, timestamp, and metadata. The collector uses a read-only schema-guarded query to correlate named [`load_skill`](https://github.com/block/goose/blob/20bb609c68f9/crates/goose/src/skills/client.rs) requests with successful results. | High; exact result timestamp |
| Implemented | Mistral Vibe | [mistralai/mistral-vibe](https://github.com/mistralai/mistral-vibe/tree/99a6efa9ca1f) | Apache-2.0; shallow clone allowed | `$VIBE_HOME/logs/session/<session>/messages.jsonl` stores structured synthetic `skill` calls and successful results for model- and user-invoked Skills. Vibe does not persist per-message timestamps, so the collector uses the Session `end_time` or active file modification time. | Invocation identity is high; 45/90 placement is Session-time approximate |
| **A2** | Kimi Code CLI | [MoonshotAI/kimi-cli](https://github.com/MoonshotAI/kimi-cli/tree/cbc15c076d17) | Apache-2.0; shallow clone allowed | `~/.kimi/sessions/<workdir-md5>/<session>/wire.jsonl` and `context.jsonl` are durable. Slash Skill execution calls `track("skill_invoked")`, reads the Skill, then injects its body ([runner](https://github.com/MoonshotAI/kimi-cli/blob/cbc15c076d17/src/kimi_cli/soul/kimisoul.py#L915-L935)); however that telemetry event is remote rather than a trustworthy local ledger. A collector must prove a stable local name/result marker before shipping. | Medium; research spike first |
| Implemented | Pi | [badlogic/pi-mono](https://github.com/badlogic/pi-mono/tree/936aff00918d) | MIT; shallow clone allowed | Durable Session JSONL records direct `/skill:name` expansion and ordinary read calls. The collector counts only persisted expansion scaffolds or correlated successful `SKILL.md` read results whose returned frontmatter supplies the authoritative Skill name. | High after false-positive fixtures; exact event timestamp |
| **A2** | Cline | [cline/cline](https://github.com/cline/cline/tree/1654517614a4) | Apache-2.0; shallow clone allowed | Task histories are durable, but storage is owned by the VS Code extension host and must be resolved through the extension's platform-specific `globalStorageUri`. Candidate evidence is a successful tool call loading an authoritative `SKILL.md`, not Skill discovery. | Medium; storage/version spike first |
| **A2** | Roo Code | [RooCodeInc/Roo-Code](https://github.com/RooCodeInc/Roo-Code/tree/b867ec914575) | Apache-2.0; shallow clone allowed | Cline-derived task histories and tool events. The same VS Code global-storage and migration risks apply; successful read/result correlation is required. | Medium; share an adapter core with Cline |
| **A2** | Kilo Code | [Kilo-Org/kilocode](https://github.com/Kilo-Org/kilocode/tree/c554409080a5) | MIT; shallow clone allowed | OpenCode/Cline-derived product with durable extension task state. Exact product-mode ownership must be detected before choosing SQLite versus VS Code task history. | Medium; do not alias blindly to OpenCode |
| Implemented | Crush | [charmbracelet/crush](https://github.com/charmbracelet/crush/tree/75791b8883df) | FSL-1.1-MIT (future MIT), source-available; shallow clone allowed | Each registered project has a `crush.db`. Successful Skill-aware `view` results persist structured `resource_type=skill` and authoritative `resource_name` metadata. The collector traverses the official project registry and correlates those results with completed View calls using read-only schema-guarded queries; it never uses the last-read table or ephemeral diagnostic logs. | High; exact result timestamp |
| **B** | Continue | [continuedev/continue](https://github.com/continuedev/continue/tree/5522c6f44ca0) | Apache-2.0; shallow clone allowed | IDE/session storage exists, but no reviewed first-party event yet distinguishes Skill activation from context discovery across IDEs. | Low until an event contract is found |
| **B** | AiderDesk | [hotovo/aider-desk](https://github.com/hotovo/aider-desk/tree/bdfb08e722c3) | Apache-2.0; shallow clone allowed | Public source is available, but Skill execution evidence and Session retention need a source-level proof. | Low |
| **B** | AstrBot | [AstrBotDevs/AstrBot](https://github.com/AstrBotDevs/AstrBot/tree/30e20318cbaa) | AGPL-3.0; shallow clone allowed | Persistent conversations exist, but the reviewed code does not yet establish a stable successful Skill-activation event. | Low |
| **B** | Deep Agents | [langchain-ai/deepagents](https://github.com/langchain-ai/deepagents/tree/6a5d93f9ba73) | MIT; shallow clone allowed | Skills middleware is open, but durable history depends on the embedding application's checkpointer; there is no universal local state root. | Not globally trustworthy without runtime discovery |
| **B** | OpenHands | [All-Hands-AI/OpenHands](https://github.com/All-Hands-AI/OpenHands/tree/71f6b0b4a901) | MIT; shallow clone allowed | Sessions may be local, containerized, or server-backed. No single desktop state root can be assumed. | Not globally trustworthy without deployment discovery |
| **B** | Zed | [zed-industries/zed](https://github.com/zed-industries/zed/tree/ce6f3af5f7ae) | GPL-3.0/AGPL-3.0/Apache-2.0 components; shallow clone allowed | Native Agent history is persisted, but the reviewed evidence does not yet prove a stable, named successful Skill invocation across Zed versions. | Medium-low |
| **B** | iFlow CLI | [iflow-ai/iflow-cli](https://github.com/iflow-ai/iflow-cli/tree/4642808afbc6) | Public source has no root license file; inspectable but not established as open source | Gemini-derived architecture is promising, but licensing and the exact persisted Skill event must be resolved first. | Do not implement before both are resolved |

The first source-verifiable batch is implemented. Kimi and the VS Code-family
Agents remain research candidates because their local success evidence or
cross-host storage ownership is not yet stable enough to report zero safely.

## Cross-platform state resolution

Collectors must resolve paths with the Agent's own policy, then normalize them
with Go's `filepath` APIs. They must never concatenate POSIX separators or
assume that an XDG path also applies to Windows.

| Agent | macOS | Linux | Windows | Skill roots relevant to identity |
| --- | --- | --- | --- | --- |
| Gemini CLI | `$HOME/.gemini/tmp/<project>/chats` | Same logical home-relative path | `%USERPROFILE%\.gemini\tmp\<project>\chats` | User `$HOME/.gemini/skills`; project `<root>/.gemini/skills` plus documented compatibility roots |
| Qwen Code | `${QWEN_RUNTIME_DIR:-$HOME/.qwen}/projects/<project>/chats`, with `QWEN_HOME` and user/selected-Workspace absolute or Workspace-relative `advanced.runtimeOutputDir` support | Same logical home-relative path | `%QWEN_RUNTIME_DIR%\projects\<project>\chats` or `%USERPROFILE%\.qwen\projects\<project>\chats` | User/project `.qwen/skills` and configured extra directories |
| Kimi Code CLI | `$HOME/.kimi/sessions` | Same | `%USERPROFILE%\.kimi\sessions` | User `$HOME/.kimi/skills` and compatibility roots; project `.kimi/skills` and compatibility roots |
| Mistral Vibe | `${VIBE_HOME:-$HOME/.vibe}/logs/session` | Same | `%VIBE_HOME%\logs\session` or `%USERPROFILE%\.vibe\logs\session` | User `$VIBE_HOME/skills` and `$HOME/.agents/skills`; project `.vibe/skills` and `.agents/skills` |
| Pi | `$HOME/.pi/agent/sessions` | Same | `%USERPROFILE%\.pi\agent\sessions` | User `$HOME/.pi/agent/skills`; project `.pi/skills` |
| Goose | Resolve with Goose's `etcetera::AppStrategy`; the source retains the legacy `Block/goose` platform namespace | Resolve with the same strategy and XDG environment | Resolve with the same strategy and Windows known folders | Global `config_dir()/skills` and `$HOME/.agents/skills`; project `.goose/skills` and `.agents/skills` |
| Cline/Roo/Kilo | Resolve the owning VS Code-compatible extension's `globalStorageUri` | Same API, not a copied macOS path | Same API under the active VS Code-compatible host | Agent-specific and compatibility roots must be mapped to the task's recorded path |
| Crush | Project registry under `$HOME/.local/share/crush/projects.json`, unless `CRUSH_GLOBAL_DATA` or XDG overrides it; each record points to a project data directory containing `crush.db` | Same | `%LOCALAPPDATA%\crush\projects.json`, with `%USERPROFILE%\AppData\Local` fallback | Configured global paths and project `.crush/skills`; invocation identity comes from persisted structured View-result metadata |

For Goose, reproducing platform paths independently is riskier than porting the
small strategy contract with table-driven tests for macOS, Linux, and Windows.
For VS Code-family Agents, the host matters: VS Code, VSCodium, and compatible
forks do not necessarily share one storage root.

## Full catalog disposition

This section accounts for every current Catalog entry. "Public source
reviewed" means a first-party repository was located and shallow-cloned. It
does not imply that a trustworthy collector is already possible.

### Already supported

`claude-code`, `codex`, `crush`, `gemini-cli`, `github-copilot`, `goose`,
`hermes-agent`, `mistral-vibe`, `openclaw`, `opencode`, `pi`, `qwen-code`,
`reasonix`.

### Official public source reviewed; collector not yet implemented

`aider-desk`, `astrbot`, `cline`, `continue`, `deepagents`, `iflow-cli`,
`kilo`, `kimi-code-cli`, `openhands`, `roo`, `zed`.

### Do not claim source-backed usage support yet

The remaining entries require a separate first-party-source discovery pass or
are primarily proprietary products. Until a source and durable evidence are
verified, SkillsGo should show usage as unavailable rather than zero:

`amp`, `antigravity`, `antigravity-cli`, `autohand-code`, `augment`, `bob`,
`codearts-agent`, `codebuddy`, `codemaker`, `codestudio`, `command-code`,
`cortex`, `cursor`, `devin`, `dexto`, `droid`, `eve`, `firebender`,
`forgecode`, `grok`, `inference-sh`, `jazz`, `junie`, `kimchi`, `kiro-cli`,
`kode`, `lingma`, `loaf`, `mcpjam`, `moxby`, `mux`, `ona`, `qclaw`, `qoder`,
`qoder-cn`, `replit`, `rovodev`, `tabnine-cli`, `terramind`, `tinycloud`,
`trae`, `trae-cn`, `warp`, `windsurf`, `workbuddy`, `zcode`, `zencoder`,
`zenflow`, `neovate`, `pochi`, `adal`.

`promptscript` and `universal` are compatibility targets rather than one
runtime with one authoritative Session store, so they must never receive a
usage collector. Their installed Skills can still inherit observations from a
concrete Agent that used the same physical Skill.

## Collector acceptance tests

Every new adapter should ship with the same cross-Agent contract:

1. macOS, Linux, and Windows path-resolution fixtures, including environment
   overrides, `~`, drive letters, and alternate separators;
2. successful call/result correlation and explicit rejection of failed,
   cancelled, or pending calls;
3. discovery-list, prompt-advertisement, arbitrary text, and incidental
   `SKILL.md` path false-positive fixtures;
4. Session-level deduplication, including resumed, forked, archived, and
   subagent Sessions when the upstream format exposes them;
5. exact 45-day and 90-day boundary tests based on event time where the
   upstream format persists it, plus explicit approximation tests otherwise;
6. read-only database access with schema guards, or append-only incremental
   JSONL parsing with disposable cache recovery;
7. partial-corruption behavior that preserves trusted observations but marks
   the Agent's usage completeness false.

## Local source inventory

The reviewed repositories are shallow working copies under
`/Users/freeman/Documents/Codes/` with the `research-agent-*` prefix, plus the
existing `codex`, `DeepSeek-Reasonix`, `hermes-agent`, `openclaw`, and
`OpenHands` checkouts. These paths are research inputs only and must not become
runtime dependencies or be documented as required SkillsGo installation
locations.
