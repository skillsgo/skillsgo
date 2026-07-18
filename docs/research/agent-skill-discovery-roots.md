# Agent Skill Managed and Discovery Roots

Verified on 2026-07-17.

## Purpose and terminology

This note verifies the skill paths for the six Agents currently aligned with
Skill Manager. It deliberately separates two kinds of data:

- **Managed root** is a SkillsGo product policy: the one root into which
  SkillsGo may create an Agent-specific projection. For the initial policy it
  remains compatible with the `skills.sh` installation catalog and aligned
  with Skill Manager where the two agree.
- **Discovery root** is an external Agent fact: a root that the Agent is
  documented or implemented to scan. Discovery roots are observational and do
  not grant SkillsGo permission to write to every such root.

Only official documentation, official source code, and first-party issue or
maintainer statements are used below. A configurable root is not treated as a
built-in root. A feature request is evidence that a path is not currently
confirmed, not evidence that the requested behavior exists.

## Recommended catalog

| Agent | SkillsGo managed user root | SkillsGo managed project root | Built-in user discovery roots | Built-in project discovery roots | Configurable discovery | Confidence |
| --- | --- | --- | --- | --- | --- | --- |
| Codex | `$CODEX_HOME/skills` | `.agents/skills` | `~/.agents/skills`; `/etc/codex/skills`; `$CODEX_HOME/skills` (deprecated compatibility) | Every `.agents/skills` from CWD through repository root | None confirmed for ordinary skill roots | Documented and source-verified |
| Claude Code | `~/.claude/skills` | `.claude/skills` | `~/.claude/skills` | Every ancestor `.claude/skills` through repository root; nested `.claude/skills` when working in a subdirectory | `.claude/skills` under directories passed with `--add-dir`; plugin skill roots | Documented |
| Cursor | `~/.cursor/skills` | `.agents/skills` | `~/.cursor/skills`; `~/.agents/skills`; `~/.claude/skills`; `~/.codex/skills` | `.cursor/skills`; `.agents/skills`; `.claude/skills`; `.codex/skills` | None confirmed in the reviewed source | Documented |
| OpenCode | `${XDG_CONFIG_HOME:-~/.config}/opencode/skills` | `.agents/skills` | `${XDG_CONFIG_HOME:-~/.config}/opencode/skills`; `~/.claude/skills`; `~/.agents/skills` | Every ancestor `.opencode/skills`, `.claude/skills`, and `.agents/skills` through the Git worktree | None confirmed in the reviewed source | Documented |
| Hermes Agent | `~/.hermes/skills` | `.hermes/skills` (skills.sh-compatible but unverified for discovery) | `~/.hermes/skills` | **None confirmed** | `skills.external_dirs` from `~/.hermes/config.yaml`, including a project directory when explicitly configured | Source-verified for user scope only |
| OpenClaw | `~/.openclaw/skills` | `<workspace>/skills` | `~/.openclaw/skills`; `~/.agents/skills` | `<workspace>/skills`; `<workspace>/.agents/skills` | `skills.load.extraDirs`; plugin skill roots | Documented and source-verified |

The managed columns are the current skills.sh-compatible SkillsGo write
targets, not claims that an Agent designates those paths as its native or sole
installation location. Discovery defaults to the managed root for unverified
Agents, but that fallback remains explicitly `unverified`; the additional roots
above should be declared only for verified Agents.

## Evidence by Agent

### Codex

