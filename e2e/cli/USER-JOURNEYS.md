# CLI and Hub User Journeys

This catalog defines black-box user stories that cross the SkillsGo CLI and Hub boundary. A journey describes a user outcome through public process, HTTP, and filesystem contracts; it is not a command-coverage checklist.

## Selection Rules

- Use real supported Agent Adapters rather than test-only adapters.
- Exercise the released CLI and Hub binaries in a fresh container for every journey.
- Assert stable JSON, exit codes, Hub responses, portable YAML/Lock state, Scope Vendors, and Agent-visible coordinate Projections.
- Do not assert localized terminal copy or internal Go types.
- Keep destructive and failure scenarios inside the disposable container filesystem.
- Prefer deterministic local source fixtures for required CI journeys; reserve live public sources for smoke journeys.

## P0 — Release-Gating Journeys

### J01 — Install a public Skill into a Workspace

As a terminal user, I want to install a public Skill for a real Agent in my current Workspace so that the Agent can use it immediately.

The CLI resolves the requested reference through the Hub, verifies one immutable Repository artifact, creates a Workspace Vendor and Agent-visible coordinate Projection, and atomically writes matching `skillsgo.yaml` and `skillsgo-lock.yaml` entries. Re-running the same request must not corrupt or duplicate state.

Status: implemented for Codex with one selected nested member by `j01_install_workspace_test.go`.

### J02 — Remove the last selected member and its Workspace Vendor

As a terminal user, I want to remove the last selected Skill from my Workspace so that the Agent no longer sees it and no undeclared Repository Vendor remains behind.

The coordinate Projection, Vendor, YAML dependency, and Lock entry disappear together. Unrelated Repository dependencies remain intact.

Status: implemented for Codex by `j02_remove_workspace_test.go`.

### J03 — Restore a declared Workspace from YAML and Lock

As a user opening an existing Workspace, I want `skillsgo install` to recreate every declared Vendor and Agent Projection from canonical requirements and verified immutable artifacts so that the Workspace is reproducible on a clean machine.

The restored files match the Repository Sum in `skillsgo-lock.yaml`, all declared coordinate Projections exist, and restoration uses only the immutable version in `skillsgo.yaml` rather than re-resolving movable input.

Status: implemented for a clean Codex Vendor/Projection restore, including invocation from a nested Workspace directory, by `j03_clean_machine_restore_test.go`.

### J04 — Recover an Agent target while the Hub is unavailable

As a user with an intact Scope Vendor, I want to restore a missing Agent Projection without reaching the Hub so that temporary network or Hub outages do not block local recovery.

The CLI verifies the Vendor against `skillsgo-lock.yaml`, recreates the coordinate Projection, leaves YAML/Lock bytes unchanged, and performs no successful Hub request.

Status: implemented for Codex with an explicitly unreachable Hub by `j04_vendor_offline_restore_test.go`.

### J05 — Reject a corrupted download atomically

As a user, I want a corrupted, truncated, or digest-mismatched Hub artifact to be rejected so that unverified content never reaches my Vendor or Agent directories.

The command fails with a stable machine result; no Vendor, Projection, YAML change, or Lock change is committed.

Status: implemented by corrupting the real Hub disk-cached ZIP in `j05_corrupted_download_test.go`.

### J06 — Keep deferred audit outside immutable installation

As a user installing an exact Skill while audit is deferred, I want immutable Info and installation behavior to remain independent of stale or historical risk data.

Immutable Repository Info contains no Risk field, and an exact verified artifact installs without an audit-confirmation gate. A future audit subsystem must attach mutable assessment data outside these immutable bytes.

Status: implemented against the SkillsGo-owned historical `e2e-risk-skills` fixture by `j06_risk_confirmation_test.go`.

### J07 — Re-resolve a movable Skill reference explicitly

As a user who previously selected Repository head, I want an explicit `add ...@head` to resolve it again while ordinary restore remains immutable.

Preflight resolves the movable selector through the product Resolution API, execution atomically replaces the old Vendor and coordinate Projections, and YAML/Lock persist only the new immutable Repository version and Sum. The movable selector and historical versions are never persisted.

