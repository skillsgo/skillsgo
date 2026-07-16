# SkillsGo CLI

The CLI context owns local Skill state and every filesystem mutation that makes a Skill available to an Agent.

## Language

**SkillsGo CLI**:
The local execution engine used by both terminal users and the SkillsGo App. The production App bundles a matching CLI version and communicates with it through stable JSON contracts.
_Avoid_: external prerequisite CLI, App-native engine, `skills` CLI fork

**Availability Exit Code**:
A stable process result used when a Hub-dependent command cannot reach its Hub (`69`) or times out temporarily (`75`). The App classifies these codes without parsing localized stderr; all local-only commands remain independent of Hub availability.
_Avoid_: stderr text matching, empty Library fallback, localized machine protocol

**Agent Adapter**:
The definition and detection rules that describe how one Agent discovers user-level and Workspace-level Skills.
_Avoid_: hard-coded Agent path, generic plugin adapter

**Installed Agent**:
An Agent environment detected on the current machine through its Agent Adapter. Detection is independent of whether the Agent currently has any Skills.
_Avoid_: active Agent, Agent with Skills

**Content-addressed Store**:
The user-level immutable store keyed by Skill content. User Scope and every Workspace Scope share one Store, so the same artifact is stored once and projected into multiple targets.
_Avoid_: Agent Skill directory, project-local cache

**Installation Target**:
One projection of a Store artifact into a specific Agent, scope, and target path. Multiple installation targets may reference the same artifact and each target has its own health and operation result.
_Avoid_: Skill copy, Skill identity

**User Scope**:
The installation scope that projects Skills into an Agent's user-level Skill directory for the current operating-system user.
_Avoid_: system install, machine-wide install

**Workspace Scope**:
The installation scope rooted at a user-selected local directory. A Workspace does not own a separate Store and does not need to be a Git repository.
_Avoid_: repository-only scope, independent project Store

**Workspace Manifest**:
The editable `skillsgo.yaml` declaration that records the Skills, references, Agents, and installation modes required by a Workspace.
_Avoid_: lock file, installation receipt

**Workspace Lock**:
The deterministic, committable `skillsgo-lock.yaml` file that records exact Skill identities, immutable versions, content digests, Hub origins, and Agent targets required to restore a Workspace.
_Avoid_: alternate lock filenames, local database, arbitrary download list

**Installation Receipt**:
The local record that connects a Store artifact to one installation target and records the source, version, mode, path, and installation time.
_Avoid_: Workspace Lock, Hub metadata

**External Adoption**:
The explicit, state-bound transition of one exact External Installation into managed ownership. An exact Content Digest match may associate it with a reviewed immutable Hub artifact; otherwise it may be imported as a private Local Skill without contacting a publication endpoint or replacing current target content.
_Avoid_: name-only association, implicit takeover, reinstall

**Local Skill Artifact**:
An immutable private Store artifact imported from unmatched local content. It has a `local.skillsgo` coordinate and immutable local version, can be projected to more Installation Targets or exported, and has no Hub update or publication source.
_Avoid_: Hub artifact, temporary target copy, published Skill

**Active Skill Binding**:
The rule that one physical target path can expose only one Skill artifact at a time, even when multiple Agent Adapters reference that path. A same-name collision requires every affected binding plus an explicit, state-bound replacement decision and is never resolved by silently adding a suffix.
_Avoid_: automatic rename, same-path coexistence

**Local Modification**:
A difference between a copy-mode installation target and its source artifact. Modified targets require explicit review before update, replacement, or removal, and replacement authority expires when the reviewed filesystem or receipt state changes.
_Avoid_: Hub version, automatically merged change

**Update Plan**:
A state-bound operation over exact managed Installation Targets. Every target resolves its own stored movable reference; tags and fixed commits are pinned; Workspace Lock changes are previewed; and each target produces independent progress and a final result.
_Avoid_: name-only global update, implicit project mutation, localized-output parsing

**Target Management Plan**:
A state-bound operation that assigns an explicit Remove, Repair, or Stop Managing action to exact managed Installation Targets. Unselected targets remain unchanged, unsafe destructive removal is rejected, and every selected target produces its own result.
_Avoid_: name-only removal, whole-Skill deletion, implicit cleanup

**Repair**:
An explicit recovery action that restores an unhealthy managed Installation Target from its immutable Store artifact. Repair replaces Local Modifications only after review and includes every Agent binding that shares the physical target.
_Avoid_: automatic healing, background overwrite

**Stop Managing**:
A content-preserving action that removes SkillsGo ownership receipts and Workspace declarations for an unhealthy Installation Target without deleting the filesystem object at the target path.
_Avoid_: remove, uninstall, delete target