The current [Codex skills documentation](https://developers.openai.com/codex/skills)
documents project discovery at each `.agents/skills` directory from the current
working directory to the repository root, user discovery at
`$HOME/.agents/skills`, and administrator discovery at `/etc/codex/skills`.
The official loader at commit
[`6138909d6ec58b2fbe635ef973e02caecad5a5aa`](https://github.com/openai/codex/blob/6138909d6ec58b2fbe635ef973e02caecad5a5aa/codex-rs/core-skills/src/loader.rs#L319-L357)
also scans `$CODEX_HOME/skills` but labels it the deprecated user location kept
for backward compatibility. It must therefore be modeled as a legacy discovery
root, not as the preferred root. The bundled installer sample still writes to
`$CODEX_HOME/skills`, which is an internal compatibility inconsistency rather
than evidence that it is the current preferred discovery root. The transition
was also discussed by an official collaborator in
[issue #10430](https://github.com/openai/codex/issues/10430).

### Claude Code

The current [Claude Code skills documentation](https://code.claude.com/docs/en/skills)
documents personal skills under `~/.claude/skills`, project skills under
`.claude/skills`, plugin-provided skill roots, ancestor traversal through the
repository root, nested project discovery, and `.claude/skills` under
`--add-dir` directories. No official source reviewed documents
`.agents/skills`. The open official repository
[feature request #31005](https://github.com/anthropics/claude-code/issues/31005)
requests that support, so `.agents/skills` must not be declared as a Claude Code
discovery root today. Legacy `.claude/commands` support concerns commands, not
skill discovery, and is excluded from the catalog.

### Cursor

The current [Cursor skills documentation](https://cursor.com/docs/skills)
lists native `.cursor/skills` roots, shared `.agents/skills` roots, and
compatibility roots for `.claude/skills` and `.codex/skills` at both project and
user scope. Cursor Skills first shipped in
[Cursor 2.4 on 2026-01-22](https://cursor.com/changelog/2-4). A first-party team
reply confirms that `/create-skill` uses the native `.cursor/skills` location in
[this official forum thread](https://forum.cursor.com/t/cursor-doesnt-know-new-skills-arens-saved/158507/5).

Symlink behavior needs a capability caveat: the Cursor IDE follows project
symlinks, while the local SDK runtime has been reported by Cursor staff to
realpath and reject targets outside the workspace in
[this tracked official forum report](https://forum.cursor.com/t/cursor-sdk-local-runtime-does-not-appear-to-load-filesystem-skills/160664).
The path declarations are valid, but SkillsGo should not claim uniform symlink
support across all Cursor runtimes.

### OpenCode

The current [OpenCode Agent Skills documentation](https://opencode.ai/docs/skills/)
explicitly lists global roots at `~/.config/opencode/skills`,
`~/.claude/skills`, and `~/.agents/skills`, plus their project equivalents
`.opencode/skills`, `.claude/skills`, and `.agents/skills`. For project roots it
walks upward from the current working directory to the Git worktree. These
facts were checked against official repository HEAD
[`ed926be253848402f9fb007b712a3777994070e3`](https://github.com/anomalyco/opencode/commit/ed926be253848402f9fb007b712a3777994070e3).

### Hermes Agent

Hermes documents `~/.hermes/skills` as its primary read-write source of truth
in the official
[Skills System documentation](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills/).
Additional roots exist only when explicitly configured through
`skills.external_dirs`; `~/.agents/skills` is an example, not an automatic root.
The official implementation at repository HEAD
[`0f102fa4dc04b7dfdab048169aaaa640d09d7523`](https://github.com/NousResearch/hermes-agent/blob/0f102fa4dc04b7dfdab048169aaaa640d09d7523/agent/skill_utils.py#L421-L509)
returns the local root followed by configured external directories.

No built-in project-local discovery root is present in that implementation.
[Issue #4667](https://github.com/NousResearch/hermes-agent/issues/4667) proposed
automatic `.hermes/skills`, `.agents/skills`, and `.claude/skills` project
discovery, but the verified HEAD still does not implement that proposal.
SkillsGo should therefore leave Hermes project discovery unknown rather than
promote the proposal to a product fact.

### OpenClaw

The current official [OpenClaw skill configuration documentation](https://docs.openclaw.ai/skills-config)
and [Agent runtime documentation](https://docs.openclaw.ai/agent) list the
following precedence: `<workspace>/skills`, `<workspace>/.agents/skills`,
`~/.agents/skills`, `~/.openclaw/skills`, bundled skills, then
`skills.load.extraDirs`. Plugin skill roots join the low-precedence configurable
group. The facts were also checked against official repository HEAD
[`e0478e2d532f0ca93a621c437ca39e6100088e3d`](https://github.com/openclaw/openclaw/commit/e0478e2d532f0ca93a621c437ca39e6100088e3d).

OpenClaw explicitly distinguishes path precedence from per-Agent allowlists.
Its documentation also states that Codex's `$CODEX_HOME/skills` is not an
OpenClaw discovery root. Profile variables such as `OPENCLAW_STATE_DIR` may
relocate the active managed directory; catalog resolution should eventually use
runtime configuration rather than assuming `~/.openclaw` in every profile.

## Implementation guidance

1. Keep installation path selection compatible with the current `skills.sh`
   catalog; do not use discovery roots as additional write targets.
2. For all Agents not listed here, set `DiscoveryRoots = [ManagedRoot]` and mark
   the result `unknown` or `unverified`.
3. For these six Agents, store root kind (`native`, `compat`, `legacy`,
   `admin`, or `configurable`) and scope (`user` or `project`) rather than a flat
   path list.
4. Model ancestor traversal and workspace-relative roots as rules, not as paths
   resolved only once at process startup.
5. Keep configurable roots separate from built-in roots. Reading an Agent's
   current configuration belongs in inventory/probing, not in the static
   catalog.
6. Treat Cursor runtime-specific symlink support as a capability probe or
   warning; path discovery alone is insufficient to guarantee a healthy
   projection.
