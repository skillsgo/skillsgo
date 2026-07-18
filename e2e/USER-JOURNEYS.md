# CLI and Hub User Journeys

This catalog defines black-box user stories that cross the SkillsGo CLI and Hub boundary. A journey describes a user outcome through public process, HTTP, and filesystem contracts; it is not a command-coverage checklist.

## Selection Rules

- Use real supported Agent Adapters rather than test-only adapters.
- Exercise the released CLI and Hub binaries in a fresh container for every journey.
- Assert stable JSON, exit codes, Hub responses, Workspace declarations, Store state, and Agent-visible files.
- Do not assert localized terminal copy or internal Go types.
- Keep destructive and failure scenarios inside the disposable container filesystem.
- Prefer deterministic local source fixtures for required CI journeys; reserve live public sources for smoke journeys.

## P0 — Release-Gating Journeys

### J01 — Install a public Skill into a Workspace

As a terminal user, I want to install a public Skill for a real Agent in my current Workspace so that the Agent can use it immediately.

The CLI resolves the requested reference through the Hub, verifies the immutable artifact, stores it, creates the Agent-visible target, and writes matching Workspace Manifest and Workspace Sum entries. Re-running the same request must not corrupt or duplicate state.

Status: implemented for Codex in copy mode by `j01_install_workspace_test.go`.

### J02 — Remove a Workspace installation without deleting the Store artifact

As a terminal user, I want to remove a Skill from one Agent in my Workspace so that the Agent no longer sees it while the verified artifact remains available for recovery or another target.

The selected Installation Target and its declaration binding disappear, unrelated targets remain intact, and the immutable Store entry remains readable.

Status: implemented for Codex by `j02_remove_workspace_test.go`.

### J03 — Restore a declared Workspace from its Manifest and Sum

As a user opening an existing Workspace, I want `skillsgo install` to recreate every declared Agent target from canonical requirements and verified immutable caches so that the Workspace is reproducible on a clean machine.

The restored files match the Workspace Sum, all declared targets exist, and restoration uses only canonical versions from `skillsgo.mod` rather than re-resolving movable input.

Status: implemented for a clean Codex copy-mode restore, including invocation from a nested Workspace directory, by `j03_restore_sum_test.go`.

### J04 — Recover an Agent target while the Hub is unavailable

As a user with a previously cached artifact, I want to restore a missing target without reaching the Hub so that temporary network or Hub outages do not block local recovery.

The CLI restores from the Content-addressed Store, leaves the Workspace Sum unchanged, and performs no successful Hub request.

Status: implemented for Codex with an explicitly unreachable Hub by `j04_restore_store_offline_test.go`.

### J05 — Reject a corrupted download atomically

As a user, I want a corrupted, truncated, or digest-mismatched Hub artifact to be rejected so that unverified content never reaches my Store or Agent directories.

The command fails with a stable machine result; no valid receipt, Installation Target, Manifest change, or Sum change is committed.

Status: implemented by corrupting the real Hub disk-cached ZIP in `j05_corrupted_download_test.go`.

### J06 — Enforce immutable risk confirmation

As a user installing an assessed Skill, I want High and Critical risk policy to require explicit confirmation so that dangerous artifacts cannot be installed by an accidental non-interactive command.

An unconfirmed command leaves no local mutation. The exact reviewed immutable artifact succeeds only with the required confirmation flags, and a changed artifact requires a new decision.

Status: implemented for both High and Critical policy branches by `j06_risk_confirmation_test.go`.

### J07 — Re-resolve a movable Skill reference explicitly

As a user who previously selected a branch, I want an explicit `add ...@branch` to resolve it again while ordinary restore remains immutable.

The target, Store receipt, canonical resolved version, digest, commit identity, and Sum are updated together. The branch name is never persisted, and historical Sum entries remain valid evidence.

Status: implemented from a known old commit to an explicit re-resolution of `main` by `j07_update_movable_test.go`.

### J08 — Preserve pinned installations during update

As a user who selected a tag or fixed commit, I want normal update checks to leave that installation pinned so that reproducibility is not silently broken.

The CLI reports no movable update, does not rewrite the Workspace Manifest or Sum, and does not replace the Agent target.

Status: implemented for an exact commit through Update Plan preflight by `j08_preserve_pin_test.go`.

## P1 — Core Multi-Target Journeys

### J09 — Install one Skill for multiple real Agents

As a user working with multiple Agents, I want one Skill installed for each selected Agent so that all of them see the same reviewed content.

