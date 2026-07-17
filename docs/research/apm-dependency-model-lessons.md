# Dependency-Model Lessons from Microsoft APM

## Scope and status

This note reviews first-party APM documentation, issues, pull requests, and specifications as of 2026-07-18. It treats open issues as evidence of user pressure or an unresolved design question, not as proof that the proposed design has shipped. APM is useful here as a fast-moving reference implementation, not as an interoperability standard that SkillsGo should copy wholesale.

## Evidence from APM

### Flattened deployment weakens package identity

APM resolves packages but deploys their primitives into agent-owned directories. [Issue #739](https://github.com/microsoft/apm/issues/739) reports that this flattening makes it hard to distinguish project Skills from dependency Skills and makes installed content look editable to agents. The proposed package namespace remains open with `status/needs-design`; it is evidence of a real identity and provenance problem, not yet a settled solution.

This separates two identities that must not be collapsed:

- a stable source identity used for resolution, integrity, inventory, and conflict reporting;
- an installation name or target path constrained by the target Agent's native discovery model.

Renaming every deployed Skill with a package prefix is not automatically safe because it can change the name an Agent or user expects. The source identity must therefore survive even where the final target layout cannot expose a namespace.

### Repository, package, and artifact boundaries diverge under pressure

[Issue #514](https://github.com/microsoft/apm/issues/514) describes a monorepo whose independently useful packages cannot all follow one repository-wide version. Its proposed GitHub Release workflow is still open and in design. [Issue #879](https://github.com/microsoft/apm/issues/879) asks for OCI archives, digest-pinned installs, mirrors, and logical package identity independent of a registry host; it is also open and in design.

APM has since added an experimental HTTP registry path: its [dependency guide](https://microsoft.github.io/apm/consumer/manage-dependencies/) documents registry dependencies and virtual subpaths, and [the lockfile specification](https://microsoft.github.io/apm/reference/lockfile-spec/) distinguishes logical identity, resolved transport URL, virtual path, Git commit, and archive hash. This means the accurate lesson is not "APM has no registry". It is that Git repository identity alone becomes insufficient once packages can be versioned independently, mirrored, or transported as prebuilt archives.

The useful domain separation is:

```text
Repository: discovery and source provenance
Package: dependency-resolution and version-selection unit
Skill: user-visible capability and installable logical member
Artifact: immutable bytes plus integrity identity
Transport: Git, Hub, mirror, OCI, or another retrieval mechanism
```

SkillsGo does not need to introduce all five as public objects today. It should avoid encoding invariants that make them impossible to separate later.

### Shared transitive dependencies require graph reachability, not one parent

APM's [lockfile specification](https://microsoft.github.io/apm/reference/lockfile-spec/) records a complete direct and transitive graph, including depth and `resolved_by`, and its [`deps tree` and `deps why` documentation](https://microsoft.github.io/apm/reference/cli/deps/) exposes that graph to users.

The lifecycle implementation still exposed graph mistakes. [Issue #2254](https://github.com/microsoft/apm/issues/2254) found that uninstall/prune reconciliation cleared transitive hook entries but rebuilt only direct dependencies. The merged fix, [PR #2256](https://github.com/microsoft/apm/pull/2256), changed reconciliation to use all surviving direct and transitive lockfile entries. Separately, [Issue #2291](https://github.com/microsoft/apm/issues/2291) reports that a selective-update preview compares a partial resolution result with the complete lockfile and therefore labels untouched dependencies as removed. The report explicitly says this is a plan-display inconsistency and does not claim that packages are actually deleted.

These incidents establish a general rule: removal, selective update, and reconciliation must operate on the complete post-operation reachable graph, even if resolution was requested for only one root.

A single per-package field such as:

```yaml
dependency: parent-a
```

is insufficient for future shared transitive dependencies. If both `parent-a` and `parent-b` require `shared-c`, one parent edge cannot explain both reasons for retention and cannot safely drive uninstall. Future graph support needs either an edge collection or a normalized graph, for example:

```yaml
edges:
  - from: parent-a
    to: shared-c
  - from: parent-b
    to: shared-c
```

The installed package may still be materialized once, but it must remain installed until it is unreachable from every direct root. `deps why` must be able to return every retaining path, not only one arbitrarily selected parent.

### Generated-file ownership is a separate state model

[Issue #1342](https://github.com/microsoft/apm/issues/1342) documents ambiguity between hand-authored files and APM-derived files at fixed Agent paths. It proposes VCS-ignore management and refusal to overwrite tracked, non-ignored files. APM's [lockfile specification](https://microsoft.github.io/apm/reference/lockfile-spec/) currently records `deployed_files` and per-file hashes for cleanup, audit, and drift detection.

The broader lesson is that a resolved dependency graph does not answer deployment ownership questions. A package can produce multiple files, multiple packages can contribute to a merged target file, users can edit a projected copy, and an Agent can replace a managed path. Safe removal therefore needs explicit claims and integrity state at the deployment layer rather than inferring ownership from directory placement.

### Executable and service dependencies require explicit trust

[Issue #20](https://github.com/microsoft/apm/issues/20) began as a request for richer MCP configuration. Much of the requested transport, environment, header, and registry support has since shipped, so the issue should not be cited as if APM still supports only MCP names. Current [`apm install` documentation](https://microsoft.github.io/apm/reference/cli/install/) shows the expanded MCP surface and keeps transitive MCP trust opt-in. The [security model](https://microsoft.github.io/apm/enterprise/security-and-supply-chain/) explains that transitive MCP servers may request tools, filesystem access, or network capabilities. The [`approve`/`deny` reference](https://microsoft.github.io/apm/reference/cli/approve/) separately gates hooks, binaries, self-defined MCP servers, and extensions.

The remaining warning is important: text content, executable hooks, local processes, remote services, credentials, and permissions are not interchangeable dependencies. Dependency resolution may discover them together, but installation must not silently convert transitive reachability into execution authority. Trust decisions should be explicit, type-specific, provenance-aware, and deny-wins.

### Update automation is useful but not yet a neutral safety signal

[Issue #639](https://github.com/microsoft/apm/issues/639) requests Renovate support and remains open with `status/needs-design`. The discussion identifies Git tags, lockfile regeneration, virtual-package version ownership, and the semantic risk of auto-merging changes to prompts or agent definitions.

SkillsGo should make automated update tooling possible through a stable machine-readable manifest, immutable resolved versions, and deterministic lock regeneration. It should not treat a successful content download or static test suite as sufficient approval for unattended semantic updates.

## Protections SkillsGo already has

The current SkillsGo architecture already avoids several APM failure modes:

- **Repository members retain canonical Skill IDs.** Repository installation expands to concrete Skill packages instead of discarding member provenance.
- **Intent and integrity are separate without a dependency lock.** `skillsgo.yaml` records canonical direct requirements and desired Agents, while the generated `skillsgo.sum` records only hashes for exact immutable Info and Skill content.
- **Artifacts are immutable and content-addressed.** The CLI verifies Hub artifact identity and content before admitting it to the Store.
- **Store and Agent projection are separate.** Agents do not mutate the shared Store directly; installation creates scope-local canonical content and explicit Agent-facing projections.
- **Installation receipts and inventory preserve target state.** SkillsGo can distinguish managed, missing, modified, replaced, dangling, and external installations rather than equating a directory's presence with ownership.
- **Collisions are explicit.** One physical target path exposes one active artifact, and same-name conflicts are not silently resolved by suffixing.
- **Update operations are state-bound.** Exact targets and Workspace Manifest previews reduce the risk that a partial operation silently rewrites unrelated installations.
- **Hub metadata separates source, immutable version, digest, and risk assessment.** Retrieval and integrity are not identified only by a repository URL.

These protections mean SkillsGo should continue projecting only Skills for now. It should not broaden `dependencies` into hooks, MCP servers, binaries, or generic Agent primitives until those types have separate trust and ownership contracts.

## Current gaps and premature assumptions

The current implementation is intentionally a direct-dependency installer, not a transitive package manager. Several shortcuts are acceptable only while that remains true:

- SkillsGo deliberately has no dependency graph or dependency lock while it installs only direct requirements.
- Whole-Repository membership comes from exact immutable Repository Info rather than a copied expansion graph or Skill-ID prefix inference.
- `skillsgo.sum` is historical integrity evidence and must never acquire parent edges, reachability, ownership, or deployment semantics.
- Target receipts describe installed projections, but future merged files would need per-contributor claims rather than one file-to-one-package ownership.
- There is no dependency type or permission model for executable or service dependencies; this is a protection while SkillsGo installs only Skill content, not a missing feature that should be filled generically.
- Repository-wide tags intentionally version all current members together. Independent subpackage versioning should be introduced only with an explicit Package release unit, not inferred from directory paths or overloaded tag patterns.

## Recommendations

### Keep the current release scope narrow

For the lazy Repository/Skill Hub work, retain only:

- Repository discovery and repository-wide version resolution;
- concrete Skill identity for every member;
- immutable Skill Info and ZIP artifacts;
- canonical direct declarations plus deterministic Workspace Sum integrity;
- Store verification and explicit Agent projection.

Do not add transitive dependencies, MCP configuration, hooks, Package namespaces, OCI, or independent monorepo package releases to this ticket set.

### Introduce a graph only when cross-Repository dependencies exist

Do not add a singular parent field to the current Workspace Manifest or Workspace Sum. When cross-Repository dependencies arrive, first expose a small version-bound `.skillsgo` dependency descriptor so version selection can occur without downloading every Skill ZIP. A future graph snapshot, if required, should then contain:

- stable node identities separate from transport URLs;
- an explicit set of directed dependency edges;
- each direct Workspace Manifest declaration represented as a root;
- canonical selected versions and integrity identities per node;
- constraints recorded on edges or declarations;
- all retaining paths derivable for `deps why`;
- removal computed from full post-operation reachability;
- selective-update plans built by merging the updated subgraph with untouched locked state before diffing.

### Keep deployment ownership out of dependency edges

Continue treating Agent targets and installation receipts as a distinct projection layer. If SkillsGo later generates or merges files, add a deployment-claim model containing at least target path, contributing package/Skill, expected digest, projection mode, and local-modification state. Deleting a graph node may remove only claims that node owns; shared or user-authored content must survive.

### Keep identity visible even when the target layout is flat

Canonical Skill ID, Repository identity, version, and digest should remain queryable through exact Info, Workspace Sum, Store receipts, inventory, conflict UI, and future `why` output. Do not require every Agent target directory name to encode a package namespace. Target-native naming and source identity are related but different concerns.

### Separate content acceptance from authority

If future dependencies can run code or configure services, resolve them into a pending plan first. Require explicit approval for executable/service capabilities, bind approval to stable source and preferably immutable artifact identity, preserve an organization-level deny ceiling, and never let a transitive declaration silently grant credentials or runtime permissions.

### Design update automation around reviewable semantic change

Expose deterministic lock regeneration and machine-readable diffs. An update plan should show changed Skill identity, old/new canonical version, origin commit, digest, risk change, added/removed members, and target impact. Automated PR creation can be supported later, but auto-merge should not be the default for agent instructions whose behavior cannot be validated by ordinary compilation tests.

## Review checklist for future dependency work

- Does every resolved Skill retain its source identity after projection?
- Are Repository, future Package, Skill, Artifact, and transport identities kept separable?
- Can one resolved node have multiple incoming dependency edges?
- Is uninstall based on complete reachability from all direct roots?
- Does selective update preserve untouched roots and their reachable closure?
- Can `why` return all retaining paths?
- Are dependency graph, Store state, and deployment ownership distinct models?
- Are local modifications and user-authored files protected from cleanup?
- Are executable and service capabilities denied until explicitly approved?
- Are update diffs reviewable without downloading or trusting mutable source state?