Status: implemented against a deterministic local Repository advanced from C1 to C2 and explicitly re-resolved through `head` by `j07_update_movable_test.go`.

### J08 — Keep an exact installation pinned

As a user who selected an exact immutable version, I want ordinary installation restore to preserve that pin even when a newer release exists.

`skillsgo install` leaves the Vendor, Projection, YAML, and Lock unchanged. Moving to head, release, or another exact version requires an explicit state-bound Repository update.

Status: implemented with deterministic v1.0.0 installed while v1.1.0 exists by `j08_explicit_fixed_version_update_test.go`.

## P1 — Core Multi-Target Journeys

### J09 — Install one Skill for multiple real Agents

As a user working with multiple Agents, I want one Skill installed for each selected Agent so that all of them see the same reviewed content.

One scope-local Vendor backs every requested Agent coordinate Projection, and each Agent is represented accurately in the YAML dependency.

Status: implemented for Codex plus Claude Code by `j09_multi_agent_install_test.go`.

### J10 — Remove one Agent binding while preserving another

As a multi-Agent user, I want to remove one Agent's binding without removing the same Skill from other Agents so that target management remains exact.

Only the selected target or binding disappears; shared canonical content and other Agent visibility remain healthy.

Status: implemented by removing only the Claude Code projection in `j10_remove_one_binding_test.go`.

### J11 — Install and remove a user-scope Skill

As a user, I want to make a Skill available to an Agent across Workspaces and later remove that user-level installation without touching project declarations.

The CLI mutates only the Agent's user-level Managed Skill Root and the User Declaration Root under `~/.skillsgo` inside the isolated environment.

Status: implemented for Codex plus a Hermes Agent-specific home override with User Vendor state by `j11_user_scope_test.go`.

### J12 — Install every Skill from a multi-Skill repository

As a user selecting a repository source, I want SkillsGo to discover and install all contained Skills so that I do not have to enumerate every Skill Name manually.

One Repository artifact and Vendor contain the complete source snapshot; each selected valid member appears in every requested coordinate Projection while invalid candidates stay out of the selected membership.

Status: implemented with deterministic root, nested, mixed-case, deep, invalid, and shared-runtime fixtures plus Cartesian multi-Agent Projections by `j12_repository_install_test.go`.

### J13 — Select same-name Repository members deterministically

As a user selecting a Repository whose members declare the same canonical Skill Name, I want name selection to choose the first path deterministically and exact-path selection to choose the requested member.

The complete Repository Publication preserves both members. A name-only selector resolves by lexicographic Skill Path, while an exact path remains persisted through later lifecycle operations.

Status: implemented across two nested Skills with one shared source-authored name in a deterministic Repository by `j13_same_name_members_test.go` and the complete lifecycle journey in `j31_repository_identity_and_selection_test.go`.

### J14 — Protect Local Modifications in a coordinate Projection

As a user who edited an installed copy, I want update and removal to detect my Local Modifications so that my work is not overwritten or deleted without review.

Removal fails without mutating the modified Projection, Vendor, YAML, or Lock. SkillsGo never infers overwrite authority from a non-interactive flag.

Status: implemented through Repository transaction baseline comparison by `j14_local_modification_test.go`.

## P2 — Inventory and Operational Journeys

### J15 — Inventory managed and external Agent Skills

As a user, I want one machine-readable inventory of managed installations, Local Modifications, unhealthy targets, and External Skills so that I can understand actual Agent visibility before mutating anything.

The result distinguishes Installation Targets from read-only Agent Visibility and does not adopt or modify External Skills.

Status: implemented with one managed Hub Skill and one preserved External Skill by `j15_inventory_test.go`.

### J16 — Refuse implicit repair of a Local Modification

As a user who modified an Agent Projection, I want ordinary `skillsgo install` to refuse overwriting my files so that recovery remains an explicit user decision.

Installation returns a failing Repository result containing Local Modification evidence and leaves the edited bytes unchanged. The first release exposes no destructive repair command.

Status: implemented for a modified Codex canonical target by `j16_local_modification_install_test.go`.

### J17 — Reject removal of locally modified content

As a user, I want removal to refuse deleting modified managed content so that my edits remain recoverable.

The Projection, Vendor, YAML, and Lock remain unchanged, and the obsolete `manage` command is absent.

