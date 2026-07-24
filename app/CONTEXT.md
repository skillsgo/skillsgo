# SkillsGo App

The App context presents public discovery and local Skill inventory as a desktop product without exposing package-manager mechanics as the primary user experience.

## Language

**Local Manager**:
The SkillsGo desktop application that uses the bundled SkillsGo CLI to discover public Skills and perform local inspection and mutations.
_Avoid_: app store, Skill platform

**Mandatory Onboarding**:
The completion-gated first-launch journey that introduces SkillsGo and obtains explicit project-management choices before the App exposes its main destinations. It applies to clean installations, resumes after interruption, and is complete permanently when the user finishes or explicitly skips project setup.
_Avoid_: optional setup, dismissible project guide, product tour

**CLI-mediated Hub Access**:
The rule that every Hub and local App operation crosses the bundled CLI machine protocol; the App never calls Hub HTTP directly. In Cloud mode the App may call the Cloud origin returned by `skillsgo hub info` for ranking responses composed from Cloud-owned metrics and uncached Hub-owned Skill cards.
_Avoid_: direct Hub client, Cloud-persisted Skill metadata

**Presentation Locale**:
The user's persisted App language choice, resolved from System or any supported UI locale. Hub discovery and detail currently receive the stable content tags `en`, `zh-Hans`, or `zh-Hant`; UI locales without matching Hub content fall back to `en`. Presentation Locale may select author-maintained or Hub-enriched display text but never changes the Skill artifact installed or executed.
_Avoid_: artifact language, installation locale, translated Skill

**Offline Local Management**:
The capability to inspect and manage Added Projects, Installed Agents, Hub-managed targets, External Installations, and Local Skills from local CLI and filesystem state while the Hub is unavailable. Hub detail, matching, installation, and update actions explain their restriction and can be retried without clearing the selected Library route or local inventory.
_Avoid_: offline discovery, cached empty Library, global offline mode

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
A member authorized to use Team Skills during a billing period. Team pricing does not vary with Skill count, install count, Agent invocation count, or Hub traffic.
_Avoid_: usage unit, installation license

**Installed Agent**:
An Agent environment detected on the current machine. The Library shows every Installed Agent even when it currently has no Skills.
_Avoid_: Agent with Skills, active Agent

**Added Project**:
A local directory that a Personal User explicitly adds to the Library. SkillsGo never scans the disk to guess projects, and removing an Added Project only stops managing that directory.
_Avoid_: automatically discovered repository, recent repository

**Library Entry**:
The aggregate Library representation of one logical Skill. Managed Targets across multiple Agents, scopes, and versions appear under one entry and are managed individually in its detail view; derived Agent Visibility separately explains which Installed Agents can discover the same physical content.
_Avoid_: installation row, Skill copy

**Agent Visibility**:
A read-only inventory observation derived by the CLI from the Agent Catalog's Discovery Roots and current filesystem identity. It may include Agents without managed Targets and never grants update or removal authority.
_Avoid_: Installation Target, enabled toggle, persisted `visibleTo`

**Installation Request**:
The App's direct request to install one immutable Skill into explicit location-and-Agent selections. The CLI may prepare concrete actions internally for safety, but that preparation is process-local and is not an App protocol or a second user review step.
_Avoid_: second installation selector, user-facing review ceremony

**Batch Takeover**:
The user's reviewed conversion of selected External Installations into ordinary managed Repository dependencies. skills.sh fixes only the Repository source; manual installations receive Hub Skill candidates ordered by App-owned description similarity, and the user retains final Repository and immutable-version choice before one confirmation.
_Avoid_: automatic identity inference, content-authenticated takeover, implicit import, unmatched Local import

**Adoption Review**:
The temporary Library mode in which complete Repository and immutable-version selections are included by default, individual rows may be opted out, and incomplete rows remain External Installations. Entering the review starts candidate discovery; ordinary Library inventory never waits for Hub matching.
_Avoid_: permanent installation table, background takeover, second Library

**Target Result**:
The success, skipped, conflict, or failure outcome for one target in a multi-target operation. Successful targets remain installed when another target fails, and failed targets can be retried independently.
_Avoid_: global transaction result, all-or-nothing install

**Update Plan**:
A reviewed set of exact managed Installation Targets, each resolved from its canonical Workspace Manifest requirement to an immutable destination version. Pinned targets are non-updateable, selected Workspace Manifest changes are explicit, and results remain target-specific for failed-only retry.
_Avoid_: update every copy, latest-version overwrite, Skill-name-only update

**Target Operation Plan**:
A reviewed, state-bound exact-path removal of healthy External Installations. Unselected targets do not change, and modified managed Repository Projections are never overwritten automatically.
_Avoid_: repair, delete by Skill name, silent overwrite

**External Installation**:
A Skill found in an Installed Agent's directory that is not derived from a declared Repository Projection. The Library can inspect or explicitly remove it but cannot update or repair it; a user-reviewed Hub mapping can convert it into an ordinary managed Repository dependency.
_Avoid_: broken Skill, unknown Skill, managed installation

**External Removal Plan**:
A reviewed, state-bound deletion for one exact External Installation. SkillsGo shows the exact target and deletes only after confirmation; it does not create ownership metadata or infer a source.
_Avoid_: name-based claim, automatic import, reinstall

**Local Skill**:
A managed, local-only Skill created through a separate explicit local import. Batch Takeover never converts an unmatched External Installation into a Local Skill.
_Avoid_: published Skill, Hub artifact, unmanaged installation

**Version Divergence**:
The valid state in which targets for one Skill intentionally use different immutable versions. The Library displays the versions and never silently rewrites project requirements to make them uniform.
_Avoid_: version conflict, automatic repair state

**Skill Risk Policy**:
The installation decision derived from a risk assessment for one immutable artifact. Personal requires additional confirmation for high risk, blocks critical risk by default with an explicit override, and never silently deletes an installed target after a later warning.
_Avoid_: safety score toggle, automatic deletion

**Product-led Growth**:
The adoption model in which Personal works without registration and team creation, trial, invitation, and seat purchase are self-service.
_Avoid_: sales-led adoption

**skillsgo-app**:
The open-source desktop client repository containing Personal and Team interactions, local orchestration, Agent presentation, and Hub access.
_Avoid_: Personal client, Team client, open-source shell

**skillsgo-cloud**:
The closed-source team control plane for accounts, organizations, seats, policy, approval, audit, and private-source metadata. The public Hub does not depend on it.
_Avoid_: official Hub, Team client
