# SkillsGo CLI

The CLI context owns local Skill state and every filesystem mutation that makes a Skill available to an Agent.

## Language

**SkillsGo CLI**:
The local execution engine used by both terminal users and the SkillsGo App. The production App bundles a matching CLI version and communicates with it through stable JSON contracts.
_Avoid_: external prerequisite CLI, App-native engine, `skills` CLI fork

**Availability Exit Code**:
A stable process result used when a Hub-dependent command cannot reach its Hub (`69`) or times out temporarily (`75`). The App classifies these codes without parsing localized stderr; all local-only commands remain independent of Hub availability.
_Avoid_: stderr text matching, empty Library fallback, localized machine protocol

**SkillsGo Machine Protocol**:
The public, versioned JSON or NDJSON interface used by the App, CI/CD, and developer automation. Its stable error codes and structured fields are language-neutral; localized Human output and stderr diagnostics are not part of this interface.
_Avoid_: App-private protocol, localized JSON output, stderr parsing

**Presentation Locale Forwarding**:
The CLI's transport of an explicit, canonical BCP 47 content-language preference between App or developer requests and Hub discovery/detail APIs. It normalizes platform-style separators and casing, selects display and search projections only, and never participates in artifact resolution, verification, or installation.
_Avoid_: localized machine protocol, artifact locale, translated installation

**Installation Target Group**:
The set of requested Installation Targets that share one physical mutation and compensation scope. A group succeeds or rolls back atomically, while unrelated groups in the same Installation Request may complete independently.
_Avoid_: globally atomic Installation Request, independent shared-path targets

**Agent Adapter**:
The definition and detection rules that describe how one Agent discovers user-level and Workspace-level Skills.
_Avoid_: hard-coded Agent path, generic plugin adapter

**Managed Skill Root**:
The single Agent directory that SkillsGo may mutate for one scope. Installation, update, and removal operate only on this root; it is also one of the Agent's Discovery Roots.
_Avoid_: every directory an Agent scans, implicit write permission

**Discovery Root**:
A read-only catalog declaration of a directory from which an Agent may load Skills. Discovery Roots support visibility and conflict checks but do not cause installation fan-out or authorize filesystem mutation. Each resolved scope is marked verified or unverified so a managed-path fallback is not mistaken for a confirmed external Agent behavior.
_Avoid_: installation target, managed directory, automatic projection

**Agent Visibility**:
An inventory-time observation derived from installed Agent Discovery Roots plus current physical target identity. It records which verified or unverified paths expose a Library Entry without creating an Installation Target or persisted `visibleTo` state.
_Avoid_: managed binding, manifest field, receipt, cached visibility database

**Installed Agent**:
An Agent environment detected on the current machine through its Agent Adapter. Detection is independent of whether the Agent currently has any Skills.
_Avoid_: active Agent, Agent with Skills

**Content-addressed Store**:
The user-level immutable artifact cache used for integrity verification and recovery. User Scope and every Workspace Scope share one Store; installation first materializes one physical canonical copy under the scope's `.agents/skills`, then projects Agent-specific symlinks or explicit copies. Agents never link directly to Store artifacts.
_Avoid_: Agent Skill directory, project-local cache

**Installation Target**:
One Agent-facing projection of a scope-local canonical Skill into a specific Agent, scope, and target path. The target is the canonical directory itself when the Agent uses `.agents/skills`; otherwise it is normally a symlink to that canonical directory or an explicit copy. Multiple installation targets may reference the same canonical content and each target has its own health and operation result.
_Avoid_: Skill copy, Skill identity

**User Scope**:
The installation scope that projects Skills into an Agent's user-level Skill directory for the current operating-system user.
_Avoid_: system install, machine-wide install

**Workspace Scope**:
The installation scope rooted at a user-selected local directory. A Workspace does not own a separate Store and does not need to be a Git repository.
_Avoid_: repository-only scope, independent project Store

**Workspace Manifest**:
The editable `skillsgo.mod` declaration whose `require` entries contain a canonical Skill or repository coordinate, its resolved immutable version, and an optional `[agent, ...]` target list. Installing through a branch, `latest`, or another movable selector records the resulting immutable pseudo-version; following that selector again requires an explicit add request.
_Avoid_: lock file, installation receipt

