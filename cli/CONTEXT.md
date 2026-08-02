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

**Install Event Reporting**:
The post-commit, best-effort emission of one Package Install Event for one successful Package transaction. The event batches every selected exact Skill Path and Agent, includes the CLI version plus an optional calling App version, and never changes the installation result when community reporting is unavailable.
_Avoid_: per-Skill request loop, installation prerequisite, local receipt

**CLI Distribution Identity**:
Immutable build metadata distinguishing a standalone direct archive, package-manager build, unknown development build, or App-bundled CLI. It controls upgrade guidance and never comes from a runtime environment override. A bundled CLI additionally reports its App bundle version and remains under the App update lifecycle.
_Avoid_: filesystem-path guess, mutable environment identity, treating App and CLI versions as compatibility negotiation

**Authenticated CLI Release Manifest**:
The bounded schema-v1 JSON document served from the fixed `https://cdn.skillsgo.ai` Origin and verified with the CLI's embedded Ed25519 public key before decoding. It maps exact OS/architecture targets to immutable same-Origin archive URLs, SHA-256 digests, and sizes. GitHub Release remains an archive and fallback, not a runtime API dependency.
_Avoid_: unsigned latest JSON, redirectable update Origin, GitHub API requirement, checksum fetched from the same unauthenticated channel

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

**Package Provider**:
The single capability boundary for exact locked Package dependencies. Metadata requests read or rebuild `~/.skillsgo/cache/info`; content requests additionally read or rebuild `~/.skillsgo/cache/packages`. Consumers never require cache entries to preexist and never read cache paths directly.
_Avoid_: command-specific cache repair, Package Store authority, movable-version restore

**Scope Package Tree**:
The complete verified expansion of one locked Package Artifact inside its installation Scope. Project Scope uses `<project>/.skillsgo/packages`; Global Scope uses `~/.skillsgo/packages`, separate from global declarations under `~/.agents`. It is derived from Manifest, Lock, and Git content, but a differing existing tree remains a protected Local Modification rather than disposable bytes.
_Avoid_: `~/.agents/.skillsgo/packages`, shared cross-Scope Store, disposable cache

**Package Projection**:
The deterministic Agent-visible directory link generated at `<managed-root>/<canonical-skill-name>` to one selected member inside the same Scope's complete filtered Package Tree. It is a relative symlink on macOS and Linux and an absolute directory junction on Windows. Canonical resolution stays inside the Package topology so applicable ancestor plugin manifests remain visible to Agents without exposing Package coordinates as Agent Skill names.
_Avoid_: external link, independent member copy, editable fork

**Global Scope**:
The installation scope that projects Skills into an Agent's Global Skill directory for the current operating-system user.
_Avoid_: system install, machine-wide install

**Workspace Scope**:
The installation scope rooted at a user-selected local directory. A Workspace does not own a separate Store and does not need to be a Git repository.
_Avoid_: repository-only scope, independent project Store

**Workspace Manifest**:
The editable strict-YAML `skills.yaml` declaration. Its `dependencies` mapping is keyed by Package Path and requires one immutable version, a non-empty explicit Skill-selector list, and a non-empty explicit Agent list. A selector may be a canonical Skill Name, which resolves to the lexicographically first matching Skill Path, or an exact Package-relative Skill Path. Product surfaces that selected a concrete member persist its exact path. Add may resolve a Tag, branch, or commit, but persists only the immutable result. There is no schema version or installation mode.
_Avoid_: `skillsgo.mod`, lock file, installation receipt

**Exact Skill Path Selection**:
The `add --skill-path` input used by product surfaces after discovery has identified a concrete Package member. Unlike the human-friendly `--skill` name selector, it requires one exact Package-relative Skill Path and persists that path unchanged so install, restore, update, and removal continue targeting the same member.
_Avoid_: name fallback, inferred path, generated member ID

**Dependency Lock**:
The generated strict-YAML `skills-lock.yaml` record whose `dependencies` mapping binds each declared Package Path to its immutable version and Go-compatible Package `h1:`. It does not repeat selected Skills or Agents and never persists movable revision input.
_Avoid_: `skillsgo.sum`, editable manifest, installation receipt

**Immutable Info Cache**:
The disposable user-level `~/.skillsgo/cache/info` cache of exact Package Info response bytes, shared by Project and Global Scopes. Cache entries are identity checked and crash-safe. Dependency Lock verifies Package artifact identity, while a checksum without cached content cannot restore anything offline.
_Avoid_: mutable resolution cache, membership database, Workspace state

**Global Declaration Root**:
The `~/.agents` directory that owns Global Scope `skills.yaml` and `skills-lock.yaml`. It contains portable user intent, while SkillsGo-private materialized state remains outside it.
_Avoid_: `~/.skillsgo` declaration root, per-Agent manifest