One scope-local canonical artifact backs every requested Installation Target, shared physical paths are not duplicated, and each Agent binding is represented accurately in the declaration.

Status: implemented for Codex plus Claude Code by `j09_multi_agent_install_test.go`.

### J10 — Remove one Agent binding while preserving another

As a multi-Agent user, I want to remove one Agent's binding without removing the same Skill from other Agents so that target management remains exact.

Only the selected target or binding disappears; shared canonical content and other Agent visibility remain healthy.

Status: implemented by removing only the Claude Code projection in `j10_remove_one_binding_test.go`.

### J11 — Install and remove a user-scope Skill

As a user, I want to make a Skill available to an Agent across Workspaces and later remove that user-level installation without touching project declarations.

The CLI mutates only the Agent's user-level Managed Skill Root and the User Declaration Root under `~/.skillsgo` inside the isolated environment.

Status: implemented for Codex copy mode plus a Hermes Agent-specific home override by `j11_user_scope_test.go`.

### J12 — Install every Skill from a multi-Skill repository

As a user selecting a repository source, I want SkillsGo to discover and install all contained Skills so that I do not have to enumerate nested Skill IDs manually.

Every discovered Skill resolves to its own immutable artifact and target, while the editable declaration retains the repository dependency needed for future restoration.

Status: implemented with two real nested Skills from `vercel-labs/agent-skills`, including direct installation and offline restoration of a source-directory/Manifest-name mismatch, by `j12_repository_install_test.go`.

### J13 — Replace a same-name Skill only after explicit review

As a user changing a target from one Skill ID to another with the same local name, I want SkillsGo to surface the conflict and require explicit replacement so that source identity is never changed silently.

Rejection preserves the old target and declarations. Approved replacement changes the target, Manifest, and Sum together and removes obsolete bindings.

Status: implemented across two exact nested Skill IDs with one shared source-authored name in a deterministic Repository by `j13_explicit_replacement_test.go`.

### J14 — Protect Local Modifications in copy mode

As a user who edited an installed copy, I want update and removal to detect my Local Modifications so that my work is not overwritten or deleted without review.

The unreviewed operation fails without mutation. A reviewed, state-bound decision expires if the target changes again before execution.

Status: implemented through Management Plan rejection by `j14_local_modification_test.go`.

## P2 — Inventory and Operational Journeys

### J15 — Inventory managed and external Agent Skills

As a user, I want one machine-readable inventory of managed installations, Local Modifications, unhealthy targets, and External Skills so that I can understand actual Agent visibility before mutating anything.

The result distinguishes Installation Targets from read-only Agent Visibility and does not adopt or modify External Skills.

Status: implemented with one managed Hub Skill and one preserved External Skill by `j15_inventory_test.go`.

### J16 — Repair an unhealthy managed target

As a user whose managed target is missing or damaged, I want to repair it from the immutable Store artifact so that the exact reviewed version becomes usable again.

Repair restores every binding sharing the physical target, preserves declarations, and requires review before replacing Local Modifications.

Status: implemented for a modified Codex canonical target by `j16_repair_test.go`.

### J17 — Stop managing while preserving content

As a user, I want SkillsGo to stop managing a target without deleting its files so that I can keep a manual copy outside SkillsGo lifecycle control.

Declarations and management metadata are removed while the filesystem content remains present and is subsequently reported as external when discoverable.

Status: implemented for a locally modified Codex target by `j17_stop_managing_test.go`.

### J18 — Fail clearly when the Hub is unavailable and no cache exists

As a user installing an uncached Skill during an outage, I want a stable availability result so that scripts and the App can distinguish infrastructure failure from invalid input.

The CLI returns the documented Availability Exit Code, emits no misleading success JSON, and leaves local state unchanged.

Status: implemented with an empty Store and unreachable Hub by `j18_hub_unavailable_test.go`.

### J19 — Reuse one immutable Hub artifact deterministically

As a user repeating a download or installing the same version for another target, I want the Hub and CLI to reuse byte-identical immutable content so that cache behavior cannot change the installed Skill.

Repeated Hub responses preserve Info identity, Content Digest, and archive bytes; the CLI reuses the compatible Store entry instead of creating conflicting content.

Status: implemented with repeated immutable ZIP downloads and a second real Agent target by `j19_immutable_reuse_test.go`.

### J20 — Keep every journey isolated from the host

As a contributor running the e2e suite, I want every scenario to execute in a disposable filesystem so that a broken path rule cannot alter my real SkillsGo, Agent, or Workspace state.