Status: implemented for a locally modified Codex target by `j17_stop_managing_test.go`.

### J18 — Fail clearly when the Hub is unavailable and no cache exists

As a user installing an uncached Skill during an outage, I want a stable availability result so that scripts and the App can distinguish infrastructure failure from invalid input.

The CLI returns the documented Availability Exit Code, emits no misleading success JSON, and leaves local state unchanged.

Status: implemented with no local Vendor and an unreachable Hub by `j18_hub_unavailable_test.go`.

### J19 — Reuse one immutable Hub artifact deterministically

As a user repeating a download or installing the same version for another target, I want the Hub and CLI to reuse byte-identical immutable content so that cache behavior cannot change the installed Skill.

Repeated Hub responses preserve Repository Info identity and ZIP bytes; adding another Agent reuses the same immutable Repository coordinate and creates another deterministic Projection without symlinks.

Status: implemented with repeated immutable ZIP downloads and a second real Agent target by `j19_immutable_reuse_test.go`.

### J20 — Keep every journey isolated from the host

As a contributor running the e2e suite, I want every scenario to execute in a disposable filesystem so that a broken path rule cannot alter my real SkillsGo, Agent, or Workspace state.

Each journey owns one container and one temporary `/e2e` mount. No host home, repository directory, Docker socket, or real Agent directory is mounted into the scenario container.

Status: enforced for every scenario by the mount inspection in `startEnvironment` and explicitly covered by `j20_host_isolation_test.go`.

### J21 — Preserve the complete Skill resource tree

As a user installing a multi-file Skill, I want every nested resource to survive Hub packaging, Vendor verification, and Agent Projection so that progressive-disclosure references and scripts remain usable.

The Projection contains the same non-empty nested resource bytes as the authoritative Vendor.

Status: implemented with the real nested `rules/async-parallel.md` resource from `vercel-labs/agent-skills` by `j21_preserve_skill_resources_test.go`.

### J22 — Update selected members at Repository granularity

As a user updating a Repository dependency with multiple selected Skills, I want every selected sibling to move atomically to one immutable Repository version so that mixed-version snapshots cannot be synthesized.

Preflight binds the target version and state token; execution replaces the Vendor and Projection coordinate, and Lock contains only the new Repository version and Sum.

Status: implemented by updating two selected members from v1.0.0 to v1.1.0 through the Repository update command by `j22_repository_update_selected_test.go`.

### J23 — Signal update failure and preserve state atomically

As an automation user, I want any failed requested update to return a non-zero process status so that scripts cannot mistake a reported failure for success.

The previous Projection, YAML, and Lock bytes remain unchanged after failure.

Status: implemented for an unavailable Hub by `j23_update_failure_atomic_test.go`, with partial Update Plan behavior at the CLI command seam.

### J24 — Resolve deeply nested Skills without false absence

As a user installing or updating a deeply nested Skill, I want its complete canonical path to remain resolvable so that bounded discovery depth cannot turn a live Skill into an apparent deletion.

Direct selection and a state-bound Repository update succeed for a four-level Skill path and preserve its selected membership.

Status: implemented with a deterministic four-level Repository path by `j24_deep_skill_discovery_test.go`.

### J25 — Expose immutable Catalog identity without deferred audit

As a user reviewing a Catalog entry, I want its immutable version and Sum to remain available while audit is deferred, without mutable assessment data entering the immutable contract.

The detail response exposes one immutable version and non-empty `sum`; its currently empty mutable Risk Assessment does not authenticate the immutable artifact. A future audit response may reference that sum through a separate mutable resource.

Status: implemented through the public Hub detail endpoint by `j25_catalog_audit_consistency_test.go`.

## Repository Distribution Journeys

### J26 — Restore a whole Repository while offline

As a Workspace user, I want one Repository requirement to restore its exact accepted member set from its verified Vendor so that Projection recovery does not require a reachable Hub.

Status: implemented for a root Skill, two nested Skills, one omitted invalid candidate, unchanged YAML/Lock bytes, and an unreachable Hub by `j26_repository_restore_offline_test.go`.

### J27 — Enforce one version across selected Repository members

