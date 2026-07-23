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

**Scope Vendor**:
The authoritative ordinary-file copy of a verified Repository Artifact within one installation scope. Workspace Scope stores Vendor under `.skillsgo/vendor`; User Scope stores it under `~/.skillsgo/vendor`. Version one does not share a Store across scopes or use symlinks.
_Avoid_: shared Store, Agent Skill directory, mutable working copy

**Repository Projection**:
The deterministic ordinary-file installation view generated for one Scope, Agent, and Repository Version. It preserves the Repository layout but retains `SKILL.md` only for selected members, so shared runtime files remain available without exposing unselected Skills.
_Avoid_: symlink, independent Skill artifact, editable fork

**User Scope**:
The installation scope that projects Skills into an Agent's user-level Skill directory for the current operating-system user.
_Avoid_: system install, machine-wide install

**Workspace Scope**:
The installation scope rooted at a user-selected local directory. A Workspace does not own a separate Store and does not need to be a Git repository.
_Avoid_: repository-only scope, independent project Store

**Workspace Manifest**:
The editable strict-YAML `skillsgo.yaml` declaration. Its `dependencies` mapping is keyed by Repository ID and requires one immutable version, a non-empty explicit Skill-path list, and a non-empty explicit Agent list; `"."` denotes the root Skill. Add may resolve a Tag, branch, or commit, but persists only the immutable result. There is no schema version or installation mode.
_Avoid_: `skillsgo.mod`, lock file, installation receipt

**Dependency Lock**:
The generated strict-YAML `skillsgo.lock` record whose `dependencies` mapping binds each declared Repository ID to its immutable version and Go-compatible Repository `h1:`. It does not repeat selected Skills or Agents and never persists movable revision input.
_Avoid_: `skillsgo.sum`, editable manifest, installation receipt

**Immutable Info Cache**:
The user-local cache of exact Skill Info and Repository Info response bytes. Cache entries are identity checked and crash-safe; Dependency Lock verifies Repository artifact identity, while a checksum without cached content cannot restore anything offline.
_Avoid_: mutable resolution cache, membership database, Workspace state

**User Declaration Root**:
The `~/.skillsgo` directory that owns user-scope `skillsgo.yaml`, `skillsgo.lock`, and `vendor`. Agent-specific directories remain derived Repository Projections rather than SkillsGo state roots.
_Avoid_: `~/.agents` ownership database, per-Agent manifest

**Batch Takeover**:
The explicit adoption of a supported skills.sh External Installation whose lock identifies an exact immutable Repository version and member. Execution verifies the External bytes against that Repository member, installs the complete Repository through the ordinary Dependency/Lock, Scope Vendor, and Repository Projection transaction, and only then moves the superseded External directory to recoverable trash. It never captures a per-Skill Store object or writes a receipt.
_Avoid_: legacy Store compatibility, implicit local import, mutable selector adoption

**External Removal**:
The explicit, state-bound deletion of one exact External Installation discovered under a known Agent Skill directory. It never creates a receipt, changes a Workspace declaration, or infers source ownership.
_Avoid_: name-only deletion, implicit adoption, managed uninstall

**Local Skill Artifact**:
A previously designed private per-Skill import artifact. It is outside the Repository-Vendor first release and requires a separate future decision because the first release distributes and locks only Repository Artifacts.
_Avoid_: Repository Artifact, first-release dependency, takeover fallback

**Active Skill Binding**:
The rule that one physical Agent target path can expose only one selected Skill at a time, even when multiple Repository Projections could produce the same discovered name. SkillsGo never invents a suffix to make colliding names coexist.
_Avoid_: automatic rename, same-path coexistence

**Local Modification**:
A difference between a Repository Projection and the deterministic view derived from its authoritative Scope Vendor and selected members. Version-one install reports the conflict and never overwrites or absorbs the changed files; the user decides how to preserve or remove them.
_Avoid_: fork, automatically merged change, silent repair

**Update Plan**:
A state-bound operation that replaces one declared Repository coordinate within one Scope. It preserves the dependency's selected Skill paths and Agents, previews the YAML version change, verifies the existing Vendor and every Projection against the old immutable baseline, and refuses Local Modifications. Because version belongs to the Repository, selecting one Library member updates the complete declared Repository dependency and all of its selected-member Projections atomically.
_Avoid_: per-Skill artifact update, target-by-target partial Repository versions, implicit overwrite, localized-output parsing

**Target Operation**:
A state-bound top-level Remove or Repair operation over exact managed Installation Targets. Unselected targets remain unchanged, unsafe destructive removal is rejected, and every selected target produces its own result.
_Avoid_: name-only removal, whole-Skill deletion, implicit cleanup

**Repair**:
An explicit future recovery action for an unhealthy Repository Projection. Version-one install does not act as Repair: any Local Modification is reported without overwrite, and the user must first resolve or remove the conflicting projection.
_Avoid_: automatic healing, background overwrite, install overwrite
