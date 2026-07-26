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
The definition and detection rules that describe how one Agent discovers Global and Workspace-level Skills.
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

**Scope Module Store**:
The authoritative filesystem copy of a verified Module Artifact within one installation scope. It preserves only artifact symlinks that resolve inside the same Module and revalidates them during extraction. Workspace Scope stores Module Store under `.skillsgo/modules`; Global Scope stores it under `~/.skillsgo/modules`. Version one does not share a Store across scopes.
_Avoid_: shared Store, Agent Skill directory, mutable working copy

**Module Projection**:
The deterministic installation view generated for one Scope, Agent, and Module Version. It preserves the Module layout and safe internal symlinks but retains `SKILL.md` only for selected members, so shared runtime files remain available without exposing unselected Skills.
_Avoid_: external symlink, independent Skill artifact, editable fork

**Global Scope**:
The installation scope that projects Skills into an Agent's Global Skill directory for the current operating-system user.
_Avoid_: system install, machine-wide install

**Workspace Scope**:
The installation scope rooted at a user-selected local directory. A Workspace does not own a separate Store and does not need to be a Git repository.
_Avoid_: repository-only scope, independent project Store

**Workspace Manifest**:
The editable strict-YAML `skills.yaml` declaration. Its `dependencies` mapping is keyed by Module Path and requires one immutable version, a non-empty explicit Skill-selector list, and a non-empty explicit Agent list. A selector may be a canonical Skill Name, which resolves to the lexicographically first matching Skill Path, or an exact Module-relative Skill Path. Product surfaces that selected a concrete member persist its exact path. Add may resolve a Tag, branch, or commit, but persists only the immutable result. There is no schema version or installation mode.
_Avoid_: `skillsgo.mod`, lock file, installation receipt

**Exact Skill Path Selection**:
The `add --skill-path` input used by product surfaces after discovery has identified a concrete Module member. Unlike the human-friendly `--skill` name selector, it requires one exact Module-relative Skill Path and persists that path unchanged so install, restore, update, and removal continue targeting the same member.
_Avoid_: name fallback, inferred path, generated member ID

**Dependency Lock**:
The generated strict-YAML `skills-lock.yaml` record whose `dependencies` mapping binds each declared Module Path to its immutable version and Go-compatible Module `h1:`. It does not repeat selected Skills or Agents and never persists movable revision input.
_Avoid_: `skillsgo.sum`, editable manifest, installation receipt

**Immutable Info Cache**:
The user-local cache of exact Module Info response bytes. Cache entries are identity checked and crash-safe; Dependency Lock verifies Module artifact identity, while a checksum without cached content cannot restore anything offline.
_Avoid_: mutable resolution cache, membership database, Workspace state

**Global Declaration Root**:
The `~/.agents` directory that owns Global-scope `skills.yaml` and `skills-lock.yaml`. It contains portable user intent, while SkillsGo-private materialized state remains outside it.
_Avoid_: `~/.skillsgo` declaration root, per-Agent manifest

**Global State Root**:
The `~/.skillsgo` directory that owns Global-scope Module Stores, immutable Info, ephemeral plans, and other SkillsGo-private state.
_Avoid_: user declaration root, Agent configuration root

**Batch Takeover**:
The state-bound execution of user-reviewed External Skill mappings. A skills.sh record supplies only a canonical Module Path, a manual installation uses a user-selected Hub Skill candidate, and neither path treats local content hashes or byte equality as execution authority; the selected immutable Module Artifact is installed through the ordinary managed transaction.
_Avoid_: Tree-SHA matching, automatic candidate choice, legacy Store compatibility, implicit local import

**Recovery Area**:
The CLI-owned temporary location that retains one superseded External Skill directory for 30 days after successful adoption. Recovery is per Skill, refuses to overwrite an occupied original path, and is not a Module Store, cache, or installation source.
_Avoid_: permanent backup, system Trash guarantee, mutable Skill Store

**External Removal**:
The explicit, state-bound deletion of one exact External Installation discovered under a known Agent Skill directory. It never creates a receipt, changes a Workspace declaration, or infers source ownership.
_Avoid_: name-only deletion, implicit adoption, managed uninstall

**Local Skill Artifact**:
A previously designed private per-Skill import artifact. It is outside the Module-Module Store first release and requires a separate future decision because the first release distributes and locks only Module Artifacts.
_Avoid_: Module Artifact, first-release dependency, takeover fallback

**Active Skill Binding**:
The rule that one physical Agent target path can expose only one selected Skill at a time, even when multiple Repository Projections could produce the same discovered name. SkillsGo never invents a suffix to make colliding names coexist.
_Avoid_: automatic rename, same-path coexistence

**Local Modification**:
A difference between a Module Projection and the deterministic view derived from its authoritative Scope Module Store and selected members. Version-one install reports the conflict and never overwrites or absorbs the changed files; the user decides how to preserve or remove them.
_Avoid_: fork, automatically merged change, silent repair

**Update Plan**:
A state-bound operation that replaces one declared Module coordinate within one Scope. It preserves the dependency's selected Skill selectors and Agents, resolves those selectors against the candidate Module Publication, previews the YAML version change, verifies the existing Module Store and every Projection against the old immutable baseline, and refuses missing selectors or Local Modifications. Because version belongs to the Module, selecting one Library member updates the complete declared Module dependency and all of its selected-member Projections atomically.
_Avoid_: per-Skill artifact update, target-by-target partial Repository versions, implicit overwrite, localized-output parsing

**Module Member Removal**:
A state-bound Module transaction that removes one selected member from a declared dependency, updates the Workspace Manifest, regenerates the Dependency Lock, Scope Module Store, and every affected Module Projection, and leaves unrelated Module members selected. Local Modifications reject the transaction without overwrite.
_Avoid_: exact-target managed removal, name-only deletion, partial Module mutation, automatic healing