**Global State Root**:
The `~/.skillsgo` directory that owns user-level configuration, the protected Global Scope Package Tree, disposable read-through metadata/Git caches, ephemeral plans, and other SkillsGo-private state. Only `~/.skillsgo/cache` is freely disposable; deleting the broader state root removes derived global installation content that must be restored from declarations and locks. Global declarations remain under `~/.agents`.
_Avoid_: Global Declaration Root, Agent configuration root

**SkillsGo User Configuration**:
The strict, versioned `~/.skillsgo/config.yaml` document that is the single extensible home for user-level SkillsGo settings. Its `projects` section is a minimal sorted sequence of canonical absolute Workspace paths used by the App and cross-Scope CLI operations; display names and UI identity are derived from those paths rather than persisted separately. Before its one-time project-bootstrap marker is set, one explicit CLI bootstrap command may seed existing Workspaces from bounded recent supported-Agent registries and session metadata; afterward only explicit add and remove operations change the sequence, even when it becomes empty. The CLI is the only persistence owner; product callers use typed CLI commands rather than editing the file directly.
_Avoid_: Managed Scope registry file, App preferences, Workspace manifest, configuration fragments

**Batch Adoption**:
The state-bound execution of App-reviewed External Skill mappings. Before review, inventory may recover one canonical Adoption Package hint from supported external installation metadata; the hint prioritizes one matching-Package candidate while ordinary ranked candidates fill the remaining result capacity, without changing External ownership, selecting a version, or authenticating local content. Each confirmed item carries an exact Package Path, immutable Version, Skill Path, and existing Installation Targets. The user's confirmation authorizes replacement of conflicting Package Store and Package Projection paths in the selected scope. The CLI fully prepares the ordinary Package add change set before touching External paths, then commits Package state and External retirement through the same mutation Plan; any pre-publication failure rolls everything back, while successful commit hands superseded copies to Trash during final cleanup.
_Avoid_: Tree-SHA authority, automatic candidate choice, separate adoption Store, subprocess recursion, pre-download External movement, implicit local import

**Recovery Area**:
The CLI-owned vault for External paths retired during adoption. Its durable per-Skill mapping preserves original directory and symlink paths across process interruption and remains available for 30 days after a successful commit. A retry restores unfinished retirement before new adoption; a failed mutation restores the original topology; an explicit restore first removes the managed Skill through the ordinary Package flow, refuses later occupants, and then restores the original path. Expired or explicitly deleted records may be cleaned automatically.
_Avoid_: permanent backup, Package Store, cache, installation source, post-commit Package compensation

**External Removal**:
The explicit, state-bound deletion of one exact External Installation discovered under a known Agent Skill directory. It never creates a receipt, changes a Workspace declaration, or infers source ownership.
_Avoid_: name-only deletion, implicit adoption, managed uninstall

**Local Skill Artifact**:
A previously designed private per-Skill import artifact. It is outside the Package-Package Store first release and requires a separate future decision because the first release distributes and locks only Package Artifacts.
_Avoid_: Package Artifact, first-release dependency, adoption fallback

**Active Skill Binding**:
The rule that one physical Agent target path can expose only one selected Skill at a time, even when multiple Package Projections could produce the same discovered name. SkillsGo never invents a suffix to make colliding names coexist.
_Avoid_: automatic rename, same-path coexistence

**Local Modification**:
A difference between a Scope Package Tree or member Projection and its deterministic view derived from exact locked Git content. Explicit verification and every mutation compare against that content. Ordinary unconfirmed add, update, remove, and restore never overwrite changed files; `--yes` and reviewed Batch Adoption are narrow transactional replacement authorization.
_Avoid_: fork, automatically merged change, silent repair

**Package Reconcile**:
The shared desired-state engine beneath add, update, install, and adopt-through-add. Commands resolve current and desired immutable Package coordinates, selected Skills, Agents, Scope Package Trees, member Projections, and optional declaration state; the reconciler prepares one Plan for Tree, Projection, immutable Info, Manifest, and Lock changes. Apply commits atomically while dry-run validates and discards the same Plan.
_Avoid_: command recursion, per-Skill version, duplicated transaction assembly, implicit overwrite, localized-output parsing

**Package Member Removal**:
A state-bound Package transaction that reacquires exact locked content, removes one selected member from a declared dependency, updates Manifest and Lock, and reconciles the Scope Package Tree plus every affected member Projection while leaving unrelated members selected. Local Modifications reject the transaction without overwrite.
_Avoid_: exact-target managed removal, name-only deletion, partial Package mutation, automatic healing