As a CLI user, I want repeated human-readable `--skill` selectors to inherit the Repository query and reject per-Skill version suffixes so that one installed Repository coordinate always describes one source snapshot.

Status: implemented through atomic mixed-version rejection followed by a two-member `@head` installation pinned to one immutable version by `j27_selected_version_consistency_test.go`.

### J28 — Select stable, prerelease, or pseudo versions lazily

As a CLI user, I want omitted queries to prefer the highest stable tag, fall back to the highest prerelease, and resolve an untagged default branch once to a pseudo-version.

Status: implemented against deterministic tagged, prerelease-only, untagged, and tagged-with-untagged-descendant Git remotes, including Go-compatible ancestor-based pseudo-version generation, by `j28_repository_version_selection_test.go`.

### J29 — Preserve disappeared Skill history

As a CLI user, I want a Skill removed from a later Repository tag to remain installable at its older immutable Repository version without inventing a separate per-Skill release pointer.

Status: implemented across v1-present and v1.1-absent Repository snapshots by `j29_repository_history_test.go`.

### J30 — Isolate invalid Repository candidates

As a CLI user, I want malformed `SKILL.md` candidates omitted without blocking valid siblings or mutating Workspace state when selected.

Status: implemented through public Repository Info, CLI installation, and unchanged YAML/Lock evidence by `j30_repository_candidate_isolation_test.go`.

### J31 — Preserve Repository identity and selection boundaries

As a CLI user, I want arbitrary host namespace depth, Repository ID plus Skill Name default selection, exact-path selection for same-name members, and root-member selection by declared name to remain unambiguous.

Status: implemented with multi-level fixture namespaces, canonical Skill Name selectors, exact-path same-name selection, root-member selection, and complete Repository ZIPs by `j31_repository_identity_and_selection_test.go`.

### J32 — Keep Repository protocol resources immutable

As a protocol consumer, I want mutable selectors resolved only through the product API and root Proxy list/exact Info/exact ZIP/HTTP HEAD routes to expose canonical resources whose published bytes do not change after a source tag moves.

Status: implemented through `POST /api/v1/repository-resolutions`, exact root Proxy resources, rejection of Proxy selectors and per-Skill Proxy resources, repeated ZIP digests, and a moved source tag by `j32_repository_protocol_immutability_test.go`.

### J33 — Bound anonymous lazy resolution

As a Hub operator, I want fresh tag catalogs, exact-version bypass, singleflight, global capacity, negative caching, and retry after capacity release to bound anonymous source work.

Status: implemented at the public seam with concurrent Hub HTTP requests, deterministic slow source fixtures, fresh tag-catalog stability, exact-version bypass, and observable capacity/retry behavior by `j33_lazy_resolution_controls_test.go`. TTL expiry, exact singleflight call counts, immutable-cache call counts, and negative-cache lifetime/call counts are verified with injected clocks at the Hub Router/publisher boundary rather than through sleeps or private Git traces.

### J34 — Preserve canonical case across source and product identity

As a product consumer, I want a lower-case host and case-preserving nested Skill paths to survive source normalization, installation, and Catalog reads.

Status: implemented with an upper-case input host, a mixed-case Git tree path, canonical YAML identity, coordinate Projection, and product detail route by `j34_coordinate_case_and_escape_test.go`.

### J35 — Populate Catalog lazily without legacy protocol resources

As a Catalog and protocol consumer, I want ordinary demand discovery to publish newly observed Skills while the Proxy remains limited to Repository list, exact Info, and exact ZIP resources.

Status: implemented from an initially absent Skill detail through ordinary add and subsequent Catalog visibility, with explicit absence checks for `@resolve`, `.manifest`, and the future `.skillsgo` resource, by `j35_lazy_catalog_and_protocol_surface_test.go`.

### J36 — Restore portable Agent Projections through separated Proxy and API surfaces

As a user moving a Workspace between machines, I want `skillsgo.yaml` to preserve exact requirements and Agent targets while the Hub keeps artifact transport separate from product APIs.

Status: implemented with canonical YAML, Codex and Claude Code coordinate Projection restoration, unchanged YAML/Lock bytes, successful root Proxy and `/api/v1` requests, and rejected `/mod`, per-Skill Proxy, and `/v1` routes by `j36_workspace_protocol_restore_test.go`.