Each journey owns one container and one temporary `/e2e` mount. No host home, repository directory, Docker socket, or real Agent directory is mounted into the scenario container.

Status: enforced for every scenario by the mount inspection in `startEnvironment` and explicitly covered by `j20_host_isolation_test.go`.

### J21 — Preserve the complete Skill resource tree

As a user installing a multi-file Skill, I want every nested resource to survive Hub packaging, Store verification, and Agent installation so that progressive-disclosure references and scripts remain usable.

The installed copy contains the same non-empty nested resource bytes as the immutable Store artifact. Copy-mode compatibility for dotfiles and executable bits remains covered at the CLI installer boundary.

Status: implemented with the real nested `rules/async-parallel.md` resource from `vercel-labs/agent-skills` by `j21_preserve_skill_resources_test.go`.

### J22 — Update only the selected direct Skill

As a user updating one direct Skill dependency, I want sibling Skills from the same repository to remain unchanged so that direct Skill and whole-repository declarations retain distinct meanings.

The sibling target bytes and complete Workspace Sum remain unchanged when the selected Skill is already current; repository-wide expansion remains exclusive to an explicit repository dependency.

Status: implemented by explicitly re-adding one direct Skill at a newer immutable version while retaining its sibling's v1 target and historical Sum evidence by `j22_update_only_selected_skill_test.go`.

### J23 — Signal update failure and preserve state atomically

As an automation user, I want any failed requested update to return a non-zero process status so that scripts cannot mistake a reported failure for success.

The previous Target, Manifest, and Sum bytes remain unchanged after failure. Explicit multi-target Update Plans also return failure when their structured result contains one or more failed targets.

Status: implemented for an unavailable Hub by `j23_update_failure_atomic_test.go`, with partial Update Plan behavior at the CLI command seam.

### J24 — Resolve deeply nested Skills without false absence

As a user installing or updating a deeply nested Skill, I want its complete canonical path to remain resolvable so that bounded discovery depth cannot turn a live Skill into an apparent deletion.

Direct resolution and explicit immutable re-add succeed for a four-level Skill path and preserve the installed target.

Status: implemented with a deterministic four-level Repository path by `j24_deep_skill_discovery_test.go`.

### J25 — Bind catalog risk to the exact immutable artifact

As a user reviewing a catalog entry, I want its risk assessment to identify the same Content Digest as the displayed immutable artifact so that stale assessment results cannot masquerade as current.

The detail response exposes one immutable version and a Risk Assessment whose `artifactDigest` exactly equals the response `contentDigest`.

Status: implemented through the public Hub detail endpoint by `j25_catalog_audit_consistency_test.go`.

## Repository Distribution Journeys

### J26 — Restore a whole Repository while offline

As a Workspace user, I want one bare Repository requirement to restore its exact accepted member set from immutable local caches so that reproducibility does not require a lockfile or a reachable Hub.

Status: implemented for a root Skill, two nested Skills, one omitted invalid candidate, unchanged Manifest/Sum bytes, and an unreachable Hub by `j26_repository_restore_offline_test.go`.

### J27 — Select multiple Repository members at mixed versions

As a CLI user, I want repeated human-readable `--skill` selectors to inherit or override the Repository query so that one operation can intentionally install exact members from different versions.

Status: implemented through a human HTTPS source, one inherited selector, one relative-path override, exact content, and canonical nested Manifest requirements by `j27_selected_skills_mixed_versions_test.go`.

### J28 — Select stable, prerelease, or pseudo versions lazily

As a CLI user, I want omitted queries to prefer the highest stable tag, fall back to the highest prerelease, and resolve an untagged default branch once to a pseudo-version.

Status: implemented against deterministic tagged, prerelease-only, and untagged Git remotes by `j28_repository_version_selection_test.go`.

### J29 — Preserve disappeared Skill history

As a CLI user, I want a Skill removed from a later Repository tag to remain installable at its older immutable version and remain the nested Skill's independent latest publication.

Status: implemented across v1-present and v1.1-absent Repository snapshots by `j29_repository_history_test.go`.

### J30 — Isolate invalid Repository candidates

As a CLI user, I want malformed `SKILL.md` candidates omitted without blocking valid siblings or mutating Workspace state when selected.

Status: implemented through public Repository Info, CLI installation, and unchanged Manifest/Sum evidence by `j30_repository_candidate_isolation_test.go`.

### J31 — Preserve Repository identity and selection boundaries

As a CLI user, I want arbitrary host namespace depth, canonical `/-/` identities, path selectors, duplicate-name errors, and root-only guidance to remain unambiguous.