**Workspace Sum**:
The generated `skillsgo.sum` integrity ledger. Each three-field line binds one canonical resource path and immutable version to an `h1:` checksum. Repository Info uses a `/repository.info` version suffix; historical lines may remain and never decide membership, ownership, or deployment.
_Avoid_: dependency lock, installation list, deployment graph

**Immutable Info Cache**:
The user-local cache of exact Skill Info and Repository Info response bytes. Cache entries are identity checked and crash-safe; Workspace Sum verifies their trusted bytes, while a checksum without cached content cannot restore anything offline.
_Avoid_: mutable resolution cache, membership database, Workspace state

**User Declaration Root**:
The `~/.skillsgo` directory that owns user-scope `skillsgo.mod`, `skillsgo.sum`, the immutable Info Cache, and the shared Store. Agent-specific directories remain derived installation targets rather than SkillsGo state roots.
_Avoid_: `~/.agents` ownership database, per-Agent manifest

**Installation Receipt**:
The local record that connects a Store artifact to one installation target and records the source, version, mode, path, and installation time.
_Avoid_: Workspace Manifest, Workspace Sum, Hub metadata

**Batch Takeover**:
One explicit operation that registers supported-lock-backed existing content through the same verified Store, Installation Receipt, health, update, repair, and removal semantics as a successful CLI copy installation. Its machine request explicitly selects User Scope, one or more Workspace Scopes, or both; it scans only those scopes' skills.sh locks and known Agent Skill directories. A supported, accurately normalizable lock entry is trusted as the Skill's source identity without Hub matching, while its normalized Content Digest and complete recoverable filesystem-state digest create the captured Store baseline. Each distinct physical directory becomes its own target without rewriting it, only identical content and filesystem state deduplicate in the Content-addressed Store, symlink aliases share one physical target group, and every lock-external or invalid candidate is skipped independently.
_Avoid_: separate adoption lifecycle, per-Skill adoption, lock content verification, target overwrite, copy normalization, unmatched Local import

**External Removal**:
The explicit, state-bound deletion of one exact External Installation discovered under a known Agent Skill directory. It never creates a receipt, changes a Workspace declaration, or infers source ownership.
_Avoid_: name-only deletion, implicit adoption, managed uninstall

**Local Skill Artifact**:
An immutable private Store artifact created through a separate explicit local import. It has a `local.skillsgo` Skill ID and immutable local version, can be projected to more Installation Targets or exported, and is never created implicitly when Batch Takeover skips an External Installation.
_Avoid_: Hub artifact, temporary target copy, takeover fallback

**Active Skill Binding**:
The rule that one physical target path can expose only one Skill artifact at a time, even when multiple Agent Adapters reference that path. `add --yes` treats the user's install confirmation as replacement authority for same-name targets and updates the shared binding in place; SkillsGo never invents a suffix to make colliding names coexist.
_Avoid_: automatic rename, same-path coexistence

**Local Modification**:
A difference between a copy-mode installation target and its source artifact. Interactive management and repair expose this state for deliberate recovery, while an affirmative `add --yes` may replace the target so installation succeeds; future backup support is expected to provide post-install recovery.
_Avoid_: Hub version, automatically merged change

**Update Plan**:
A state-bound operation over exact managed Installation Targets. Canonical Workspace requirements are pinned; following a movable branch or `latest` requires another explicit add. Workspace Manifest changes are previewed, and each target produces an independent result.
_Avoid_: name-only global update, implicit project mutation, localized-output parsing

**Target Operation**:
A state-bound top-level Remove or Repair operation over exact managed Installation Targets. Unselected targets remain unchanged, unsafe destructive removal is rejected, and every selected target produces its own result.
_Avoid_: name-only removal, whole-Skill deletion, implicit cleanup

**Repair**:
An explicit recovery action that restores an unhealthy managed Installation Target from its immutable Store artifact. Repair replaces Local Modifications only after review and includes every Agent binding that shares the physical target.
_Avoid_: automatic healing, background overwrite