### J37 — Preserve integrity for App-driven project installation

As an App user selecting exact project and Agent targets, I want installation to persist the same complete integrity evidence as terminal installation so that the Workspace remains reproducible rather than depending on the machine that performed the install.

The App-facing `add <repository>@<version> --skill ... --project ... --agent ...` contract writes one Repository Sum, caches exact Repository Info, and restores a deleted coordinate Projection from the verified Vendor while the Hub is unavailable.

Status: implemented with a deterministic nested Skill and offline Vendor-backed Projection recovery by `j37_app_install_integrity_test.go`.

### J38 — Diagnose a machine-mode Hub failure without parsing prose

As a CI/CD or developer-automation user, I want a recognized machine-mode failure to provide a stable code, retryability, diagnostic context, and process status so that automation and troubleshooting do not depend on localized terminal text.

Status: implemented against an unreachable Hub with released CLI JSON stdout and exit 69 by `j38_machine_failure_contract_test.go`.

### J39 — Keep a successful installation group when another group fails

As an App or automation user installing to independent targets, I want one target failure to leave another committed Installation Target Group intact and report both outcomes.

Status: implemented with schema 3, one committed Codex Project target, one failed Codex User target, nested `installation.target_failed`, and non-zero process status by `j39_installation_partial_failure_test.go`.

## Existing Installation Management Journeys

### J40 — Manage an existing locked Skill without rewriting user files

As a user who installed a Skill through a compatible lockfile, I want SkillsGo to verify it against an immutable Repository Artifact, install ordinary managed state, and recoverably retire the External copy.

Preflight reports one eligible Skill without writing Vendor, YAML, or Lock state. Confirmation verifies exact bytes against a published Repository member, writes the User Vendor and coordinate Projection, moves the superseded external copy to recoverable trash, exposes the Skill as managed inventory, and makes the next scan report zero eligible Skills.

Status: implemented through the released CLI and observable filesystem state by `j40_takeover_existing_skill_test.go`.

### J41 — Preserve edits made after takeover confirmation

As a user whose editor or Agent changes a Skill while takeover is starting, I want the confirmed plan to reject only that stale candidate so that newer local work is never overwritten or recorded under the wrong digest.

Two candidates are confirmed, one changes before execution, and the result commits the unchanged Skill while skipping the edited Skill with `target-changed`. The edited bytes remain intact, its management metadata remains absent, and the next scan reports exactly that one eligible Skill.

Status: implemented through the released CLI and observable filesystem state by `j41_takeover_changed_skill_test.go`.

### J42 — Recover takeover after an unexpected process exit

As a user whose App or machine stops during takeover, I want the next operation to recover the interrupted metadata transaction so that no partial management state hides or corrupts my existing Skill.

The journey sends `SIGKILL` after the paired YAML/Lock transaction journal appears, then verifies that the next inventory read recovers before exposing state, the next scan still reports one eligible Skill, and a retry commits complete Vendor, Projection, YAML, and Lock state. The journal is removed and the final scan reports zero eligible Skills.

Status: implemented with a real released-CLI process interruption by `j42_takeover_interrupted_commit_test.go`.

### J43 — Re-resolve a movable query after the default branch advances

As a user who installed a Repository from `head` at C1, I want a later explicit `head` query to observe C2 without silently changing my installed version.

The repeated movable resolution bypasses stale selector state, resolves the refreshed remote-tracking branch to a new pseudo-version, returns C2 content, and leaves Workspace YAML pinned to C1 until a separate confirmed installation occurs.

Status: implemented with a deterministic local Repository advanced from C1 to C2 during the running scenario by `j43_movable_query_refresh_test.go`.

### J44 — Preserve versions when an untagged Repository starts publishing tags

As a user who previously resolved C1 as F1 before a Repository published tags, I want that immutable version to remain available after C1 becomes V1 and the default branch advances to C2.

The old F1 still resolves to C1, `release` selects V1 at C1, and an explicit `head` query resolves C2 as the ancestor-based F2 without rewriting either historical identity.