Status: implemented with multi-level fixture namespaces, canonical/path/name selectors, root rejection, and absence of a bare ZIP for a Repository without a root Skill by `j31_repository_identity_and_selection_test.go`.

### J32 — Keep Repository protocol resources immutable

As a protocol consumer, I want list, latest, Info, ZIP, and HEAD routes to expose canonical resources whose published bytes do not change after a source tag moves.

Status: implemented through public Hub Repository/branch/commit and nested-Skill list/Info/ZIP/HEAD routes, root ZIP presence/absence, repeated byte digests, and a moved source tag by `j32_repository_protocol_immutability_test.go`. Conflict detection for a moved Tag is verified at the Hub Router/publisher boundary, where a forced rematerialization can be injected without relying on private E2E controls.

### J33 — Bound anonymous lazy resolution

As a Hub operator, I want fresh tag catalogs, exact-version bypass, singleflight, global capacity, negative caching, and retry after capacity release to bound anonymous source work.

Status: implemented at the public seam with concurrent Hub HTTP requests, deterministic slow source fixtures, fresh tag-catalog stability, exact-version bypass, and observable capacity/retry behavior by `j33_lazy_resolution_controls_test.go`. TTL expiry, exact singleflight call counts, immutable-cache call counts, and negative-cache lifetime/call counts are verified with injected clocks at the Hub Router/publisher boundary rather than through sleeps or private Git traces.

### J34 — Separate display identity from escaped transport paths

As a protocol consumer, I want normalized Repository identity and case-preserving nested Skill paths to survive Go-style HTTP escaping.

Status: implemented with mixed-case source input, a mixed-case Git tree path, canonical Manifest identity, and a directly requested escaped Info route by `j34_coordinate_case_and_escape_test.go`.

### J35 — Populate Catalog lazily without legacy protocol resources

As a Catalog and protocol consumer, I want ordinary demand discovery to publish newly observed Skills while the maintained protocol remains limited to list, latest, Info, and ZIP resources.

Status: implemented from an initially absent Skill detail through ordinary add and subsequent Catalog visibility, with explicit absence checks for `@resolve`, `.manifest`, and the future `.skillsgo` resource, by `j35_lazy_catalog_and_protocol_surface_test.go`.

### J36 — Restore portable Agent targets through separated module and API surfaces

As a user moving a Workspace between machines, I want `skillsgo.mod` to preserve exact requirements and Agent targets while the Hub keeps artifact transport separate from product APIs.

Status: implemented with canonical `require` formatting, Codex and Claude Code target restoration, unchanged `skillsgo.mod` and `skillsgo.sum` bytes, successful `/mod` and `/api/v1` requests, and explicit 404 responses from the removed root artifact and `/v1` routes by `j36_mod_namespace_and_restore_test.go`.

## GitHub Issue #27 User-Story Coverage Index

The numbered user stories in #27 are release-reviewed through these black-box journeys:

| #27 stories | E2E evidence |
| --- | --- |
| 1–3: whole Repository, one member, repeated members | J12, J26, J27 |
| 4–5: default latest and selector-attached versions | J27, J28 |
| 6–8: branch, commit, and Repository Version Queries | J27, J32 |
| 9–10: selector override and inherited query | J27 |
| 11–12: stable-first and prerelease fallback | J28 |
| 13–14: untagged default branch and canonical movable resolution | J07, J08, J28, J32 |
| 15–17: uncatalogued discovery, invalid isolation, revision-faithful Info | J12, J26, J29, J30 |
| 18: disappeared Skill history | J29 |
| 19–20: ambiguity and selector disambiguation | J27, J31 |
| 21–23: canonical persistence, one Repository requirement, integrity/offline recovery | J07, J26, J27 |
| 24–25: explicit `/-/` boundary and root-as-whole-Repository semantics | J26, J31 |
| 26–29: shared Go-shaped routes and immutable Info/ZIP/HEAD | J19, J31, J32 |
| 30–32: Git tags as releases, exact discovery, moved-tag immutability | J26, J32 |
| 33–39: demand discovery, TTL, singleflight, snapshot reuse, immutable cache, negative cache, global bounds | J12, J19, J26, J33 |
| 40: demand-discovered Catalog visibility | J35 |
| 41: display identity versus escaped HTTP path | J34 |
| 42: explicit SkillsGo protocol divergence and future-resource isolation | J32, J35 |
| 43: `skillsgo.mod`, Agent target restoration, and `/mod` versus `/api/v1` separation | J36 |
