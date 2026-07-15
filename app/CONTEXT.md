# SkillsGo App

The App context presents public discovery and local Skill inventory as a desktop product without exposing package-manager mechanics as the primary user experience.

## Language

**Local Manager**:
The SkillsGo desktop application that discovers public Skills through a Registry and invokes the bundled SkillsGo CLI for local inspection and mutations.
_Avoid_: app store, Skill platform

**Personal User**:
A developer who discovers, inspects, and manages Skills on their own machine without an account.
_Avoid_: consumer, free account

**Personal Plan**:
The permanently free, local-first product for public Skill discovery and local management. It does not include organization policy, private distribution, or team audit.
_Avoid_: community edition, consumer tier

**Team Plan**:
The single paid plan for teams that need approved distribution, version policy, audit, and shared Agent configuration.
_Avoid_: enterprise edition, professional tier

**Paid Team**:
A team of developers using Coding Agents that needs consistent Skill distribution, approval, locking, and audit.
_Avoid_: ordinary user, generic enterprise

**Active Member Seat**:
A member authorized to use Team Skills during a billing period. Team pricing does not vary with Skill count, install count, Agent invocation count, or Registry traffic.
_Avoid_: usage unit, installation license

**Installed Agent**:
An Agent environment detected on the current machine. The Library shows every Installed Agent even when it currently has no Skills.
_Avoid_: Agent with Skills, active Agent

**Added Project**:
A local directory that a Personal User explicitly adds to the Library. SkillsGo never scans the disk to guess projects, and removing an Added Project only stops managing that directory.
_Avoid_: automatically discovered repository, recent repository

**Library Entry**:
The aggregate Library representation of one logical Skill. Targets across multiple Agents, scopes, and versions appear under one entry and are managed individually in its detail view.
_Avoid_: installation row, Skill copy

**Installation Plan**:
A user-selected matrix of location-and-Agent installation targets. A plan may contain multiple locations and multiple Agents, but only explicitly selected cells become targets. Conflict replacement is bound to the reviewed reason and target state; a physical path shared by Agent bindings requires every affected Agent cell before replacement.
_Avoid_: default install everywhere, automatic Cartesian product

**Target Result**:
The success, skipped, conflict, or failure outcome for one target in a multi-target operation. Successful targets remain installed when another target fails, and failed targets can be retried independently.
_Avoid_: global transaction result, all-or-nothing install

**Target Progress**:
A schema-versioned started or finished machine event for exactly one Installation Target. The App retains these events outside transient dialogs, restores them after navigation, and never derives them from localized CLI text.
_Avoid_: parsed terminal line, global spinner, inferred completion

**Update Plan**:
A reviewed set of exact managed Installation Targets, each resolved from its own stored source reference to an immutable destination version. Pinned targets are non-updateable, selected Workspace Lock changes are explicit, and results remain target-specific for failed-only retry.
_Avoid_: update every copy, latest-version overwrite, Skill-name-only update

**Target Management Plan**:
A reviewed set of exact managed Installation Targets with an explicit Remove, Repair, or Stop Managing action per selected target. Unselected targets do not change, and every selected action has target-specific progress and results.
_Avoid_: delete Skill, remove every target, name-only mutation

**Repair**:
An explicit action offered for recoverable unhealthy managed targets. It restores the reviewed target from its immutable Store artifact and may require every Agent binding that shares the physical path.
_Avoid_: automatic repair, silent overwrite

**Stop Managing**:
An explicit content-preserving action for an unhealthy target. It removes SkillsGo ownership metadata, including selected Workspace Manifest and Lock bindings, while leaving current target content in place.
_Avoid_: remove, delete, uninstall

**External Installation**:
A Skill found in an Installed Agent's directory without a SkillsGo installation receipt. The Library can inspect it but cannot update or remove it until the user explicitly brings it under management.
_Avoid_: broken Skill, unknown Skill, managed installation

**External Adoption Plan**:
A reviewed, state-bound transition for one exact External Installation. SkillsGo first matches by Content Digest and optional source hints, then requires the user to confirm either one immutable Registry artifact or an unmatched Local import; it never replaces the current content during adoption.
_Avoid_: name-based claim, automatic import, reinstall

**Local Skill**:
A managed Skill created by importing an External Installation that does not match a Registry artifact. It can be installed elsewhere, exported, or removed, but has no online update source and is not published by importing it.
_Avoid_: published Skill, Registry artifact, unmanaged installation

**Version Divergence**:
The valid state in which targets for one Skill intentionally use different immutable versions. The Library displays the versions and never silently rewrites project Locks to make them uniform.
_Avoid_: version conflict, automatic repair state

**Skill Risk Policy**:
The installation decision derived from a risk assessment for one immutable artifact. Personal requires additional confirmation for high risk, blocks critical risk by default with an explicit override, and never silently deletes an installed target after a later warning.
_Avoid_: safety score toggle, automatic deletion

**Product-led Growth**:
The adoption model in which Personal works without registration and team creation, trial, invitation, and seat purchase are self-service.
_Avoid_: sales-led adoption

**skillsgo-app**:
The open-source desktop client repository containing Personal and Team interactions, local orchestration, Agent presentation, and Registry access.
_Avoid_: Personal client, Team client, open-source shell

**skillsgo-cloud**:
The closed-source team control plane for accounts, organizations, seats, policy, approval, audit, and private-source metadata. The public Registry does not depend on it.
_Avoid_: official Registry, Team client