Status: implemented through released CLI Info requests against a deterministic Repository transitioned from untagged C1 to tagged V1 and then advanced to C2 by `j44_no_tag_to_tag_transition_test.go`.

### J45 — Check many installed Skills against Repository-fresh candidates

As an App or terminal user with many installed Skills, I want one update check to compare local immutable versions with fresh Repository head and release candidates while resolving each Repository only once.

The journey seeds the Catalog from the SkillsGo-owned public versioned fixture, checks 80 installed entries through one CLI invocation, and receives independent head and release results for every entry.

Status: implemented against the released CLI and Hub by `j45_catalog_only_batch_update_check_test.go`.

### J46 — Roll back a failed whole-Repository add

As a user adding every Skill from one Repository, I want one conflicting member target to abort the complete installation so that the Workspace never records or exposes a partial Repository publication.

The journey passes `--yes`, preserves a pre-existing conflicting coordinate path, and verifies that non-interactive confirmation never grants replacement authority: the Vendor, Projection content, YAML dependency, and Lock entry are all absent after failure.

Status: implemented with the deterministic multi-Skill collection Repository and a coordinate Projection conflict by `j46_repository_add_atomicity_test.go`.

### J47 — Explain and verify a Repository installation

As a user maintaining a Workspace, I want to understand why a Skill is present and verify its Vendor and Projection integrity without mutating either.

The journey installs one selected member, observes declaration and Projection evidence through `why`, verifies healthy state, modifies the coordinate Projection, and receives a failing `verify` result without repair or mutation.

Status: implemented through the released CLI and Hub plus observable Vendor, Projection, and Workspace state by `j47_why_verify_test.go`.

### J48 — Report a committed installation through a Cloud deployment

As a user connected to a Cloud-mode Hub, I want a successful CLI installation to report one anonymous installation fact to the declared Cloud origin without changing the installation result.

The journey starts real CLI and Hub processes plus a separate public-contract Cloud Mock process, verifies `hub info`, installs an immutable fixture Skill, and observes exactly one post-commit event containing the Skill coordinate, version, scope, and Agent.

Status: implemented through released CLI and Hub processes plus the external Cloud Mock boundary by `j48_cloud_install_reporting_test.go`.

## GitHub Issue #27 User-Story Coverage Index

The numbered user stories in #27 are release-reviewed through these black-box journeys:

| #27 stories | E2E evidence |
| --- | --- |
| 1–3: whole Repository, one member, repeated members | J12, J26, J27 |
| 4–5: default head and Repository selector versions | J27, J28 |
| 6–8: explicit head/release, rejected ambiguous selectors, and Repository Version Queries | J27, J28, J32 |
| 9–10: inherited Repository query and rejected per-Skill override | J27 |
| 11–12: release stable-first and prerelease fallback | J28 |
| 13–14: untagged default branch and canonical movable resolution | J07, J08, J28, J32 |
| 15–17: uncatalogued discovery, invalid isolation, revision-faithful Info | J12, J26, J29, J30 |
| 18: disappeared Skill history | J29 |
| 19–20: ambiguity and selector disambiguation | J27, J31 |
| 21–23: canonical persistence, one Repository requirement, integrity/offline recovery | J07, J26, J27 |
| 24–25: Repository ID plus Skill Name identity and root-member semantics | J26, J31 |
| 26–29: shared Go-shaped routes and immutable Info/ZIP/HEAD | J19, J31, J32 |
| 30–32: Git tags as releases, exact discovery, moved-tag immutability | J26, J32 |
| 33–39: demand discovery, TTL, singleflight, snapshot reuse, immutable cache, negative cache, global bounds | J12, J19, J26, J33 |
| 40: demand-discovered Catalog visibility | J35 |
| 41: display identity versus escaped HTTP path | J34 |
| 42: explicit SkillsGo protocol divergence and future-resource isolation | J32, J35 |
| 43: `skillsgo.yaml`, coordinate Projection restoration, and root Proxy versus `/api/v1` separation | J36 |
| Movable head refresh and installed-version separation | J43 |
| Untagged F1 preservation after V1 publication and C2 advance | J44 |
| Repository-fresh batched head/release update checking | J45 |
| Whole-Repository installation atomicity | J46 |
| Dependency explanation and local integrity inspection | J47 |
