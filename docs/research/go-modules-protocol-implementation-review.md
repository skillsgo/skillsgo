# Go Modules Protocol Review for SkillsGo

## Scope and method

This living review compares the complete [Go Modules Reference](https://go.dev/ref/mod) with the current SkillsGo Hub, Protocol, and CLI implementations. It does not assume that Go's domain model is automatically correct for SkillsGo. Each task records:

- the Go contract and the problem it solves;
- the closest SkillsGo implementation and executable evidence;
- whether SkillsGo should copy, adapt, defer, or reject the contract;
- duplicated implementation, inherited residue, and semantic drift;
- a concrete disposition and follow-up.

The classification vocabulary is:

- **Copy**: preserve the Go behavior and prefer its public library implementation.
- **Adapt**: preserve the design principle but change domain-specific syntax or lifecycle.
- **Defer**: useful only after a named capability exists.
- **Reject**: tied to Go compilation or another inapplicable domain concern.
- **Duplicate**: SkillsGo locally reimplements an available public Go primitive without a justified boundary.
- **Drift**: SkillsGo claims or inherits Go-like behavior but no longer satisfies the relevant semantic contract.

## Executive conclusion

SkillsGo should not become a second Go module client. It should reuse the small set of Go mechanisms that solve the same integrity and distribution problems, adapt the release model to Repository Publications and per-Skill artifacts, and remove inherited behavior that implies a dependency graph or direct VCS client.

The durable architecture is:

- a **Repository** is the version-selection and publication unit;
- a **Skill** is the independently installable and content-addressed member;
- one Repository Publication atomically exposes every valid Skill observed at one immutable version and commit;
- `add` resolves a movable selector once, asks the Hub to publish the complete selected Repository snapshot, and installs only the requested members;
- authenticated Repository History Backfill invokes that same publication seam for older semantic-version Tags;
- immutable Info and Sum remain resident, while hot ZIP bytes may be evicted only after an authoritative exact cold copy exists and restoration is tested;
- the CLI verifies one Go-compatible Skill-relative `h1:` Sum, records it in `skillsgo.sum`, stores immutable extracted content, and never falls back directly to VCS;
- a future SumDB authenticates Skill Sums and canonical Repository release records through the public `x/mod/sumdb` protocol rather than per-artifact signatures or a custom Merkle implementation.

### Copy, adapt, defer, and reject at a glance

| Disposition | Mechanisms |
| --- | --- |
| Copy and reuse | `x/mod/semver`, canonical pseudo-version primitives, declarative manifest principles, `dirhash` h1, immutable proxy resources, bounded ZIP validation concepts, cache verification, `x/mod/sumdb`, `tlog`, and `note` checkpoints. |
| Adapt | Repository-wide versions with per-Skill ZIPs; explicit `/-/`; the `/mod` resource protocol; one authoritative Hub; full selected-release materialization; authenticated history Backfill; hot/cold ZIP residency; `skillsgo.mod` and `skillsgo.sum`. |
| Defer | Artifact eviction until cold restoration is guaranteed; SumDB until immutable records and visibility are correct; retractions, mirrors, and dependency constraints until their product capabilities exist. |
| Reject | MVS and dependency-graph directives; `/v2` identity suffixes; `+incompatible`; `.mod` proxy resources; `go.work`; package-to-module prefix search; direct CLI-to-VCS fallback; per-ZIP signatures; a second BLAKE3 content fingerprint. |

### Highest-risk findings

1. A public Hub that can read private source may currently materialize and publicly serve private Repository content on an ordinary `/mod` cache miss. Visibility must become an end-to-end authorization property before mixed public/private source authority is enabled.
2. The configured offline mode is not an invariant: Info and ZIP misses can still reach VCS or enqueue materialization. Source access policy must apply at the publication boundary, not only to List and Latest.
3. Storage immutability is backend-dependent, Repository publication can expose partial Info/ZIP pairs, and an existing publication is trusted primarily by commit SHA. Create-only publication, collision verification, and explicit artifact state are prerequisites for durable history and SumDB.
4. The Git resolver observes multiple Tag namespaces. Exact resolution, `latest`, pseudo-version ancestry, tagged-commit canonicalization, and Backfill must use one Tag catalog.
5. Producer and consumer ZIP validators have drifted, while some reads allocate the complete remote ZIP or `SKILL.md` before enforcing limits. One cross-platform validation contract and bounded streaming are required.
6. Immutable artifact/release evidence currently embeds refreshable Risk state. SumDB and long-lived Info require immutable content metadata to be separated from mutable assessment and product projections.

### Wheels to remove

The main duplicated wheels are not the intentional SkillsGo domain adaptations. They are local substitutes for public or already-owned primitives: copied path escaping instead of `module.UnescapePath`, two active h1 framings plus an unused vendored Hash1, duplicated ZIP limits and path validators, duplicated pseudo-version recognition, nested/custom singleflight layers, fragile lock implementations, and the remaining Athens mode/configuration matrix. Each should have one owner and one conformance suite.

## Task inventory

| Task | Go Modules sections | SkillsGo concern | Status |
| --- | --- | --- | --- |
| 01 | Modules, packages, paths, versions, pseudo-versions, major suffixes, package-to-module resolution | Repository / Skill identity and immutable version selection | Complete |
| 02 | `go.mod` lexical grammar and directives | `skillsgo.mod` declaration format and parser ownership | Complete |
| 03 | MVS, replacement, exclusion, upgrade, downgrade | Dependency and update semantics | Complete |
| 04 | Graph pruning and lazy module loading | Demand-driven metadata and ZIP materialization | Complete |
| 05 | Workspaces and `go.work` | User / Workspace scope composition | Complete |
| 06 | Non-module compatibility and `+incompatible` | Legacy or unversioned Skill sources | Complete |
| 07 | Module-aware commands | CLI command lifecycle and offline restore | Complete |
| 08 | Version queries | Selector grammar and immutable resolution | Complete |
| 09 | GOPROXY protocol endpoints | `/mod` HTTP contract | Complete |
| 10 | Proxy communication and fallback | Hub origins, cache modes, errors, and privacy | Complete |
| 11 | Direct proxy serving | Hub publication and immutable storage | Complete |
| 12 | VCS discovery and version mapping | Git resolver, repository cache, and source security | Complete |
| 13 | Module ZIP files and limits | Skill ZIP format, validation, and extraction | Complete |
| 14 | Private modules and credentials | Public / private Hub and source authentication | Complete |
| 15 | Module cache | CLI Store, Info cache, Hub repository cache, and eviction | Complete |
| 16 | Authentication, `go.sum`, and checksum database | Sum, local integrity ledger, and future SumDB | Complete |
| 17 | Environment variables | Configuration surface and policy composition | Complete |
| 18 | Glossary and final architecture synthesis | Naming, boundary corrections, and prioritized migration plan | Complete |

## Task 01 — Domain units, identity, and immutable versions

### Go contract

The Go reference defines a **module** as the collection of packages released, versioned, and distributed together. A module path plus version identifies that release. Packages are members discovered below the module root; they are not independently versioned by the module system. Go applies canonical semantic versions, pseudo-versions for untagged revisions, and a major-version suffix in the module path for `v2+`. Package lookup searches module-path prefixes and selects the longest module that actually contains the package.

Primary sources:

- [Modules, packages, and versions](https://go.dev/ref/mod#modules-overview)
- [Module paths](https://go.dev/ref/mod#module-path)
- [Versions](https://go.dev/ref/mod#versions)
- [Pseudo-versions](https://go.dev/ref/mod#pseudo-versions)
- [Major version suffixes](https://go.dev/ref/mod#major-version-suffixes)
- [Resolving a package to a module](https://go.dev/ref/mod#resolve-pkg-mod)
- [`golang.org/x/mod/module`](https://pkg.go.dev/golang.org/x/mod/module)
- [`golang.org/x/mod/semver`](https://pkg.go.dev/golang.org/x/mod/semver)

### Correct SkillsGo domain mapping

The closest mapping is not `Skill = Go Module`:

| Go | SkillsGo | Reason |
| --- | --- | --- |
| Module | Repository Publication / repository-wide release | One Git tag resolves one Repository snapshot and versions all discovered members together. |
| Package | Skill | A Skill is a member below the Repository root and is discovered from `SKILL.md`. |
| Module ZIP | Individual Skill Artifact plus Repository Info | SkillsGo deliberately distributes each member independently even though its version comes from the Repository release. |
| Module path | Repository ID | It identifies the source and release unit. |
| Package path | Skill ID (`repository/-/skill/path`) | It identifies a member beneath the release unit. |

This is a hybrid worth preserving: **Repository is the version-selection unit; Skill is the installable and content-addressed unit**. The current source model already expresses this in [`hub/pkg/skill/fetcher.go`](../../hub/pkg/skill/fetcher.go), where `RepositorySnapshot` has one version and commit while each `RepositoryMember` owns an independently downloadable artifact.

### What remains valuable

1. **Canonical SemVer and pseudo-version primitives.** [`protocol/version/version.go`](../../protocol/version/version.go) correctly delegates syntax and ordering to `golang.org/x/mod/semver` and pseudo-version recognition to `golang.org/x/mod/module`. Stable releases are preferred over prereleases, and pseudo-versions are excluded from published Tag selection.
2. **Pseudo-version construction.** [`hub/pkg/skill/git_fetcher.go`](../../hub/pkg/skill/git_fetcher.go) uses `module.PseudoVersion`, `PseudoVersionRev`, `PseudoVersionTime`, and `PseudoVersionBase` rather than recreating their string grammar.
3. **Immutable resolution result.** A movable branch or `latest` becomes a version, ref, commit SHA, tree SHA, and commit time before artifact publication. This preserves the crucial Go separation between a query and an immutable selected revision.
4. **Stable-first release selection.** The shared selector in [`protocol/version/version.go`](../../protocol/version/version.go) correctly orders published Tags: the highest release wins; the highest prerelease is used only when no release exists. That primitive should belong to a `release` channel rather than define every meaning of “latest” in SkillsGo.
5. **Exact pseudo-version authenticity checks.** SkillsGo verifies the commit suffix, timestamp, base Tag existence, and ancestor relationship. `x/mod` exposes parsing and construction but not a complete VCS-backed authenticity validator, so the VCS checks are justified domain code rather than avoidable duplication.

### What should remain adapted

1. **No `/v2` Skill-ID suffix.** ADR 0004 intentionally rejects Go import-compatibility suffixes. SkillsGo has no Go compiler import graph and records an exact immutable version in its declaration, so `github.com/owner/repo@v2.0.0` does not need a second public identity. This is a sound adaptation, not a compatibility defect.
2. **Explicit `/-/` member boundary.** Go can infer a package path from module-prefix matching. SkillsGo needs to distinguish an arbitrary repository path from a nested Skill path before source inspection. The explicit separator avoids ambiguous host/repository parsing and should remain.
3. **Repository-wide version with per-Skill artifacts.** Go distributes one ZIP for all packages. SkillsGo should keep small per-Skill ZIPs because installation, auditing, matching, and eviction operate at Skill granularity. Repository Info is the release-membership snapshot that Go does not need.
4. **No package-to-module discovery algorithm.** Users add a Repository or canonical Skill ID, not an unresolved capability import path. Longest-prefix probing would add network traffic and ambiguity without solving a current product requirement.

### Tagless ecosystem reality and update discovery

As of 2026-07-22, the official GitHub Tags and Releases APIs for both [`vercel-labs/agent-skills`](https://api.github.com/repos/vercel-labs/agent-skills/tags) and [`anthropics/skills`](https://api.github.com/repos/anthropics/skills/tags) return empty arrays; their corresponding release lists are also empty, and both use `main` as the default branch. These are not marginal legacy sources. They demonstrate that default-branch publication is a primary distribution practice in the Agent Skill ecosystem.

The current resolver can install them: when no canonical Tag exists, `latest` falls back to the refreshed default-branch HEAD and returns a pseudo-version. `TestNoTagLatestObservesRemoteDefaultBranchAndReturnsPseudoVersion` proves that a later resolution can observe a moved remote HEAD. Tag-first is therefore not Tag-only.

The current update-check path still cannot reliably discover that movement. `skillsgo updates check` calls a Catalog-only batch endpoint, and the endpoint returns the `latest_version` already stored for each Skill without refreshing the Repository. Unless another request has caused the new default-branch snapshot to be published, the Catalog continues to report the old pseudo-version. This is a freshness gap, not a pseudo-version limitation.

A single Tag-first `latest` also has a second domain problem: if a previously Tagless Repository creates one Tag and then continues publishing only on `main`, release-first selection stops observing later default-branch work. SkillsGo should expose two independent candidates:

- **head:** the refreshed default-branch HEAD, canonicalized to a Tag when that exact commit has one and otherwise represented by a pseudo-version;
- **release:** the highest stable canonical Tag, falling back to the highest prerelease Tag.

Missing selectors for ordinary add should resolve the `head` candidate because source repositories are the ecosystem's active publication channel. Exact Tags and pseudo-versions remain pins. Update checking should refresh or freshness-cache both candidates once per Repository, coalescing all member Skills, rather than read only the existing Catalog row or query once per Skill. A bounded TTL, singleflight, and provider webhook/background refresh may reduce source traffic, but stale Catalog state must be visible in the response.

The Manifest can continue storing only the exact immutable selected version for reproducible restore. Advisory update checking does not require tracking intent: it can report both head and release candidates for comparison. If automatic following is added later, it needs an explicit first-class `track head`, `track release`, or `track branch:<name>` field; it must not infer intent from the installed version.

### Drift and inherited residue

1. **Skill `latest` and Repository `latest` follow different client paths.** `Client.Repository` requests `@v/list`, selects the latest release locally, and falls back to `@latest`; `Client.FetchWithProgress` requests `@v/latest.info` directly. Go's proxy flow consults the list first. These paths can disagree when upstream disappears but retained storage still has tagged versions. The Hub list may serve retained immutable history while direct `@latest` depends on the VCS lister. This is semantic drift inside SkillsGo, not merely a Go difference.
2. **The inherited pseudo-version fallback in `List` is ineffective for the current CLI.** [`hub/pkg/download/protocol.go`](../../hub/pkg/download/protocol.go) may return stored pseudo-versions when a Repository has disappeared, but [`cli/internal/hub/client.go`](../../cli/internal/hub/client.go) deliberately filters pseudo-versions from `Versions`. The client then calls `@latest`, which requires upstream access and can fail. The Athens-era branch therefore neither guarantees restore nor cleanly matches the Go proxy list contract.
3. **Tag namespaces are not used consistently.** Refreshes place remote Tags under `refs/skillsgo/upstream-tags/*`, and exact semantic resolution prefers that namespace. However, pseudo-version base selection uses `git tag --merged`, and tagged-commit canonicalization uses `git tag --points-at`; both inspect ordinary local Tag refs. After Tag additions or moves, exact resolution and pseudo-version derivation can observe different Tag sets. This is a real resolver consistency risk.
4. **`latest` ownership is duplicated across layers.** Hub source resolution, Hub list behavior, shared Protocol selection, CLI selection, and Catalog-only update checking each participate. The ordering primitive is shared, but release selection, default-branch freshness, and stored-Catalog freshness are conflated. This increases the chance that Repository and Skill behavior diverge again.
5. **Terminology still overstates Go compatibility.** Several inherited comments and types call Skills `module` or say the endpoint mirrors `cmd/go`, even though `.mod`, major-path rules, graph semantics, and exact query behavior are intentionally different. That wording hides adaptations and makes accidental compatibility claims likely.

### Disposition

- **Copy:** continue using `x/mod/semver` and `x/mod/module` for all exported primitives they provide.
- **Adapt:** keep Repository-wide versions, per-Skill artifacts, `/-/`, and no major suffix.
- **Reject:** do not implement package-prefix-to-module discovery.
- **Fix:** define distinct `head` and `release` candidates shared by Repository reads, Skill reads, and update checks; make retained-history behavior explicit when upstream is unavailable.
- **Fix:** introduce one Tag catalog abstraction used by exact Tag resolution, release selection, tagged-commit canonicalization, pseudo-version base selection, and Backfill.
- **Fix:** make update checking refresh or freshness-cache source state once per Repository; do not present Catalog-only state as a current upstream check.
- **Remove or redesign:** delete the inherited pseudo-version `List` fallback unless a tested client-visible offline contract uses it.
- **Rename on touch:** replace maintained `module` terminology with Repository, Skill, artifact, or resource terminology according to the actual object.

### Task 01 review verdict

The fundamental version machinery is mostly strong and already reuses the correct Go public libraries. The largest issue is not duplicate SemVer code; it is **policy fragmentation around Tag catalogs and `latest`**. The domain mapping should be made explicit in architecture docs because treating `Skill = Go Module` obscures why Repository Info exists and why per-Skill ZIPs are a deliberate departure.

## Task 02 — `go.mod` grammar and `skillsgo.mod`

### Go contract

`go.mod` is a UTF-8, line-oriented, human-readable and machine-writable declaration. Its grammar and syntax tree are implemented by the public [`golang.org/x/mod/modfile`](https://pkg.go.dev/golang.org/x/mod/modfile) package. The reference defines lexical rules plus `module`, `go`, `toolchain`, `godebug`, `require`, `tool`, `ignore`, `exclude`, `replace`, and `retract` directives. Those directives are not a generic configuration vocabulary: most exist to drive Go compilation, toolchain selection, or module-graph selection.

Primary sources:

- [`go.mod` files](https://go.dev/ref/mod#go-mod-file)
- [Lexical elements](https://go.dev/ref/mod#go-mod-file-lexical)
- [Grammar](https://go.dev/ref/mod#go-mod-file-grammar)
- [`require`](https://go.dev/ref/mod#go-mod-file-require)
- [`replace`](https://go.dev/ref/mod#go-mod-file-replace)
- [`exclude`](https://go.dev/ref/mod#go-mod-file-exclude)
- [`retract`](https://go.dev/ref/mod#go-mod-file-retract)
- [Automatic updates](https://go.dev/ref/mod#go-mod-file-updates)

### What is correctly copied

1. **A declarative, editable direct-requirement file.** `skillsgo.mod` is the portable desired-state file and is correctly separated from `skillsgo.sum` and machine-local Installation Receipts.
2. **Direct requirements as the only portable membership declarations.** SkillsGo has no transitive dependency graph, so the Manifest should continue to express direct Repository or Skill requirements rather than inferred graph state.
3. **The instinct to use a mature parser.** The implementation calls `modfile.Parse` instead of recreating all lexical mechanics. The parser choice is wrong for the final domain grammar, but using an established structured parser remains the correct engineering principle.
4. **Only direct requirements.** Rejecting `// indirect` is consistent with the current product: SkillsGo has no transitive dependency graph, so pretending that indirect requirements exist would create false semantics.
5. **Crash-safe, cross-process mutation.** File locking, temporary-file publication, fsync, and transaction recovery are SkillsGo lifecycle requirements independent of the surface grammar; this code is justified and should remain owned locally.

### What should remain rejected or deferred

| Directive | Disposition | Reason |
| --- | --- | --- |
| `module` | Reject now | A Workspace is an installation scope, not a publishable Skill or Repository identity. |
| `go`, `toolchain`, `godebug` | Reject | They control Go language and toolchain behavior. |
| `tool` | Reject | SkillsGo does not install executable tool dependencies. |
| `ignore` | Reject | Package-pattern traversal is not a SkillsGo Workspace operation. |
| `exclude` | Defer | It is meaningful only with dependency constraints and graph selection. |
| `replace` | Defer | A future reviewed local or mirror override may need it, but current Local Skill import is a separate provenance model. |
| `retract` | Move to publisher metadata later | Retraction describes released versions and belongs to Hub publication, not consumer Workspace intent. |

### Duplicate implementation and drift

1. **The custom Agent suffix bypasses `modfile`'s important validation.** `convertAgentListsToComments` extracts the real version, replaces it with `v0.0.0`, and only then invokes `modfile.Parse`. As a result, the parser never validates the stored version. A hand-edited `skillsgo.mod` can contain `main`, an arbitrary Tag, or another path-safe mutable selector even though the domain contract says the Manifest stores an immutable resolved version.
2. **The claimed Go grammar is only partially accepted.** The preprocessor recognizes a block only when trimmed text is exactly `require (` and parses entries with line-oriented string operations. `modfile` accepts according to tokens and syntax nodes, but the custom pre-pass introduces a narrower undocumented grammar before the official parser sees the file.
3. **Canonical Skill ID validation is missing at the Manifest boundary.** Parsing relies on Go module-path syntax, not `protocol/skillid`. The two grammars intentionally differ (`/-/`, no major suffix, repository rules), so a syntactically acceptable but non-canonical resource path can enter the in-memory Manifest and fail later at Store or Hub boundaries.
4. **Machine updates discard human structure and comments.** Mutations parse into a reduced map and regenerate one canonical block. Go's `modfile.File` retains a syntax tree and can format edits while preserving associated comments. Calling the file human-editable while erasing comments on every install is a behavioral regression from the design being copied.
5. **`Mode` exists but is not portable.** `SkillRequirement.Mode` participates in installation planning, yet neither parsing nor writing persists it. After restoration on another machine, copy versus symlink intent is lost and silently defaults. This contradicts the type's apparent role and the claim that the Manifest fully expresses portable target intent.
6. **Source identity is represented twice in memory.** The map key and `SkillRequirement.Source` are forced to the same value. The duplicate field has no independent serialized meaning and creates opportunities for inconsistent callers.
7. **Treating native fields as extensions to Go grammar is the wrong constraint.** `[agent, ...]` is not a Go comment or directive, so every `modfile` operation currently requires a SkillsGo lexical rewrite. The Agent list itself may remain in the compact native grammar, but it must be parsed as a first-class field together with mode. Moving either field into a reserved comment would make the Manifest look like a patch layered over `go.mod`.

### Better boundary

Make `skillsgo.mod` a first-class SkillsGo manifest. Requirement identity, immutable version, Agent targets, and installation mode are all domain data and should occupy fixed grammar positions rather than comments. The compact canonical form is:

```text
require github.com/owner/repo/-/skills/design v2.0.0 [codex, zed]
```

The omitted mode above means `symlink`. Copy mode is explicit:

```text
require github.com/owner/repo/-/skills/design v2.0.0 [codex, zed] copy
```

Block form remains available for multiple requirements:

```text
require (
  github.com/owner/repo v1.2.3 [claude-code] copy
  github.com/owner/repo/-/skills/design v2.0.0 [codex, zed]
)
```

The closed grammar is `require <Repository/Skill ID> <immutable version> [<Agent IDs>] [<symlink|copy>]`. Mode applies to every Agent in that requirement and defaults to `symlink` when omitted. Parsers may accept an explicit `symlink`, but the canonical writer omits the default; it always emits `copy`. A small dedicated parser should own this grammar directly; it does not need to implement Go directives or general-purpose expressions. It must preserve ordinary human comments, reject unknown fields clearly, and produce deterministic machine output. Reuse `x/mod/semver` and `x/mod/module` after parsing for version semantics, but do not retain `modfile` merely for visual familiarity. Since backward compatibility is not required, replace the hybrid parser directly rather than carrying dual parsers indefinitely.

Regardless of syntax, the Manifest boundary must validate:

- canonical Skill or Repository ID through the shared Protocol package;
- canonical immutable semantic or pseudo-version, not merely a URL-safe selector;
- unique and known Agent IDs where portability requires a closed vocabulary;
- serialization of non-default `copy` mode; omitted mode canonically means `symlink` during restore.

### Disposition

- **Copy:** keep Go's declarative, human-readable, machine-writable, deterministic-formatting principles.
- **Adapt:** define the compact SkillsGo-native requirement grammar with first-class ID, version, Agent list, and optional mode; omitted mode means `symlink`.
- **Reject:** do not import Go compilation directives into the SkillsGo Workspace.
- **Reject:** do not encode product semantics in reserved comments or a sidecar, and do not preprocess native fields into fake `go.mod` values.
- **Fix:** stop replacing real versions with `v0.0.0`; validate resolved immutable versions explicitly.
- **Fix:** validate resource IDs at parse and write boundaries with `protocol/skillid`.
- **Implement:** replace the preprocessor plus `modfile` path with one parser for the closed native grammar and conformance tests for single-line/block forms, comments, omitted/explicit modes, and canonical output.
- **Simplify:** remove `SkillRequirement.Source` if it cannot differ from the canonical map key.

### Task 02 review verdict

`skillsgo.mod` currently reuses `modfile` cosmetically while its real domain fields already require a pre-parser and full-file regeneration. The local locking and transaction layer is strong. The correction is not to hide more SkillsGo semantics in comments or introduce a larger configuration language; it is to parse the compact native requirement grammar directly, make non-default `copy` mode portable while omission consistently means `symlink`, and continue reusing Go only for version and integrity primitives. The current immutable-version validation gap remains.

## Task 03 — MVS, replacement, exclusion, upgrade, and downgrade

### Go contract

Minimal version selection (MVS) computes one build list from the main module's requirements and the transitive requirements of selected modules. It chooses the highest required version of each module path. Replacement changes the content used for a module version, exclusion removes a version from consideration, upgrade raises selected versions, and downgrade may lower other modules to retain a consistent graph.

These rules solve dependency-graph consistency for a compiler. They are not general rules for updating independent installed artifacts.

Primary sources:

- [Minimal version selection](https://go.dev/ref/mod#minimal-version-selection)
- [Replacement](https://go.dev/ref/mod#mvs-replace)
- [Exclusion](https://go.dev/ref/mod#mvs-exclude)
- [Upgrades](https://go.dev/ref/mod#mvs-upgrade)
- [Downgrade](https://go.dev/ref/mod#mvs-downgrade)
- [`golang.org/x/mod/mvs`](https://pkg.go.dev/golang.org/x/mod/mvs)

### What SkillsGo should reject for now

SkillsGo currently installs only direct Workspace requirements. Skills do not declare cross-Repository dependencies, and Repository membership is an immutable expansion snapshot rather than a dependency graph. Consequently:

- there is no graph on which MVS could operate;
- two direct Skills at different versions do not constrain one another;
- removal does not require reachability analysis;
- replacement and exclusion would add unexplained semantics without dependency constraints;
- downgrade need not cascade to unrelated Skills.

Implementing MVS today would be premature architecture, not protocol completeness. If Skill dependencies are introduced later, the public `x/mod/mvs` package should be evaluated before implementing graph traversal or upgrade/downgrade selection locally. Even then, SkillsGo must first decide whether its constraints are minimum versions, exact versions, ranges, or policy-driven approvals; MVS is correct only for minimum-version semantics.

### What is correctly adapted

1. **Direct requirements remain independently pinned.** A Workspace Manifest records exact immutable versions; there is no hidden graph lock.
2. **Update planning is target-state-bound.** [`cli/internal/updateplan/update_plan.go`](../../cli/internal/updateplan/update_plan.go) binds a plan to installed identity, Sum, target filesystem state, Workspace declaration, and affected shared bindings before mutation. Go does not solve this projection-safety problem.
3. **Unrelated mutation groups can fail independently.** SkillsGo groups physically shared targets and rolls back within their mutation boundary while allowing unrelated groups to continue. This is appropriate for Agent installations and should not be replaced with whole-Workspace graph atomicity.
4. **Stale Catalog results cannot rewind a valid SemVer installation.** The update decision compares current and candidate versions and retains the newer installed version.
5. **Workspace declaration reconciliation is explicit.** A target already containing the expected artifact can repair stale portable metadata without downloading or replacing content.

### Drift and unfinished policy

1. **`ActionPinned` is dead code.** It is declared, counted, rendered, and skipped during execution, but no branch in `buildItem` assigns it. `sourceReference` computes whether a source reference is fixed and immediately discards the Boolean result. The implementation therefore advertises pin semantics it does not execute.
2. **The documented pin contract and update behavior conflict.** CLI context says a movable selector is resolved to an immutable version and following it again requires an explicit add request. The Update Plan nevertheless sends every installed Skill to Catalog latest, including exact Tags and pseudo-versions. Current tests explicitly expect `v1.0.0` to update to `v1.1.0` and `v1.9.9` to update across the major boundary to `v2.0.0`.
3. **There are at least three update policies.** The explicit Update Plan uses Catalog latest; the older global update path resolves the `main` branch directly; the ordinary Workspace `update` command currently reports unchanged entries without performing resolution. These are product-visible semantic differences, not implementation details.
4. **Major upgrades are automatic without a named policy.** Rejecting Go's `/v2` identity rule is reasonable, but it removes the guard that makes a Go major version a distinct module. SkillsGo must replace that guard with an explicit UX policy. An instruction Skill can change behavior incompatibly at any version, but silently treating every higher major as an ordinary update is still an unreviewed choice.
5. **Catalog update responses are not validated as immutable versions.** The CLI checks that `latestVersion` is non-empty but uses the path-safe `ValidateVersion` contract elsewhere. A malformed or mutable selector can therefore cross the Catalog protocol and become an update target unless the server happens to prevent it.
6. **Fixed-reference recognition reimplements pseudo-version syntax.** `pseudoVersionReference` copies a regex already better represented by `module.IsPseudoVersion`, while commit recognition and Ref classification are mixed into the update planner. This is a small but concrete repeat of the version-wheel problem fixed elsewhere.
7. **Update means are conflated.** "Update to latest published release", "refresh the original branch", "repair declaration metadata", "replace captured content with a Hub artifact", and "explicitly move to a requested version" are different operations but share overlapping paths and actions.

### Recommended policy split

Define selector intent separately from the resolved version:

- **Pinned requirement:** exact Tag, pseudo-version, or commit; ordinary update reports `pinned` and does not move it.
- **Tracking requirement:** explicitly stores a movable source selector such as `main` or `latest` alongside the resolved immutable version; update re-resolves that selector.
- **Release update:** explicitly asks for the newest published release, with a separate major-version approval rule.
- **Exact transition:** explicitly asks for a target immutable version and may upgrade or downgrade after review.
- **Reconcile / repair:** changes no artifact version.

The current Manifest stores only the resolved version, while receipts sometimes retain a source Ref. Neither is a complete portable tracking-intent model. Do not infer long-term intent from `Info.Ref`: it describes how one artifact was resolved, not necessarily what the user wants to follow.

### Disposition

- **Reject now:** MVS, `exclude`, graph-wide replace, and cascading downgrade.
- **Defer:** dependency selection until Skills can declare actual dependencies and a constraint model is chosen.
- **Keep:** state-bound plans, shared-binding validation, per-group compensation, and stale-Catalog downgrade prevention.
- **Fix:** make `ActionPinned` reachable or remove it and correct the documentation; do not retain fictional states.
- **Fix:** converge global, Workspace, and explicit-target update flows on one selector-intent policy.
- **Reuse:** replace pseudo-version regex classification with `x/mod/module` and centralize reference classification outside update orchestration.
- **Design:** require an explicit rule for major release transitions and exact downgrades.

### Task 03 review verdict

Not implementing MVS is correct. The present risk is the opposite: SkillsGo has a sophisticated safe-mutation engine wrapped around an unresolved and internally inconsistent **version-intent policy**. The local execution machinery is valuable; selector intent, pinning, and the meaning of update need consolidation before more graph concepts are added.

## Task 04 — Graph pruning, lazy loading, and artifact materialization

### Go contract

Go graph pruning lets a module record enough transitive requirements to avoid loading every dependency's `go.mod`. Lazy module loading then delays loading module requirements until the imported package graph requires them. The important architectural pattern is not the Go-version-specific pruning algorithm; it is the separation of:

1. cheap resolution metadata;
2. dependency-graph expansion;
3. large source ZIP download;
4. reusable immutable cache state.

Primary sources:

- [Module graph pruning](https://go.dev/ref/mod#graph-pruning)
- [Lazy module loading](https://go.dev/ref/mod#lazy-loading)

### SkillsGo's deliberate adaptation

SkillsGo has no transitive Skill graph to prune. Its corresponding optimization boundary is **Repository metadata versus per-Skill ZIP bytes**:

- Repository Info is the immutable membership snapshot for one Repository version.
- Skill Info is immutable install metadata, source identity, Sum, and archive size.
- Skill ZIP is the large installable payload.
- Catalog discovery is a current projection, separate from historical publication.
- CLI Info cache and Store separate exact metadata from extracted artifact content.

The recently chosen Backfill design deliberately materializes every canonical semantic Tag, scans every valid Skill, calculates every Sum, and initially creates complete ZIPs. Historical ZIPs may later be evicted while immutable metadata remains. This is a valid trade: fingerprint-based Content Match cannot be populated from Tag names or Git tree identities alone, so the first historical ingestion must read full Skill content at least once.

River is an appropriate infrastructure choice for the explicit administrative Backfill. It supplies durable, retryable, at-least-once work and typed job visibility; the Catalog separately owns business status and idempotency. This is not a Go feature and is not duplicated by the module protocol.

### What is currently strong

1. **Demand-driven ordinary publication.** A cold Repository request resolves one immutable snapshot, and stored immutable versions are reused without fetching source again.
2. **One Repository scan per publication.** `DiscoverRepository` synchronizes and walks the commit once, then produces all accepted members. This avoids cloning or scanning once per Skill.
3. **Complete publication commit.** [`hub/cmd/skillsgo-hub/actions/repository_publisher.go`](../../hub/cmd/skillsgo-hub/actions/repository_publisher.go) stores members, calculates assessed metadata, and exposes Repository membership transactionally; partial new artifacts are removed if publication fails.
4. **Historical visibility is explicit.** Catalog history does not automatically reintroduce removed Skills into current discovery and ranking.
5. **Backfill is incremental and conflict-aware.** Existing exact publications are skipped only after Tag-to-commit comparison; version conflicts are surfaced rather than overwritten.
6. **Concurrent work is bounded.** Process singleflight, an upstream capacity semaphore, River uniqueness, and transaction-scoped submission address different concurrency scopes.

### Materialization drift blocking ZIP eviction

The intended "retain metadata, evict cold historical ZIPs, restore on access" lifecycle is **not implemented yet**, and the current read pipeline prevents it in several ways:

1. **Enriched Info depends on live ZIP bytes on every read.** [`catalogProtocol.Info`](../../hub/cmd/skillsgo-hub/actions/catalog_protocol.go) reads stored base Info, opens the ZIP, parses `SKILL.md`, recalculates Sum / Risk, and only then returns enriched Skill Info. Catalog existence is checked after enrichment and only suppresses duplicate indexing. Therefore metadata-only historical entries cannot currently serve Skill Info or Repository Info.
2. **The exact enriched Info document is not persisted.** Catalog stores name, description, version identity, Sum, and archive size, but not the complete frontmatter projection (`license`, `compatibility`, `allowedTools`, arbitrary metadata) nor exact assessed Info bytes. An evicted ZIP leaves insufficient state to reproduce the current wire document.
3. **Repository Info transitively reopens every member ZIP.** Building a Repository Info response calls the per-Skill Info path for each member, so a metadata request scales with total member content and repeated hash/audit work.
4. **Storage existence is a compound and inconsistent concept.** Filesystem, S3, GCS, Azure, and MinIO `Exists` generally require both Info and ZIP. Mongo checks only its metadata document, while the generic fallback checks only Info. A future Info-present / ZIP-absent state would therefore be interpreted differently by backend.
5. **Deletion is all-or-nothing.** The common `storage.Deleter` and artifact helper delete Info and ZIP together. There is no `DeleteZIP`, artifact-state enum, or cold-object transition.
6. **No access evidence exists.** Catalog versions do not record last artifact access, request count, restoration state, or an eviction lease. A periodic cleanup worker cannot yet make a safe, race-free coldness decision.
7. **Restoration is not a first-class operation.** A ZIP miss falls into inherited stash behavior. Depending on backend `Exists` semantics, it may refetch or may incorrectly declare the version present and return another ZIP miss. There is no durable restore job, single artifact-state transition, or response policy while restoration is running.

### Over-materialization that should be explicit

A request for one nested Skill currently calls Repository publication and builds ZIPs for every Skill in that Repository snapshot. This matches the selected "full pull during add/publication" strategy and enables complete Repository Info plus matching metadata. It should be documented as a product decision because it differs from Go's package-driven lazy source download and can be expensive for large multi-Skill repositories.

Backfill multiplies that cost by every canonical Tag. The design remains reasonable only with:

- per-Repository and source-host concurrency limits;
- bounded Repository / artifact sizes;
- resumable per-version results;
- a later ZIP lifecycle that actually reduces retained bytes;
- observability for fetched bytes, generated artifacts, reuse, eviction, and restoration.

### Required seam before eviction

Introduce a storage and metadata distinction such as:

```text
Publication metadata: immutable and always resident
Artifact state: present | restoring | evicted | unavailable
Artifact object: independently readable / writable / deletable ZIP
```

Persist either the exact enriched Skill Info bytes or every canonical field needed to reconstruct them without opening the ZIP. Then:

1. Info and Repository Info reads use resident metadata only.
2. ZIP reads check artifact state.
3. An evicted read performs or enqueues exact-version restoration with singleflight / River deduplication.
4. Restored bytes are verified against the already persisted Sum before publication.
5. Eviction uses recorded access and an atomic state/lease so it cannot race an active download or restore.
6. `DeleteZIP` never deletes publication metadata, Sum, or Repository membership.

### Disposition

- **Reject:** do not copy Go graph-pruning algorithms while SkillsGo has no dependency graph.
- **Adapt:** preserve metadata-first resolution and defer large ZIP transfer where product requirements allow it.
- **Keep:** full first-pass Backfill materialization because complete fingerprint coverage requires content.
- **Fix before eviction:** persist enriched Info independently of ZIP and split storage existence / deletion by resource kind.
- **Add later:** access tracking, eviction policy, durable restoration, artifact-state reconciliation, and source-host concurrency controls.
- **Remove repeated work:** do not re-parse and re-hash unchanged ZIPs on every Info request.

### Task 04 review verdict

The high-level full-pull-then-evict strategy is coherent and balances fingerprint coverage with long-term storage cost. The current implementation, however, still treats Info and ZIP as one inseparable cache entry and recomputes Info from ZIP on every read. **ZIP eviction is not a cleanup job away; it first requires a deeper storage/read-model seam.** This is the most important architectural prerequisite found so far.

## Task 05 — Go workspaces versus SkillsGo scopes

### Go contract

A Go workspace uses `go.work` to make multiple main modules participate in one build. `use` selects local module directories, workspace-level `replace` applies across them, and `go work sync` updates their build lists according to the workspace build list. A `go.work` file is therefore a **multi-module build-composition override**, not a generic list of filesystem projects.

Primary sources:

- [Workspaces](https://go.dev/ref/mod#workspaces)
- [`go.work` files](https://go.dev/ref/mod#go-work-file)
- [`use` directive](https://go.dev/ref/mod#go-work-file-use)
- [`replace` directive](https://go.dev/ref/mod#go-work-file-replace)
- [`go work init`](https://go.dev/ref/mod#go-work-init)
- [`go work use`](https://go.dev/ref/mod#go-work-use)
- [`go work sync`](https://go.dev/ref/mod#go-work-sync)

### The terms are false friends

SkillsGo's Workspace is an installation and declaration scope rooted at a user-selected directory. It is not composed with other Workspaces for resolution. Each Workspace has independent desired Agent bindings and can install a different version of the same Skill. The User Declaration Root is another independent scope, not a main module in a larger build.

Consequently, adding a product `skillsgo.work` because Go has `go.work` would be incorrect. It would imply a combined resolution graph and shared overrides that SkillsGo does not have.

### What is correctly adapted

1. **Nearest-root discovery.** [`project.FindRoot`](../../cli/internal/project/files.go) walks ancestors and selects the nearest `skillsgo.mod`, mirroring the useful locality rule of Go module discovery without importing build semantics.
2. **Independent declarations.** Project Workspaces and `~/.skillsgo` each own a Manifest and Workspace Sum. One scope does not silently override another.
3. **Shared immutable cache, separate intent.** All scopes share the CLI Store and Info cache, while their Manifests and Installation Receipts remain separate. This is analogous to multiple Go modules sharing `GOMODCACHE`, not to a `go.work` build list.
4. **Explicit multi-scope operations.** Library and Batch Takeover operations accept User and one or more Workspace scopes explicitly, then preserve per-scope result and mutation boundaries. They do not create a synthetic combined declaration.
5. **Offline restore is per Workspace.** `skillsgo install` resolves the nearest Manifest, verifies its own Sum, and reconstructs only that scope's targets.

### Gaps and naming risks

1. **The CLI `use` command is only a placeholder.** Its usage text (`use <package>@<skill>`) does not match Go workspace `use`, and no domain contract defines what it will own. Leaving a Go-loaded command name without semantics invites accidental imitation.
2. **Added Projects are App state, not portable resolution state.** That is reasonable for navigation, but documentation must not imply that the set is equivalent to a checked-in `go.work` file.
3. **Cross-scope inventory can look like composition.** A unified Library view aggregates entries for presentation, while source-of-truth state remains per scope. Every bulk plan must continue carrying explicit scope and exact target identity so the UI aggregation never becomes an implicit mutation boundary.
4. **Nearest-root behavior needs a nested-Workspace contract.** The implementation deterministically chooses the nearest Manifest, but the product documentation should state whether a nested `skillsgo.mod` intentionally shadows the parent for commands invoked below it.
5. **User Scope should not be renamed Workspace.** The current domain already distinguishes User Declaration Root from Workspace Scope. Preserving that distinction prevents a future combined-workspace abstraction from being smuggled into local state.

### Disposition

- **Reject:** do not add `skillsgo.work`, workspace-level replace, or `sync` semantics without a real cross-Workspace resolution requirement.
- **Copy:** retain nearest-Manifest discovery and shared immutable cache reuse.
- **Keep:** per-scope Manifest, Sum, receipts, mutation transactions, and independently reportable failures.
- **Define or remove:** give `skillsgo use` a SkillsGo-native contract before implementation, or remove the placeholder.
- **Document:** make nested Workspace shadowing and App Added Project ownership explicit.

### Task 05 review verdict

SkillsGo's current scope model is cleaner than copying Go workspaces. The implementation correctly shares immutable bytes without combining portable intent. The main concern is terminology: `Workspace`, App Added Projects, and the placeholder `use` command could easily drift toward a `go.work` analogy that does not match the product.

## Task 06 — Non-module repositories and `+incompatible`

### Go contract

Go supports repositories that predate modules. It may synthesize a minimal `go.mod`, use `+incompatible` versions for some `v2+` releases without a matching major-version module path, and apply minimal-module-compatibility rules for old GOPATH import layouts. These are migration mechanisms for the Go ecosystem's transition from GOPATH to modules.

Primary sources:

- [Compatibility with non-module repositories](https://go.dev/ref/mod#non-module-compat)
- [`+incompatible` versions](https://go.dev/ref/mod#incompatible-versions)
- [Minimal module compatibility](https://go.dev/ref/mod#minimal-module-compatibility)

### SkillsGo mapping

A Git Repository without semantic Tags is not an unsupported legacy source. SkillsGo resolves its default branch or requested commit to a pseudo-version and can publish valid `SKILL.md` directories normally. A Repository without a valid `SKILL.md` is simply not a Skill source.

This distinction means SkillsGo needs untagged-source support but does not need Go's non-module compatibility layer:

- no synthetic `SKILL.md` should be invented;
- no GOPATH import rewriting exists;
- no major-version path migration exists;
- no `+incompatible` marker has domain meaning.

### What is correctly adapted

1. **Untagged repositories receive immutable pseudo-versions.** The default branch remains a movable query, while the published artifact records a commit-derived version.
2. **The first semantic Tag naturally supersedes default `latest`.** A previously published untagged commit remains exactly addressable, while stable-first selection prefers the new release.
3. **Backfill enumerates semantic Tags only.** It does not pretend that every historical commit is a release. Untagged commits become available only through actual demand or explicit revision resolution.
4. **Missing or invalid manifests fail closed.** Repository discovery skips invalid candidates and rejects a snapshot with no installable Skill rather than synthesizing content.

### Inherited residue

1. **`+incompatible` remains in copied pseudo-version regexes.** Both Hub list filtering and CLI update classification accept the suffix even though SkillsGo deliberately removed the major-path rule that gives it meaning.
2. **Exact version validation is broad enough to admit it.** `source.ValidateVersion` checks URL-path safety, not the resolved-version grammar. An exact `+incompatible` pseudo-version can reach Hub resolution even though Tag listing and generated versions do not use the suffix.
3. **Comments still describe legacy Go compatibility.** Tests and implementation comments refer to Go legacy list behavior or copied `cmd/go` regexes, preserving a migration concern that SkillsGo never adopted.

### Disposition

- **Copy:** keep Go pseudo-version format for untagged immutable Git revisions.
- **Reject:** synthetic manifests, minimal module compatibility, and `+incompatible` semantics.
- **Fix:** define a SkillsGo immutable-version validator that accepts canonical SemVer and canonical pseudo-versions but rejects `+incompatible` explicitly.
- **Remove:** eliminate `+incompatible` branches from local regexes; preferably eliminate the regexes in favor of `x/mod/module`.
- **Document:** untagged Repository support is a first-class source mode, not a legacy compatibility promise.

### Task 06 review verdict

SkillsGo already has the right untagged-source behavior. The remaining Go migration artifacts are small but misleading: `+incompatible` is accepted by inherited classifiers despite having no SkillsGo meaning. This should be removed rather than documented as compatibility.

## Task 07 — Module-aware commands and CLI lifecycle

### Go contract

The Go reference documents commands that consume or mutate module state. Their behavior is useful as a lifecycle checklist, but their names do not define SkillsGo behavior. Go commands primarily build source code and maintain a dependency graph; SkillsGo commands resolve immutable Skills and project them into Agent discovery roots.

Primary source: [Module-aware commands](https://go.dev/ref/mod#mod-commands), including each command-specific anchor linked below.

### Complete command disposition

| Go command / section | Closest SkillsGo surface | Disposition |
| --- | --- | --- |
| [Build commands](https://go.dev/ref/mod#build-commands) | Agent runtime consumes installed Skills | Reject. SkillsGo does not compile or execute Skill instructions as a build graph. |
| [Vendoring](https://go.dev/ref/mod#vendoring) | Scope-local canonical copy and Agent projections | Reject the analogy. Installation is deployment, not a fallback dependency source tree. |
| [`go get`](https://go.dev/ref/mod#go-get) | `skillsgo add` | Adapt. Resolve user intent, persist an immutable requirement, verify content, and deploy targets. |
| [`go install`](https://go.dev/ref/mod#go-install) | `skillsgo install` | Name overlap only. SkillsGo restores one Manifest; it does not install an executable selected independently of module state. |
| [`go tool`](https://go.dev/ref/mod#go-tool) | None | Reject until SkillsGo owns executable tool dependencies, which it currently should not. |
| [`go list -m`](https://go.dev/ref/mod#go-list-m) | `skillsgo list`, `inventory`, `info`, machine JSON | Adapt only the read-only introspection principle. Do not copy module-graph fields. |
| [`go mod download`](https://go.dev/ref/mod#go-mod-download) | No cache-only public command | Defer. A future `fetch` / `cache warm` command may support CI or offline preparation without Agent mutation. |
| [`go mod edit`](https://go.dev/ref/mod#go-mod-edit) | No low-level Manifest editor | Reject for now. High-level state-bound operations are safer than unvalidated field edits. |
| [`go mod graph`](https://go.dev/ref/mod#go-mod-graph) | None | Reject until a real dependency graph exists. |
| [`go mod init`](https://go.dev/ref/mod#go-mod-init) | Placeholder `skillsgo init` | Define narrowly or remove. Creating an empty Workspace Manifest is useful; inventing package identity is not. |
| [`go mod tidy`](https://go.dev/ref/mod#go-mod-tidy) | Inventory / reconciliation concepts | Reject automatic inference. Agent directories and receipts cannot safely decide portable desired state. |
| [`go mod vendor`](https://go.dev/ref/mod#go-mod-vendor) | Copy-mode installation | Reject the analogy. Copy mode is an explicit projection mode with receipts, not a generated dependency snapshot. |
| [`go mod verify`](https://go.dev/ref/mod#go-mod-verify) | Automatic Store Sum checks and inventory health | Adapt. Verification exists as a behavior but lacks one explicit read-only command over a selected scope. |
| [`go mod why`](https://go.dev/ref/mod#go-mod-why) | Source / target provenance in receipts | Defer graph paths; consider a non-graph `skillsgo why <target>` that explains declaration → artifact → target provenance. |
| [`go version -m`](https://go.dev/ref/mod#go-version-m) | `skillsgo info`, receipt inspection | Reject binary build-info semantics; retain artifact provenance introspection. |
| [`go clean -modcache`](https://go.dev/ref/mod#go-clean-modcache) | Future Store garbage collection | Adapt carefully. Store cleanup must protect referenced artifacts and recovery state; blind cache deletion is not equivalent. |
| [Commands outside a module](https://go.dev/ref/mod#commands-outside) | Global commands and `add` in a new directory | Keep an explicit matrix: product reads and User operations need no Manifest; project restore does. |

### What is currently strong

1. **`add` crosses one high-level transaction seam.** It resolves Repository Info, verifies member Sums, authorizes risk, prepares target conflicts, populates Store, installs projections, and persists scope state.
2. **`install` restores exact immutable state.** It can use cached exact Info and Store artifacts offline or refill missing Store content from Hub while verifying Workspace Sum evidence.
3. **Read and mutation commands are separated.** `info`, `discover`, `detail`, `inventory`, and diagnostics do not implicitly mutate targets.
4. **Repair and remove are exact-target operations.** They use reviewed state tokens and Installation Receipts instead of name-only directory mutation.
5. **Integrity is enforced continuously.** Store reads verify directory Sum; installation persistence verifies target content; Hub downloads verify declared Sum. A standalone `verify` would expose existing behavior rather than add a new trust model.

### Drift and inherited CLI residue

1. **Unimplemented commands are registered as public commands.** `use`, `find`, and `init` appear in help but only return "not implemented". This advertises surface area without a contract and encourages accidental Go or skills.sh imitation.
2. **Ordinary `add` accepts no-op flags.** `--list`, `--metadata`, and `--full-depth` are registered and rejected only by the explicit-target path; the ordinary Repository path reads none of them and silently continues. These appear to be skills.sh compatibility residue and should not remain inert public promises.
3. **`install` is semantically non-obvious.** It restores the nearest Workspace Manifest, while many package ecosystems use `install <source>` for add. The behavior itself is good, but help and documentation must emphasize restore / reconcile semantics.
4. **Verification has no complete user seam.** Diagnostics reports whether the Store directory is initialized/readable, not whether every Store entry, Workspace Sum, Info cache entry, receipt, and target is valid. Inventory computes health for managed targets but is not an explicit integrity audit with a stable summary.
5. **Store cleanup has no reference model.** A future cleanup command must trace every User / Workspace Manifest, Info cache dependency, Store receipt, and active target before deleting bytes. Go's cache can be fully regenerated from module sources; SkillsGo also carries Local and captured provenance that may not be remotely recoverable.
6. **Whole-Repository add mutates targets before one final Manifest write.** Sums are persisted early, but member installations occur sequentially and the direct Repository requirement is written afterward. A later member or Manifest failure can leave partially installed targets. This differs from the File Contract's "atomic-preflight" wording and deserves a dedicated installation-transaction review.

### Recommended command model

- `add`: resolve a source selector, review, install, and persist exact intent.
- `install`: restore / reconcile the current Manifest exactly.
- `update`: apply the unified selector-intent policy from Task 03.
- `verify`: read-only integrity audit across Manifest, Sum, Info cache, Store, receipts, and targets.
- `gc`: reference-aware cleanup with dry-run; never delete Local / captured content merely because Hub can usually restore public artifacts.
- `info` / `list` / `inventory` / future `why`: provenance and state introspection.
- `init`: only if it creates a minimal empty scope declaration and explains nearest-root behavior.

### Disposition

- **Copy:** preserve high-level separation between declaration mutation, download/cache, verification, and cleanup.
- **Adapt:** expose SkillsGo-native `verify`, `gc`, and provenance reads rather than copying Go output schemas.
- **Remove:** unregister placeholders and silent no-op flags until they have implemented contracts.
- **Review separately:** make whole-Repository add failure atomic or accurately document partial success and recovery.
- **Reject:** build, tool, vendor, graph, tidy, and binary-inspection semantics.

### Task 07 review verdict

The core add / restore / target-management lifecycle is richer than Go's because it must own filesystem projection and user review. The avoidable problems are public residue and misleading names: inert flags, placeholders, and an incomplete verification surface. Go is most useful here as a command-responsibility checklist, not as a CLI to clone.

## Task 08 — Version queries and selector grammar

### Go contract

Go version queries are a closed grammar:

- an exact semantic version;
- a semantic prefix such as `v1` or `v1.2`;
- a comparison such as `<v1.2.3` or `>=v1.5.6`;
- a VCS revision, Tag, branch, or commit;
- `latest`;
- context-dependent `upgrade` and `patch`.

Non-exact queries select from tagged versions, omit pseudo-versions, honor exclusions and retractions, and prefer releases over prereleases. A semantic-looking name is interpreted as a version query rather than a branch.

Primary source: [Version queries](https://go.dev/ref/mod#version-queries).

### What SkillsGo actually supports

| Query class | Current behavior | Verdict |
| --- | --- | --- |
| `latest` | Stable-first Tag; then prerelease; then default-branch pseudo-version | Correct Go behavior, but overloaded for the SkillsGo ecosystem. |
| Exact canonical SemVer | Resolves exact Tag | Correctly copied, without major-path rule. |
| Exact pseudo-version | Resolves commit suffix and validates authenticity | Correctly copied. |
| Branch name | Resolves refreshed remote-tracking branch to a pseudo-version or pointed-at canonical Tag | Useful adaptation. |
| Commit hash / prefix | Resolves Git revision and emits canonical Tag or pseudo-version | Useful adaptation. |
| Non-SemVer Tag | May resolve through Git's generic revision rules | Supported implicitly, with ambiguity risk. |
| `v1`, `v1.2` | Not implemented as semantic prefixes; may be treated as branch-like revisions | Drift. |
| `<`, `<=`, `>`, `>=` | Not implemented; may pass URL-safety validation and fail later as Git revisions | Drift. |
| `upgrade`, `patch` | Not implemented; may be treated as branch names | Drift. |
| npm range such as `^1.0.8` | Explicitly accepted by a source-parser test but not resolved by Hub | Broken inherited promise. |

### What is correctly copied

1. **A query is not persisted as the artifact version.** Branches and commits resolve to canonical immutable versions before publication.
2. **Semantic-looking branches cannot masquerade as exact Tags.** Canonical semantic inputs are resolved through the semantic Tag ref, and a same-named branch is rejected if the Tag is absent.
3. **Current `latest` selection has direct executable matrices.** Tests cover no-Tag timelines, Tag transitions, prerelease preference, movable branch freshness, and old exact pseudo-version stability. These tests are valuable evidence even though the public contract should split head freshness from release selection.
4. **HTTP path escaping uses `x/mod/module`.** The CLI uses `EscapePath` and `EscapeVersion` for `/mod` requests rather than custom URL escaping.

### Drift and duplication

1. **`ValidateVersion` validates transport safety, not selector support.** It accepts any non-empty path segment. The name is therefore misleading and allows unsupported query languages to cross the CLI boundary.
2. **The test suite promises npm syntax.** `TestParseCanonicalSkillWithVersionSelector` requires `^1.0.8` to parse successfully, but neither the Hub nor shared Protocol implements npm range selection. This is a concrete compatibility test that guarantees later failure.
3. **Semantic prefixes are ambiguous.** `semver.IsValid("v1")` is true, but SkillsGo's canonical-Tag check rejects it and falls through to revision resolution. Go would select the highest `v1` release; SkillsGo may resolve a branch named `v1` or fail.
4. **CLI exactness checks encode another grammar.** `validateAssessedInfo` treats any request starting with `v` as exact and requires the returned version to equal it. That makes future `v1` prefix support impossible without changing the client, even if Hub adds it.
5. **Non-SemVer Tag versus branch precedence is accidental.** The resolver prefers `refs/remotes/origin/<query>` when it exists, then falls back to Git's generic revision lookup. A branch and Tag with the same non-semantic name do not have an explicit public disambiguation rule.
6. **Selector parsing, immutable-version validation, HTTP escaping, VCS resolution, and update reference classification use different validators.** This is why unsupported ranges pass one layer and fail another.

### Recommended selector contract

Define shared Protocol types instead of one overloaded string validator:

```text
Selector:
  head
  release
  exact canonical SemVer
  exact canonical pseudo-version
  explicit branch:<name>
  explicit tag:<name>
  explicit commit:<hex-prefix>

ImmutableVersion:
  canonical SemVer or canonical pseudo-version only
```

`head` resolves the refreshed default branch and is the ordinary add/update candidate. `release` uses stable-first canonical Tag selection. The explicit VCS prefixes are a SkillsGo adaptation, not required to match Go syntax. They remove branch / Tag ambiguity and let the Hub validate before invoking Git. Existing friendly inputs such as GitHub tree URLs may normalize to `branch:<name>` internally.

Update availability is a separate read model. It should return both head and release candidates plus their freshness/source status, deduplicated by Repository. It must not claim to have checked upstream when it only read a previously published Catalog version.

Semantic prefixes, comparisons, `patch`, `upgrade`, npm ranges, and arbitrary SemVer constraints should be rejected until an actual selection contract, retraction behavior, and tests exist. If range selection is later desired, choose one language deliberately; do not simultaneously imply Go queries and npm ranges.

### Disposition

- **Copy:** exact versions, authentic pseudo-versions, and stable-first ordering inside the release channel.
- **Adapt:** make default-branch `head` and Tag-based `release` distinct; retain branch, Tag, and commit selection with explicit kinds.
- **Reject now:** semantic prefixes, comparisons, `patch`, `upgrade`, and npm ranges.
- **Fix:** split selector validation from immutable-version validation in the shared Protocol workspace.
- **Remove:** delete the `^1.0.8` acceptance test unless range resolution is implemented end to end.
- **Fix:** make the CLI's response exactness check depend on parsed selector kind, not `strings.HasPrefix("v")`.
- **Fix:** make update checking refresh/freshness-cache Repository source state and return head/release candidates instead of only Catalog `latest_version`.

### Task 08 review verdict

The resolver's immutable Git behavior is well tested, but its public input grammar is not. SkillsGo currently accepts a superset of strings and implements only a subset, including an explicit npm-range test with no resolver. A closed, typed selector contract will remove several downstream special cases and prevent future protocol drift.

## Task 09 — `GOPROXY` protocol endpoints

### Official contract

The [Go Modules Reference — `GOPROXY` protocol](https://go.dev/ref/mod#goproxy-protocol) defines a static-file-compatible HTTP namespace with five resources:

| Resource | Required behavior |
| --- | --- |
| `$module/@v/list` | Plain text canonical versions, one per line, excluding pseudo-versions |
| `$module/@v/$version.info` | JSON with canonical `Version` and optional RFC 3339 `Time` |
| `$module/@v/$version.mod` | Original `go.mod`, or a synthesized minimal module declaration |
| `$module/@v/$version.zip` | Immutable, canonically structured module ZIP |
| `$module/@latest` | Optional Info-shaped fallback when the list has no suitable version |

Module path and version path elements use the same case encoding: an uppercase letter becomes `!` followed by its lowercase form. A successful response is `200`; clients follow redirects; `404` and `410` mean that another proxy may have the resource. Error bodies should be UTF-8 or US-ASCII `text/plain`. Successful `.mod` and `.zip` responses must be immutable.

### SkillsGo implementation

`hub/pkg/download/handler.go` registers the artifact surface under `/mod`:

- `/mod/{coordinate}/@v/list`
- `/mod/{coordinate}/@latest`
- `/mod/{coordinate}/@v/{version}.info`
- `/mod/{coordinate}/@v/{version}.zip`, including `HEAD`

This matches ADR 0004. The missing `.mod` endpoint is deliberate: a Repository release has no dependency manifest consumed by the installer, and Repository Info carries the release/member metadata that SkillsGo actually needs. The extra `/-/` segment distinguishes a Repository coordinate from one of its Skills. It is valid inside SkillsGo's namespace but makes the wire protocol intentionally different from a Go proxy.

The CLI correctly constructs paths with `golang.org/x/mod/module.EscapePath` and `EscapeVersion`. The Hub independently copied cmd/go's decoder into `hub/pkg/paths/decode.go`, but that decoder only reverses case encoding. It does not perform the full validation provided by `module.UnescapePath` and `module.UnescapeVersion`. This is both duplicated protocol code and a weaker server boundary.

`InfoHandler` returns assessed Skill or Repository metadata rather than Go's two-field Info document. That is a valid SkillsGo adaptation because the CLI is the only supported protocol client, but comments claiming the package “serves up cmd/go's download protocol” and “mirrors” cmd/go are inaccurate. A real `go` client cannot use this endpoint because `.mod` is absent and Skill ZIPs have different content semantics.

### HTTP and cache behavior

The current boundary gets several important details right:

- movable selectors such as branches and commit prefixes receive `Cache-Control: no-cache, no-store, must-revalidate` on Info and ZIP responses;
- canonical versions may redirect to an external immutable artifact origin;
- ZIP supports `GET` and `HEAD`, sets `application/zip`, and includes `Content-Length` when known;
- list and latest are explicitly non-cacheable, preventing a stale discovery result from becoming immutable accidentally;
- canonical SemVer and pseudo-version Info responses are not marked non-cacheable.

There are four concrete deviations:

1. `ListHandler` declares `application/json; charset=utf-8` but sends newline-delimited plain text. It must use `text/plain; charset=utf-8`.
2. `LatestHandler` initially declares `text/plain` and then calls Fiber's JSON encoder. The final framework behavior should not be relied on implicitly; the handler should declare and test `application/json` directly.
3. Most handler errors use `SendStatus`, producing framework-owned bodies and content types. The public protocol has no centralized guarantee that every 4xx/5xx body is UTF-8 `text/plain`, and `410 Gone` is not represented in the Hub error kinds.
4. Immutable canonical Info/ZIP responses have no explicit cache policy, ETag, or conditional request handling. This does not violate Go's minimum protocol, but it leaves CDN/browser efficiency and byte-identity validation implicit. Immutable resources should be served with a long-lived `public, max-age=..., immutable` policy once artifact restoration/eviction semantics can preserve availability.

The implementation also registers `list` with `Router.All`, so POST, PUT, and other methods invoke a read endpoint. The Go contract specifies `GET`; SkillsGo should register `GET` (and optionally `HEAD` where useful) and let unsupported methods return `405`/`404` consistently.

### Recommended contract

Treat `/mod` as a **Go-proxy-shaped SkillsGo artifact protocol**, not as a Go proxy implementation:

```text
GET  /mod/{escaped-coordinate}/@v/list
GET  /mod/{escaped-coordinate}/@latest
GET  /mod/{escaped-coordinate}/@v/{escaped-selector}.info
GET  /mod/{escaped-coordinate}/@v/{escaped-selector}.zip
HEAD /mod/{escaped-coordinate}/@v/{escaped-selector}.zip
```

The request may contain a movable selector, but every successful Info response must name an immutable canonical version. Requests that already name a canonical immutable version must return that exact version. Canonical Info and ZIP bytes must remain stable forever; a deleted local ZIP may be restored, but the endpoint must never silently generate different bytes for the same coordinate and version.

Use `x/mod/module` on both client and server for escaping, unescaping, and validation. Keep Repository and Skill Info extensions, the `/mod` namespace, `/-/`, external artifact redirects, and HEAD. Do not add a meaningless `.mod` endpoint merely for surface symmetry.

### Disposition

- **Copy:** case-safe path/version escaping, newline list shape, canonical Info resolution, immutable version resources, status-code semantics, and redirect support.
- **Adapt:** keep `/mod`, `/-/`, enriched Info, ZIP HEAD, and external immutable artifact redirects.
- **Reject:** do not synthesize `.mod`; do not claim cmd/go client compatibility.
- **Replace duplicated code:** remove the copied `DecodePath` implementation in favor of `module.UnescapePath` and `module.UnescapeVersion` at the correct parsing positions.
- **Fix:** correct list/latest content types, restrict list to GET, normalize text error responses, and model `410 Gone` if multi-origin fallback will use it.
- **Improve later:** explicit immutable cache headers, ETag/conditional GET, and restoration-aware availability tests.

### Task 09 review verdict

The endpoint set is an appropriate adaptation, not a faulty partial Go proxy. Its main design problem is inaccurate compatibility language; its immediate implementation defects are duplicated/weaker decoding, a wrong list media type, an overly broad list method, and underspecified HTTP error/cache semantics. These can be corrected without adding `.mod` or changing the Repository/Skill model.

## Task 10 — Proxy communication and fallback

### Official contract

The [Go Modules Reference — communicating with proxies](https://go.dev/ref/mod#communicating-with-proxies) separates three concerns:

1. consult the local module cache before making a network request;
2. use an ordered `GOPROXY` source list, with `direct` and `off` as explicit policies;
3. choose fallback semantics with separators: comma falls through only on `404`/`410`, while pipe falls through on any error.

This distinction lets an organization use a proxy as a gatekeeper: `403` stops comma-based fallback, while `404`/`410` allow another source. Go separately verifies downloaded immutable `.mod` and `.zip` bytes; unauthenticated version lists and Info metadata are discovery inputs, not content-integrity evidence.

### SkillsGo communication topology

The CLI has one Hub origin selected by `--hub` or `SKILLSGO_HUB_URL`. It does not implement an ordered Hub list, `direct`, `off`, comma/pipe fallback, automatic retries, or `Retry-After`. Its default `http.Client` follows redirects and applies a five-minute whole-request timeout. Every non-`200` response becomes `HTTPError`; the machine boundary classifies timeouts, `429`, `502`, `503`, `504`, and generic 5xx, but does not preserve `404` versus `410` as source-selection signals.

Keeping one Hub is currently the right adaptation. The Hub is not merely a byte mirror: it resolves selectors, assesses Risk, publishes Sum and Repository membership, and feeds product metadata. Direct CLI-to-VCS fallback would bypass those authority and assessment boundaries. Copying `GOPROXY`'s full source-list language now would add policy complexity without a second equivalent trust origin.

Offline restoration is instead provided locally by the CLI's Store plus immutable Info cache and `skillsgo.sum`. That is the correct equivalent of Go's cache-first behavior for already-resolved Workspace state. New selection and uncached installation still require the configured Hub, which is an honest limitation rather than a protocol defect.

### Hub-side policy matrix

The Hub contains two inherited Athens policy systems:

- `DownloadMode`: `sync`, `async`, `redirect`, `async_redirect`, `none`, optionally selected per coordinate with HCL;
- `NetworkMode`: `strict`, `offline`, or `fallback`.

`NetworkMode` only governs `List` and `Latest`. It does **not** govern `Info` or `Zip` cache misses: `protocol.processDownload` ignores it and may synchronously invoke the source stasher or enqueue work even when `SKILLSGO_HUB_NETWORK_MODE=offline`. Existing tests only prove that the upstream lister is not called by `List` in offline mode. There is no test proving that all source access is disabled. Consequently, “offline” is a misleading and unsafe policy name.

The two axes also produce a large state matrix whose combinations are not all meaningful. For example, `NetworkMode=offline` plus `DownloadMode=sync` serves list data from storage but fetches a directly requested missing Info/ZIP from VCS. `fallback` controls only whether a failed upstream list can be replaced with the stored list; it is unrelated to proxy-origin fallback and can return discovery results whose completeness varies with upstream health.

One additional resource issue is hidden in `processDownload`: it always replaces the request context with a background-derived fifteen-minute context, including synchronous downloads. A client cancellation therefore does not cancel a synchronous upstream materialization. Detached context is appropriate for durable async dispatch, not automatically for request-bound sync work.

### Recommended policy model

Keep the CLI on one authoritative Hub for now. On the Hub, separate policy by what it actually controls:

```text
SourceAccessPolicy: online | offline
DiscoveryPolicy:    require-upstream | storage-on-upstream-error
ArtifactMissPolicy: materialize-sync | enqueue | redirect | not-found
```

`SourceAccessPolicy=offline` must be a top-level invariant: no VCS listing, clone/fetch, materialization, or enqueue that can later contact VCS. `DiscoveryPolicy` only describes list completeness while online. `ArtifactMissPolicy` describes the response to a missing immutable artifact and may remain coordinate-specific. Validate invalid or contradictory combinations at startup rather than permitting accidental behavior.

For the CLI, add bounded retries only for idempotent reads and only for transport errors, `408`, `429`, `502`, `503`, and `504`; honor `Retry-After`, use jittered backoff, and keep attempts within the caller's deadline. Do not retry malformed protocol responses or most 4xx errors. Preserve typed status and request ID in machine output.

If multiple Hub origins are added later, do not expose raw `GOPROXY` syntax. Define an ordered `HubOrigin` policy with explicit trust and fallback:

- `404`/`410`: artifact absent, another trusted origin may be consulted;
- `401`/`403`: policy/authentication failure, stop;
- `429`/5xx/transport failure: retry or fail over only when configuration explicitly permits availability fallback;
- successful immutable bytes: require the same expected Sum regardless of origin.

This preserves Go's valuable fallback distinction without pretending that arbitrary Hubs are interchangeable.

### Disposition

- **Copy:** cache-first immutable reads, typed `404`/`410` absence, gatekeeper semantics for `401`/`403`, redirect following, and checksum verification across origins.
- **Adapt:** keep one authoritative Hub and local offline restore; add typed trusted-origin fallback only when a real mirror use case exists.
- **Reject now:** CLI direct-to-VCS fallback and raw `GOPROXY` comma/pipe configuration.
- **Fix immediately:** make Hub offline mode prohibit every upstream side effect, not just List/Latest calls.
- **Refactor:** replace the ambiguous two-dimensional Athens mode matrix with explicit source-access, discovery, and artifact-miss policies.
- **Improve:** bounded idempotent retries with `Retry-After`; retain request cancellation for synchronous materialization.

### Task 10 review verdict

The CLI's single-Hub topology is simpler and safer than copying `GOPROXY` wholesale. The serious drift is inside the Hub: a configuration named `offline` still permits Info/ZIP misses to reach upstream. The inherited Athens policy matrix should be reduced to explicit orthogonal policies before ZIP eviction, restoration, or private-source routing adds more states.

## Task 11 — Serving directly from a proxy and immutable publication

### Official contract

The [Go Modules Reference — serving modules directly from a proxy](https://go.dev/ref/mod#serving-from-proxy) allows a module path owner to return a `go-import` meta tag whose VCS kind is `mod`. The tag redirects cmd/go from vanity-path discovery to a GOPROXY-compatible origin. This hides the underlying VCS and can front unsupported source-control systems. It is a discovery indirection, not a publication transaction specification.

SkillsGo does not need to copy `?go-get=1` or `go-import ... mod ...`. Repository IDs are parsed by the SkillsGo source boundary and the CLI already knows its configured Hub. Adding an HTML discovery protocol would create a second Hub-discovery authority without enabling a current use case.

The useful idea to copy is architectural: clients consume stable, immutable proxy resources without learning source credentials or VCS details. SkillsGo's Hub already plays that role and should make publication correctness an explicit storage contract.

### Existing publication pipeline

The Hub has two related paths:

- the generic `stash.Stasher` resolves one requested coordinate/version, checks storage, fetches the source, saves Info and ZIP, and indexes it;
- `repositoryPublisher` discovers one Repository snapshot, validates every member, saves all missing Skill artifacts, assesses them through the protocol decorator, then commits Repository/version membership to the Catalog. On failure it attempts to delete newly stored members.

Strong implementation choices include bounded upstream concurrency, negative caching of not-found Repository publications, per-request correlation logs, immutable Repository conflict checks against `CommitSHA`, and singleflight around both requested query and resolved Repository version. Publication keeps Repository membership invisible until member assessment succeeds, which is the right high-level commit seam.

### Storage immutability is not a real invariant yet

`storage.Backend.Save` is documented as saving immutable Info and ZIP, but its interface and compliance suite do not require create-only behavior, byte equality on repeated writes, atomic visibility, or rollback after a partial write. Backend behavior differs materially:

- GCS uses `DoesNotExist` preconditions and maps a collision to `AlreadyExists`;
- filesystem storage opens `source.zip` with `O_TRUNC` and then rewrites Info, so an existing canonical artifact can be overwritten and a crash can expose a partial pair;
- S3, Azure Blob, and MinIO upload to stable keys without an explicit create-only precondition in this layer and may replace existing bytes;
- the shared object uploader writes Info and ZIP concurrently and returns a combined error, but does not remove the successful half when the other upload fails;
- several `Exists` implementations require both files, while the generic checker requires only Info, so partially published state is interpreted differently by backend.

The Repository publisher's preflight reduces but does not close this gap. It trusts an existing member when its Info contains the same `CommitSHA`; it does not compare the expected `Sum` or verify the stored ZIP. Two Hub instances can race after the read-before-write check because Repository singleflight is process-local. The generic stasher similarly treats `Exists` as proof and does not authenticate existing bytes.

This matters directly to the future eviction design: Info-only is intended to become a valid, explicit state. It cannot continue to be an accidental half-publication state detected differently by each backend.

### Duplicate concurrency machinery

`stash.New` already owns an `x/sync/singleflight.Group`, but `app_proxy.go` wraps it again with a configurable singleflight layer. The default in-memory wrapper reimplements singleflight with a mutex, subscriber map, goroutine, and channels even though the inner implementation already uses `golang.org/x/sync/singleflight`. Distributed wrappers add a legitimate multi-instance concern, but the inner and outer duplicate suppression layers obscure which key and lifecycle is authoritative.

Singleflight should remain only an optimization. It cannot establish immutability across processes; storage conditional creation and content verification must do that.

### Recommended publication contract

Define storage around independently addressable immutable resources and an explicit publication record:

```text
PutInfoIfAbsent(coordinate, version, exactBytes)
PutZIPIfAbsent(coordinate, version, stream, expectedSum, expectedSize)
GetInfo(...)
GetZIP(...)
DeleteZIP(...)                 // eviction only; never deletes Info
ArtifactState(...)            // present | restoring | evicted | unavailable
CommitRepositoryVersion(...)  // Catalog transaction after all members validate
```

Each conditional put must have one of three outcomes: created; already present with identical authenticated content; or immutable conflict. Backends that lack native conditional creation need an adapter with equivalent transactional/CAS guarantees, not silent overwrite. The storage compliance suite should run collision, concurrent-writer, partial-failure, Info-only, ZIP restoration, and post-restore Sum tests against every backend.

For publication:

1. resolve one immutable Repository snapshot;
2. deterministically build every member Info/ZIP and expected Sum;
3. conditionally publish each resource, treating identical existing bytes as success and different bytes as conflict;
4. read/verify published bytes or rely on a backend receipt that proves digest and size;
5. atomically commit Repository/version membership and artifact state in the Catalog;
6. make cleanup idempotent, but never delete a resource that predated this attempt.

Use one `x/sync/singleflight` layer for in-process request coalescing. If cross-instance coordination is still valuable, expose one lease abstraction around the resolved immutable publication key. Correctness must continue to hold when the lease is absent or expires.

### Disposition

- **Copy:** proxy-mediated source hiding and permanent immutable resource semantics.
- **Reject:** `go-import` HTML discovery and `mod` meta tags; the configured Hub already supplies discovery.
- **Keep/adapt:** Repository snapshot publication followed by Catalog visibility, upstream capacity bounds, and immutable conflict detection.
- **Fix immediately:** make create-only or identical-content behavior part of `storage.Backend` compliance; eliminate overwrite-capable canonical saves.
- **Refactor:** model Info-only eviction as explicit state and split ZIP deletion from artifact deletion.
- **Remove duplication:** replace the custom in-memory subscriber singleflight and nested coalescing layers with one standard in-process group plus an optional distributed lease.
- **Test:** concurrent conflicting publishers, half-write recovery, backend parity, and exact-byte restoration.

### Task 11 review verdict

The Hub has a sound high-level Repository commit seam, but immutable publication currently depends on optimistic checks and backend-specific behavior. The storage interface says “immutable” without enforcing it. Before historical ZIP eviction is implemented, storage must distinguish intentional Info-only residency from corruption and must reject different bytes at an existing canonical coordinate across every backend.

## Task 12 — VCS discovery, version mapping, and source security

### Official contract

The Go reference splits direct VCS access into six separate concerns:

- [finding a repository](https://go.dev/ref/mod#vcs-find), including vanity-path `go-import` discovery and secure transport rules;
- [mapping semantic versions to commits](https://go.dev/ref/mod#vcs-version), including submodule Tag prefixes and immutable Tag expectations;
- [mapping pseudo-versions to commits](https://go.dev/ref/mod#vcs-pseudo), validating revision suffix, commit timestamp, and ancestor Tag base;
- [mapping branches and commits to canonical versions](https://go.dev/ref/mod#vcs-branch), preferring the highest valid Tag at the revision and otherwise deriving a pseudo-version;
- [locating module directories](https://go.dev/ref/mod#vcs-dir) and excluding nested modules/vendor content;
- [controlling VCS tools with `GOVCS`](https://go.dev/ref/mod#vcs-govcs), because invoking source-control clients against untrusted servers is an attack surface.

Go also copies a repository-root `LICENSE` into a subdirectory module when no local `LICENSE` exists. That rule is frozen because it affects authenticated content bytes.

### SkillsGo source model

SkillsGo deliberately has a narrower and clearer source model:

- only Git is supported;
- a canonical Repository ID is also its HTTPS clone coordinate;
- `/-/` explicitly separates the Repository from a Skill directory, avoiding prefix probing and vanity HTML discovery;
- every Skill discovered in one Repository snapshot inherits the same Repository version;
- Repository-wide Tags are plain canonical SemVer Tags, regardless of Skill subdirectory;
- there is no Go major-version path suffix and no independently versioned subdirectory module.

These are good adaptations. SkillsGo should not copy Go's subdirectory Tag prefixes (`gopls/v0.4.0`), nested-module search, `+incompatible`, VCS suffix guessing, or `go-import` discovery. They solve Go Module identity problems that SkillsGo has intentionally removed.

The repository scanner resolves one commit, walks tracked paths for `SKILL.md`, excludes hidden path segments, validates each manifest, computes the member tree identity, and builds every accepted Skill from the same snapshot. That is a strong implementation of Repository-owned publication.

### Version mapping: strong reuse with one ref-namespace defect

The resolver correctly reuses public `golang.org/x/mod/module` and `x/mod/semver` APIs for pseudo-version construction and parsing. Exact pseudo-versions are checked against:

- the canonical 12-character commit prefix;
- the exact UTC commit timestamp;
- existence of the base semantic Tag;
- base-Tag ancestry;
- the rule that an already canonically tagged commit cannot be represented by a derived pseudo-version.

Branch and commit queries resolve to the highest canonical SemVer Tag at that commit or to an ancestor-based pseudo-version. The adversarial matrices cover Tag/revision ambiguity and invalid pseudo-version forms. This is the right place to reuse Go behavior rather than vendor cmd/go internals.

However, Git Tag storage is internally inconsistent. Refresh fetches remote Tags into `refs/skillsgo/upstream-tags/*`, preserving upstream identity without mutating local Tags. Exact semantic resolution uses that namespace, and `latest` partially combines it with local Tags. Other paths still run `git tag --list`, `git tag --points-at`, or `git tag --merged`, which inspect `refs/tags/*`, not the custom upstream namespace. After the initial clone:

- newly pushed Tags may be absent from `/@v/list`;
- a branch/commit pointing at a newly tagged commit may be converted to a pseudo-version instead of that Tag;
- pseudo-version generation may ignore a newly fetched ancestor Tag;
- deleted or moved initial-clone Tags may remain as stale local Tags.

`ListRepositoryTags` avoids the cache and uses `git ls-remote --tags`, creating a third Tag view. The three mechanisms can disagree about the same Repository. There must be one `TagCatalog` abstraction over the refreshed upstream ref namespace, reused by List, latest, exact Tag lookup, points-at, ancestor-base selection, and backfill.

### Identity bug for non-GitHub hosts

`protocol/skillid.Parse` lowercases the entire Repository string, and the CLI repeats this normalization. Lowercasing is valid for DNS host names and for GitHub owner/repository identity, but Git path components on general hosts may be case-sensitive. Since SkillsGo accepts arbitrary full hosts, `git.example.com/Team/Repo` can silently become a different repository.

Canonicalization must lowercase the host only by default. Apply host-specific path normalization through an explicit provider policy; GitHub may case-fold owner/repository components, while an unknown Git host must preserve path case. Repository cache keys must use the same canonical provider policy.

### Git execution security

Several controls are already valuable:

- canonical clone URLs are HTTPS;
- HTTP redirects are disabled for clone/fetch;
- DNS results are rejected when they resolve to private, loopback, link-local, unspecified, or non-global addresses unless private Git hosts are explicitly enabled;
- clone happens in a temporary directory followed by rename;
- GitHub credentials are injected through an environment header rather than a command-line URL;
- only bounded diagnostics are logged;
- repository synchronization is coalesced and source work has time limits.

The remaining gaps are significant:

1. Git inherits the Hub process environment and user/system Git configuration. `url.*.insteadOf`, credential helpers, alternate transports, hooks/config, and interactive credential behavior are not made hermetic. A nominal HTTPS URL can be rewritten by operator-level Git config.
2. `SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS=true` disables the network-target check globally. It should be a host/CIDR allowlist with explicit private-source routing, not a boolean off switch.
3. DNS validation and Git connection are separate operations, leaving a DNS-rebinding window. Host allowlisting, egress policy, and sandbox/network enforcement are stronger boundaries than preflight lookup alone.
4. GitHub token failover retries every token after every Git failure, not only authentication or rate-limit failures. A malformed or missing Repository can multiply upstream work.
5. The 512 MiB repository limit is measured only after initial clone. Fetch growth is not rechecked. A large pack can exhaust disk before the post-clone walk, and later fetches can grow the cache without enforcement.
6. `--filter=blob:none` creates a partial clone. Later `git show`, `cat-file`, or packaging reads may lazily contact the promisor remote for missing blobs outside the apparent synchronization step. Offline/source-access policy, egress validation, accounting, and timeouts must cover those lazy fetches too.
7. The Hub invokes Git directly against arbitrary public hosts without a sandbox equivalent to Go's centralized mirror risk boundary.

Do not replace Git with a pure-Go implementation solely to avoid process execution; that trades a mature, highly optimized protocol client for a different compatibility and resource-risk profile. Keep Git, but execute it through one hardened adapter with a controlled environment, explicit protocol allowlist, non-interactive credentials, resource limits, and sandbox/egress policy.

At minimum the adapter should set a controlled HOME/config, `GIT_CONFIG_NOSYSTEM=1`, `GIT_TERMINAL_PROMPT=0`, disable credential prompting and unsafe protocol rewrites, permit HTTPS only, and make all network-capable Git operations observable. Production deployment should add process, filesystem, CPU/memory, disk, and network isolation.

### Directory and license policy

SkillsGo's explicit `/-/` directory is superior to Go's module-root inference for this domain. Repository discovery may publish many Skills, but each ZIP should contain only its selected Skill tree according to one deterministic inclusion policy. Nested `SKILL.md` files need an explicit rule: they are currently both content inside an ancestor Skill and separate discovered Skills, so the same bytes can occur in multiple artifacts. That may be intended, but must be documented and tested.

Do not copy Go's automatic repository-root `LICENSE` injection implicitly. SkillsGo already extracts declared license metadata and has established content sums. If root-license inclusion is desired, define it now as part of the deterministic Skill archive format before SumDB launch; otherwise keep artifacts limited to their Skill tree and require publishers to place necessary license text inside it.

### Disposition

- **Copy:** canonical Tag preference, pseudo-version authenticity, Tag immutability expectations, and a strict VCS execution policy.
- **Reuse:** continue using `x/mod/module` and `x/mod/semver`; cmd/go's repository internals are not a public library and should not be vendored wholesale.
- **Adapt:** Git-only HTTPS sources, explicit `/-/` directories, Repository-wide versions, and one-snapshot multi-Skill discovery.
- **Reject:** vanity `go-import`, VCS guessing, subdirectory Tag prefixes, nested-module discovery, major suffixes, and `+incompatible`.
- **Fix immediately:** unify all Tag operations on one upstream Tag catalog/ref namespace and stop case-folding arbitrary Git path components.
- **Harden:** introduce one hermetic Git runner, private-host allowlists, complete disk/resource accounting, lazy-fetch policy enforcement, and deployment sandboxing.
- **Decide before SumDB:** nested-Skill inclusion and repository-root license behavior, because both affect authenticated archive bytes.

### Task 12 review verdict

SkillsGo's VCS domain simplification is sound, and its pseudo-version validation is one of the strongest parts of the implementation. The main correctness drift is fragmented Tag visibility; the main identity bug is universal path lowercasing; and the main operational risk is treating a preflight DNS check plus an inherited-environment Git subprocess as a complete source sandbox. These should be corrected before broadening beyond GitHub or relying on cached repositories for ZIP restoration.

## Task 13 — ZIP format, limits, and safe extraction

### Official contract

The [Go Modules Reference — module ZIP files](https://go.dev/ref/mod#zip-files) points implementers to the public `golang.org/x/mod/zip` package. Go's archive rules address both reproducibility and hostile input:

- compressed and total uncompressed content are each limited to 500 MiB;
- every entry has the `$module@$version/` prefix;
- symlinks and irregular files are excluded;
- empty directories are ignored;
- nested modules and vendor trees are excluded;
- case-fold-equivalent paths are forbidden;
- paths obey portable character and Windows reserved-name rules through `module.CheckFilePath`;
- file mode, timestamps, and other ZIP metadata do not define module content.

SkillsGo appropriately chooses smaller limits: 64 MiB compressed, 64 MiB uncompressed, and 5,000 files. A Skill is usually documentation plus small scripts, so Go's 500 MiB ceiling would be unnecessarily permissive.

### SkillsGo archive contract

The producer creates a ZIP from one Git Skill directory, strips that directory prefix, and writes entries below:

```text
{skillID}@{immutableVersion}/SKILL.md
{skillID}@{immutableVersion}/{relative-path}
```

The prefix is useful for safe human inspection and extraction. The content Sum intentionally removes it and hashes only sorted Skill-relative file paths and bytes, so the same Skill content can match across identity/version coordinates. This separation is coherent: ZIP identity is coordinate-specific, while content matching is coordinate-independent.

The shared `protocol/artifact` boundary validates archive size, entry count, prefix, exact duplicate paths, total expansion, CRC/declared-size consistency, required root `SKILL.md`, and normalized relative paths. It computes and visits content in one sorted traversal. The CLI verifies the declared Sum before extracting into a private temporary directory, then atomically renames the completed Store entry. Symlinks and non-regular files are rejected or omitted. These are strong choices.

### Duplicated and incomplete validation

`hub/pkg/skill/zip_compression.go` independently defines the same three limits and a second path validator instead of importing `protocol/artifact`. The producer's validator is actually stricter about UTF-8 and control characters, while the shared consumer validator is stricter only through later newline rejection in h1 framing. This split means “what Hub emits” and “what CLI accepts” are not one executable format contract.

Portable collision handling is also incomplete:

- the producer detects collisions with `strings.ToLower`, which is not the same as Unicode case folding;
- the shared validator rejects only byte-identical duplicate paths;
- neither shared validation nor extraction rejects Windows device names or all cross-platform-invalid characters;
- the CLI extractor may therefore overwrite/collide on a case-insensitive filesystem or fail only after download and verification.

Use `module.CheckFilePath` and the collision behavior already implemented by `x/mod/zip` as the baseline. SkillsGo may add stricter rules, but one shared validator must be invoked by producer, auditor, Sum calculator, local importer, and extractor. Do not apply Go's module-specific vendor/nested-`go.mod` exclusions automatically; a Skill may legitimately contain those names as examples or support files.

### Resource-boundary gaps

The internal Hub audit read is correctly bounded with `LimitReader(MaxArchiveBytes+1)` and validates the storage-reported size. The CLI download path is not: `getWithProgress` calls `io.ReadAll` on a successful response before checking `ArchiveSize` or invoking the bounded artifact validator. A malicious or broken Hub can therefore cause unbounded client memory growth despite the nominal 64 MiB protocol limit. Content-Length and Info ArchiveSize must be checked before reading, and the body itself must always be limit-read.

`metadataFromArchive` is another bypass. It locates any path ending in `/SKILL.md` and calls unbounded `io.ReadAll` before the archive has passed `WalkContent`. A compressed ZIP bomb in storage could allocate far beyond the limit during Info enrichment. Metadata extraction, Sum calculation, and audit should be one call to the shared bounded traversal, selecting the exact root-relative `SKILL.md`.

The producer is bounded but memory-heavy. It buffers the Git archive, parses it, writes a new ZIP, then `recompressZipBest` reads the full output into memory and rewrites it. At the 64 MiB boundary, each concurrent publication may retain several archive-sized buffers plus expanded file data. The CLI similarly retains the full ZIP and then extracts it. This is acceptable for a first implementation only if worker concurrency and process memory are budgeted; a streaming/file-backed pipeline would provide much better headroom.

### Archive-byte determinism and modes

The h1 Sum correctly ignores ZIP compression, entry order, timestamps, and file modes, matching Go's content identity model. SkillsGo still preserves executable mode in Store content because scripts need it; that mode is security/installation metadata, not part of Sum. This distinction must remain explicit. If mode changes are meant to be authenticated, add a separate artifact-envelope digest rather than silently changing h1 semantics.

The Store also records SHA-256 of the exact ZIP bytes and rejects a second archive with different encoding at the same coordinate, even when h1 content is equal. That is a useful byte-immutability check, but future ZIP restoration must either reproduce exact canonical bytes or persist/verify an explicit envelope digest. h1 alone proves file content, not identical ZIP serialization or executable modes.

### Recommended implementation boundary

Create one shared archive package with these operations:

```text
ValidateAndWalkZIP(readerAt, size, coordinate, version, visitor) -> h1, envelope metadata
CreateZIP(file source, coordinate, version) -> stream, h1, byte digest, size
ExtractValidatedZIP(validated source, destination)
ValidateDirectory(root) -> h1, mode/envelope metadata
```

It should own all limits, Unicode/case-fold collision detection, `module.CheckFilePath` portability, exact prefix rules, supported compression methods, regular-file policy, and root manifest selection. Producer and consumer must not maintain parallel validators. Prefer file-backed `ReaderAt`/temporary files for large downloads and generation so limits are enforced without multiple full-memory copies.

The HTTP client should reject an advertised length above 64 MiB, read at most 64 MiB plus one byte regardless of headers, verify actual length against Info, then validate h1. Extraction should consume only the already-validated entry plan and use no-follow/containment-safe filesystem operations where supported.

### Disposition

- **Copy:** prefix discipline, dual compressed/uncompressed limits, portable path rules, Unicode case-fold collision checks, irregular-file rejection, and public `x/mod` validation helpers.
- **Adapt:** keep 64 MiB/5,000-file limits, Skill-relative h1, required root `SKILL.md`, executable mode preservation, and coordinate-specific ZIP prefixes.
- **Reject:** Go's 500 MiB limit and automatic vendor/nested-module exclusion.
- **Remove duplication:** consolidate Hub producer and shared consumer limits/path validation; use `module.CheckFilePath` rather than recreating portable filename rules.
- **Fix immediately:** bound CLI response reads, make metadata extraction use the shared traversal, and reject case-fold/Windows path collisions before extraction.
- **Improve:** file-backed streaming generation/download and an explicit exact-ZIP envelope digest/restoration contract.

### Task 13 review verdict

The basic archive design is strong and substantially safer than the earlier implementation: it has bounded expansion, normalized h1 content identity, and atomic local Store writes. The remaining risk comes from having two validators and several reads outside the validated traversal. Consolidating these seams will both remove wheel reinvention and close the most important ZIP-bomb and cross-platform extraction gaps.

## Task 14 — Private sources, Hub authentication, and privacy

### Official contract

The [Go Modules Reference — private modules](https://go.dev/ref/mod#private-modules) treats privacy as routing policy, not just credentials:

- `GOPRIVATE` marks path prefixes whose existence must not be disclosed to public proxies or SumDB;
- `GONOPROXY` and `GONOSUMDB` split source-routing and transparency-log policy;
- ordered proxy fallback distinguishes absence (`404`/`410`) from gatekeeper rejection (`403`);
- proxy credentials may come from `.netrc` or URL userinfo, with explicit warnings about exposing URL credentials;
- VCS credentials belong to the VCS client, which must avoid interactive prompts.

The central lesson is that the path itself may be sensitive. Preventing public artifact download after a private path has already been sent to a public service is too late.

### Hub HTTP authentication

The accepted SkillsGo model is implemented accurately:

- a complete `SKILLSGO_HUB_BASIC_AUTH_USER/PASS` pair protects the entire Hub except `/healthz` and `/readyz`, including administration;
- when global authentication is absent, a complete `SKILLSGO_HUB_ADMIN_AUTH_USER/PASS` pair registers and protects only `/api/v1/admin/**`;
- with neither pair, administration routes are not registered;
- partial pairs fail startup;
- if both pairs are complete, global credentials win and Hub logs a warning without failing startup;
- Basic credentials are compared with constant-time primitives and unauthorized responses include `WWW-Authenticate`.

This is a good bootstrap contract for a single-tenant private Hub and for a public Hub whose Backfill API alone is administrative. It exactly matches ADR 0008 and the prior design decision.

It is not a full authorization system. There is one shared credential, no principal identity, repository/operation permissions, revocation/audit model, brute-force control, or tenant isolation. Basic Auth must only travel over TLS. Those limitations are acceptable for current Hub administration if documented; they are not sufficient for a multi-tenant private registry.

### Missing CLI side of private Hub authentication

The CLI has no first-class Hub credential configuration and never calls `SetBasicAuth`. `hub.New` accepts a URL containing userinfo, so `https://user:pass@hub/...` may work through Go's HTTP stack, but this is not an acceptable primary contract: credentials can leak through shell history, process arguments, diagnostics, configuration output, and logs. A globally protected Hub is therefore implemented server-side but incomplete as an end-to-end supported product flow.

Add an explicit credential provider to the CLI HTTP transport, scoped to the exact configured Hub origin and stripped on cross-origin redirects. Prefer OS credential storage or a permission-checked credential file; environment variables are a non-interactive fallback. Do not put secrets in `SKILLSGO_HUB_URL` or `--hub`. Return a typed authentication failure for `401` and authorization failure for `403` instead of classifying both as generic invalid input.

Admin Backfill intentionally remains Hub API-only, so the normal CLI does not need Admin credentials. Operational callers can use the Admin pair directly. Global Hub credentials also authorize Backfill by design.

### Critical source-visibility gap

The Hub can receive GitHub tokens or a copied `.netrc` that grants access to private repositories, but publication has no public/private visibility field or authorization check. Any ordinary unauthenticated `/mod/{repository}/...` miss can invoke the credentialed source fetcher. Once materialized, artifact protocol, Catalog, search, Content Match, and metadata routes do not distinguish a private Repository.

On a public Hub, a token with private-repository scope can therefore turn knowledge of a private coordinate into a public fetch-and-publish path. Admin-only Backfill protection does not close this, because demand-driven ordinary publication is public. This is a **release-blocking privacy issue** for any deployment that combines public routes with source credentials capable of reading private repositories.

Until repository visibility and authorization exist:

- public Hub credentials must be constrained to public-repository access only;
- private repositories must use a globally authenticated private Hub or remain Local Skills;
- the operator documentation should explicitly reject mixed public/private source authority in one Hub;
- future SumDB must not log private coordinates into a public transparency tree.

A durable model needs `RepositoryVisibility` and an authorization decision before source resolution, publication, every artifact/catalog read, background processing, logging/metrics labels, and SumDB inclusion. Visibility must derive from trusted operator policy or source-provider evidence; it must not be selected by an untrusted request.

### Source credential handling

GitHub token injection through an HTTPS extra header is better than embedding credentials in clone URLs, and token values are not intentionally logged. Stable deduplication and sticky failover are reasonable for rate-limit distribution, subject to the failure-classification issue in Task 12.

The generic auth-file path is inherited baggage:

- `initializeAuthFile` copies the configured file into the Hub process user's real home directory and may overwrite an existing `.netrc`/`.hgrc`;
- it leaves the copy behind after shutdown;
- it makes credentials process-global rather than origin-scoped;
- `.hgrc` support remains even though SkillsGo supports Git only.

Remove Mercurial configuration. Run Git with a controlled HOME and explicit credential material or a narrowly scoped credential helper. Validate source-credential file permissions, avoid copying into the operator's real home, and clean up ephemeral files. Provider tokens should be least-privilege and separated between public metadata/rate-limit access and explicitly private source access.

### Privacy routing recommendation

Do not copy all five Go environment variables. Model the actual SkillsGo authorities:

```text
HubOrigin              // one trusted distribution authority
HubCredentialProvider  // authenticates the CLI to that origin
SourceAccessPolicy     // Hub-side host/repository allowlist
RepositoryVisibility   // public | private(scope)
TransparencyPolicy     // public log | private log | excluded
```

The CLI must never fall back from a private Hub coordinate to the public Hub unless an explicit policy proves the coordinate is public. A private Hub may proxy public and private Skills while keeping clients on one origin, which is the simplest safe deployment. If multi-origin fallback is added, `401`/`403` must stop and private path prefixes must never be sent to a public origin.

### Disposition

- **Copy:** privacy-before-network routing, origin-scoped credentials, non-interactive VCS auth, and gatekeeper status semantics.
- **Keep:** global Basic Auth fallback for Backfill, Admin-only protection on a public Hub, startup rejection of partial pairs, and warning when global credentials supersede Admin credentials.
- **Adapt:** one trusted private Hub instead of CLI direct-to-VCS for private remote Skills.
- **Reject:** credentials in Hub URLs as the normal interface and raw Go `GOPRIVATE/GONOPROXY/GONOSUMDB` configuration.
- **Fix before private-source use:** add visibility/authorization throughout publication and reads; add a real CLI Hub credential provider.
- **Remove:** process-home auth-file copying and obsolete `.hgrc` support.
- **Guard:** prohibit private-capable source tokens on a public unscoped Hub until the visibility model is implemented.

### Task 14 review verdict

The Backfill authentication decision is implemented cleanly, but private Hub support is only half complete and mixed public/private source access is unsafe. The most important Go lesson here is not `.netrc`; it is that coordinate disclosure and source authority are privacy decisions made before any network or publication action. SkillsGo needs that boundary before it can safely claim private remote Repository support.

## Task 15 — Local caches, Hub residency, and eviction

### Official contract

The [Go Modules Reference — module cache](https://go.dev/ref/mod#module-cache) establishes several useful properties:

- one cache is shared safely by multiple projects and concurrent Go commands;
- extracted module directories are read-only to discourage accidental mutation;
- proxy-shaped Info, mod, ZIP, and ziphash resources remain distinct;
- a content hash authenticates both ZIP content and extracted content;
- `go mod verify` detects local changes;
- the Go tool does not impose a maximum size or automatically evict entries; explicit `go clean -modcache` removes them.

SkillsGo should copy the concurrency, immutability, and verification properties, but not Go's “grow forever” policy. A public Hub has different storage economics, and the agreed full-history Backfill specifically needs lifecycle management.

### CLI Store

The CLI Store is shared under `~/.skillsgo/store` across Workspaces. `Put` verifies the Hub Sum, extracts into a private temporary directory, writes Info and a provenance receipt, and atomically renames the completed entry. An entry lock coalesces cross-process writers; an existing different ZIP SHA-256 is rejected. `Get` verifies identity, required assessment fields, root `SKILL.md`, and a fresh directory h1 before returning the artifact. Local and captured provenance are modeled explicitly.

This provides stronger automatic verification than Go's normal cache reads. It also means every `Get` is O(total files and bytes), which may become expensive for inventory and repeated projections. A verified-state cache can optimize this only if it binds file identity/mtime/inode safely; correctness should continue to fall back to h1 verification.

The Store is called content-addressed, but its physical key is `skillID@version`, not Sum. Equal content under multiple coordinates or versions is stored repeatedly. A true CAS would split immutable objects from references:

```text
objects/{content-or-envelope-digest}/...
refs/{escaped-skillID}/{version} -> object + Info + provenance
```

Do not key extracted trees by h1 alone while preserving executable modes, because h1 intentionally ignores mode. Either canonicalize modes or use an envelope digest that binds path, mode, and content while retaining h1 for ecosystem content identity.

### Local mutation and locking risks

Unlike Go's read-only extracted cache, Store files retain ordinary writable owner permissions from the ZIP. Symlink installation projects the Store tree directly into Agent directories, so a tool editing through that symlink can corrupt the shared immutable entry for every Workspace. Later `Get` detects the mismatch, but mutation has already occurred. Hub-backed Store objects should be made read-only after extraction (`0444`/`0555` according to executable mode), while copy installations receive writable copies. Local/captured ownership semantics may require a separate policy.

The custom lock file is serviceable but fragile: stale recovery is based only on one-minute age, does not verify whether the recorded PID is alive, may break a valid slow writer, and does not define shared-network-filesystem behavior. Info cache locking is only an in-process `sync.Map`; two CLI processes can race to replace the same immutable metadata path. Atomic rename prevents partial files but not last-writer-wins with different bytes.

Prefer create-only immutable publication plus byte comparison, using a well-tested cross-platform file-lock primitive only where required. Treat lock files and abandoned `.skillsgo-store-*`/`.partial-info-*` directories as explicit recoverable temporary state, with safe cleanup tests.

### Info cache

The Info cache preserves exact Repository and Skill Info bytes, wraps them with identity plus SHA-256 corruption detection, and refuses a different subsequent value in one process. `skillsgo.sum` supplies the separate expected checksum used by restore. This separation is conceptually correct: the wrapper hash detects local corruption, while the Workspace ledger establishes expected identity.

There is no enumeration, size policy, cross-process immutability, reference tracking, or garbage collection. Skill Info is also stored inside each Store entry, so some data is duplicated; Repository Info remains necessary for restoring membership. Consolidate immutable metadata behind one cache API and reference graph instead of adding independent cleanup code to both directories.

### Hub source and artifact caches

The persistent Git repository cache is shared across Skills in a Repository and avoids repeated clone/synchronization. It has no total-size quota, TTL, LRU, or cleanup. The configured per-repository byte limit runs only after initial clone, not after fetch or partial-clone lazy blob retrieval. It cannot be treated as a durable restoration source or a bounded cache.

Hub artifact storage currently couples Info and ZIP in `Exists`, `Save`, and `Delete`, with backend-dependent behavior. There is no last-access timestamp, residency state, restore lease, or ZIP-only delete. These gaps were identified in Tasks 04 and 11 and must be fixed before scheduled cleanup.

### “Delete old ZIPs but guarantee download”

Deleting the only stored historical ZIP and relying on the upstream Git Repository does **not** guarantee future download. A Repository can be deleted, made private, rewrite history, lose a Tag, revoke Hub credentials, or become unavailable. Commit SHA and h1 prove a reconstruction if one is obtained; they do not preserve the bytes needed to obtain it.

The fish-and-bear solution is tiered authoritative storage:

```text
Backfill
  -> publish immutable Info + expected Sum + exact ZIP
  -> keep ZIP hot initially
  -> after access/age policy, move exact ZIP to durable cold tier
  -> mark hot residency evicted, never delete Info/catalog identity

GET ZIP
  -> hot hit: stream and record sampled access
  -> hot miss: acquire restore lease
       -> retrieve cold exact ZIP
       -> verify size + h1 + optional envelope digest
       -> conditionally restore hot copy
       -> stream
```

“Eviction” must mean deletion from the hot serving tier, not destruction of the authoritative copy. Object-store archival classes are the simplest implementation and provide byte-identical restoration. If storage duplication across many Skills is too expensive, a more advanced cold tier may retain content-addressed file trees or Repository Git bundles/packs and deterministically rebuild ZIPs. That can deduplicate aggressively, but it is more complex and must preserve every file, mode policy, archive-format version, and expected h1. An upstream clone cache alone is not sufficient.

The Catalog should track at least `artifact_state`, `hot_last_accessed_at`, `cold_location/version`, `restore_attempted_at`, and stable failure state. Access writes should be sampled or batched rather than synchronously updating the database for every download. Eviction must skip current/latest versions, active publication/restoration, recent access, legal/retention holds, and any artifact not durably confirmed in the cold tier. A restore lease must coalesce concurrent cold misses.

Historical Info remains independently readable and must never reopen the ZIP merely to regenerate enrichment. Exact assessed Info, Sum, size, Risk result, and cold receipt are publication records. This both enables eviction and removes the current read amplification.

### CLI garbage collection

The CLI Store has no ZIP to evict after extraction; the downloaded ZIP exists only in memory. Future local GC should operate on extracted immutable objects and metadata references, not mimic Hub ZIP policy. It must discover live references from Workspace manifests/sums, installation receipts/targets, in-progress plans, and user-pinned entries. Local and captured artifacts must never be deleted merely because no Hub coordinate can restore them. A dry-run report and age grace period should precede deletion.

### Disposition

- **Copy:** shared cache, concurrency safety, immutable/read-only extracted objects, separate integrity records, and explicit verification.
- **Adapt:** automatic Hub hot-tier eviction is justified; CLI GC and Hub residency need different policies.
- **Reject:** unbounded grow-forever Hub storage and source-cache-as-authoritative restoration.
- **Fix:** make Store objects read-only, make Info publication cross-process immutable, and replace fragile duplicate locking where practical.
- **Refactor:** split Store objects from coordinate refs; split Hub Info metadata from ZIP residency and deletion.
- **Guarantee:** retain an authoritative cold copy (exact ZIP or equivalent complete immutable source) before any hot ZIP eviction.
- **Optimize:** sampled access accounting, restore singleflight/lease, quotas, abandoned-temp cleanup, and source-cache size management.

### Task 15 review verdict

The CLI Store already has good atomicity and verification, but it is writable, not truly content-addressed, and paired with a second metadata cache whose concurrency guarantees are weaker. For the Hub, metadata-only historical residency is viable only when “delete” means hot-tier eviction backed by durable cold data. No checksum can compensate for destroying the last copy while promising permanent downloadability.

## Task 16 — h1, `skillsgo.sum`, and a future checksum database

### Official contract

The [Go Modules Reference — authenticating modules](https://go.dev/ref/mod#authenticating) uses three related but distinct mechanisms:

1. **h1 content Sum:** SHA-256 over deterministic file-path/content framing for a module ZIP; ZIP order, compression, alignment, and metadata do not affect it. Raw `go.mod` bytes use a direct SHA-256 h1.
2. **`go.sum`:** a Workspace-local three-field trust ledger: path, version/resource suffix, and algorithm-prefixed hash.
3. **SumDB:** a global append-only transparency log of `go.sum` records. Merkle inclusion and consistency proofs detect omission/equivocation relative to a client's known history; a signed checkpoint authenticates the tree size and root hash.

The Merkle tree and checkpoint signature are not alternatives. The tree makes proofs compact and append-only history auditable; the Ed25519 `note` signature tells the client which tree head is authorized by the log operator. Neither replaces the artifact h1 embedded in each leaf record.

### SkillsGo h1 contract

SkillsGo's `Sum` is correctly shaped for the Go ecosystem:

- a Skill ZIP is normalized to Skill-relative paths, sorted, and framed with Go's Hash1 rule;
- the coordinate/version ZIP prefix is removed before hashing, enabling content matching across releases and repositories;
- an extracted directory produces the same Sum as its archive;
- Repository Info bytes use direct SHA-256 encoded as `h1:`;
- only one content fingerprint is used in public Info and Store receipts.

This is the right cost/security tradeoff. BLAKE3 would be faster on large streams, but Skill archives are capped at 64 MiB and ZIP parsing/decompression, Git, network, storage, and assessment dominate. Choosing BLAKE3 would forfeit direct `x/mod` reuse and require a new ecosystem algorithm contract without removing the need for SHA-256 inside a Go-compatible transparency log. Do not add it as a second routine content fingerprint. A separate envelope digest is justified only if exact ZIP bytes/modes need authentication beyond h1.

### The current “vendored” Hash1 is not the implementation path

`protocol/artifact/hash1.go` vendors Go's small Hash1 function, but production ZIP and directory calculations do not call it. `WalkContent` and `DirectorySum` independently reproduce the framing through `writeHash1Content`; the exported vendored `Hash1` is called only by tests. The repository therefore has both a copied upstream function and a separate active implementation of the same algorithm.

`golang.org/x/mod/sumdb/dirhash.Hash1` is a stable public API and `x/mod` is already a dependency. Prefer calling it directly with validated Skill-relative paths and open callbacks. If one-pass audit performance materially requires an incremental accumulator, keep one private shared implementation and run golden/differential tests against `dirhash.Hash1`; remove the unused vendored public copy. Do not vendor cmd/go internals.

### `skillsgo.sum` strengths

The ledger follows Go's useful three-field shape and correctly separates editable intent from integrity. Updates are locked, sorted, atomic, and retain historical entries. The CLI verifies every already-known expected Sum before Store, manifest, or target mutation; a missing line is accepted only for first use and is added after the downloaded bytes have been verified. Conflicting hashes for the same path/version/algorithm fail closed.

Historical retention is a reasonable SkillsGo adaptation. There is no transitive graph to tidy, and old lines preserve evidence for rollback and dormant Workspaces. A future explicit tidy command may prune only entries proven unreachable by current requirements and retained history policy; it must not silently rewrite trust during ordinary add/update.

Two format issues should be fixed:

1. `validateSumEntry` accepts any valid base64 length for `h1`, while the shared `ValidSum` correctly requires a 32-byte SHA-256 value. The ledger parser should use the shared validator.
2. `skillsgo.sum` is written with mode `0600`. It is a portable, normally version-controlled integrity file containing no secret and should use repository-normal file permissions (typically `0644`) unless the Workspace policy says otherwise.

### Trust-on-first-use and metadata boundaries

Without SumDB, a new public Skill is trusted on first use through TLS plus the configured Hub: the Hub supplies Info.Sum and the matching ZIP, and the CLI then records the verified h1. `skillsgo.sum` detects later changes but cannot detect a Hub that equivocates before the first line is established. That is the exact gap a transparency log should close.

Skill content Sum does not authenticate mutable assessment. This is desirable: Risk can be rescanned without changing the immutable artifact. However, Repository Info is hashed as exact raw bytes and embeds complete member Info, including Risk. That freezes assessment bytes and conflicts with `Store.RefreshAssessment`, which explicitly permits Risk refresh while holding Sum and source identity stable.

Split the wire model before SumDB:

- **immutable Skill artifact Info:** ID, version, time, commit/tree identity, content-derived name/description/license metadata, Sum, and archive size;
- **immutable Repository release manifest:** Repository ID/version/commit plus ordered member IDs and their immutable Sums/metadata references;
- **mutable assessment/product state:** Risk level, scanner version, evidence, popularity, translations, and other enrichments.

The artifact protocol and transparency log bind the first two. Product/API policy reads may combine current assessment at response time, but mutable Risk must not alter a previously authenticated immutable record.

### Future SkillsGo SumDB record model

Use a standard Go-shaped record rather than inventing a per-ZIP signature:

```text
{skillID} {canonicalVersion} h1:{skill-content-sum}
{repositoryID} {canonicalVersion}/repository.release h1:{canonical-release-bytes-sum}
```

The exact suffix is a SkillsGo choice; `repository.release` is clearer than authenticating an enriched, mutable `repository.info`. Canonical release bytes must use deterministic serialization and contain only immutable fields. A lookup may return the relevant line(s) plus log position and checkpoint exactly as Go SumDB does.

Publication order should be:

1. validate and durably retain the immutable artifact/cold receipt;
2. conditionally publish immutable Info and Repository release state;
3. append the first observed record to SumDB, rejecting a different existing line;
4. sign and publish a new checkpoint;
5. expose Catalog visibility only after the authenticated record is available, or explicitly define the short pending state.

Backfill uses the same path for every historical Tag. River may orchestrate discovery/retries, but append ordering, deduplication, and conflict detection belong to the log storage transaction, not job delivery semantics.

### Reuse the public SumDB implementation

The current `x/mod` dependency already exposes:

- `sumdb.NewServer` and `sumdb.NewClient` for the HTTP protocol;
- `sumdb/tlog` for records, tiles, tree hashes, inclusion proofs, and consistency proofs;
- `sumdb/note` for signed notes and key handling;
- `sumdb/dirhash` for h1.

Use these packages as the protocol engine and implement only SkillsGo's storage adapters, canonical record source, routing, and operational key management. `note.GenerateKey` currently uses Ed25519; that is the checkpoint signature to choose. Keep the signing key outside the database and ordinary application configuration, support rotation/multiple trusted verifiers, and publish the verifier key through an independently trusted release/configuration channel.

Clients must persist their latest trusted checkpoint/tile cache and verify both inclusion and consistency before accepting a previously unknown Sum. A `/lookup` response or database row used without proof and checkpoint verification is merely another unauthenticated API response.

Private Repository records must be excluded from the public log or written to a separately keyed private transparency log. Otherwise the coordinate itself leaks. Hub proxying/mirroring of SumDB can support controlled networks without weakening client verification.

### What not to add

- Do not sign every ZIP with the Hub's checkpoint key; that provides no public append-only consistency and complicates rotation.
- Do not use TreeSHA, CommitSHA, ZIP SHA-256, h1, Merkle leaf hash, and checkpoint signature as interchangeable “fingerprints.” Each has a different role.
- Do not add BLAKE3 alongside h1 without a concrete envelope threat that h1 does not address.
- Do not build a custom Merkle tree, proof format, tile protocol, or note signature implementation while `x/mod/sumdb` satisfies the required model.
- Author/publisher provenance signing (for example Sigstore/in-toto) is a separate future feature; SumDB proves globally consistent observed content, not who authored it.

### Disposition

- **Copy:** h1 semantics, three-field ledger shape, transparency-log lookup/tiles/checkpoints, inclusion and consistency verification.
- **Reuse directly:** `x/mod/sumdb`, `tlog`, `note`, and `dirhash`; use Ed25519 note signatures for checkpoints.
- **Adapt:** Skill-relative content Sum and an immutable Repository release record; retain historical Workspace lines.
- **Fix:** validate exact 32-byte h1 values, normalize sum-file permissions, and separate mutable Risk from authenticated immutable Info.
- **Remove duplication:** delete the unused vendored Hash1 path or make one implementation differential-tested against the public package.
- **Reject:** per-artifact Hub signatures, BLAKE3 as a second default fingerprint, and a home-grown SumDB.

### Task 16 review verdict

The choice of one `h1:` Sum is correct, but the code currently vendors one implementation while executing another, and the Info model mixes immutable release evidence with refreshable Risk. A future SumDB should be built as storage adapters around `x/mod/sumdb`, with Skill content and canonical Repository release records as leaves, Merkle proofs for append-only consistency, and Ed25519-signed checkpoints for tree-head authority.

## Task 17 — Environment variables and policy composition

### Official surface

The Go Modules Reference lists eleven module-related variables: `GO111MODULE`, `GOMODCACHE`, `GOINSECURE`, `GONOPROXY`, `GONOSUMDB`, `GOPATH`, `GOPRIVATE`, `GOPROXY`, `GOSUMDB`, `GOVCS`, and `GOWORK`. They combine historical mode selection, cache location, source routing, privacy, transport security, checksum policy, and workspace composition.

SkillsGo should copy the policy concepts, not the names or accumulated compatibility surface.

### Per-variable disposition

| Go variable | SkillsGo disposition | Reason |
| --- | --- | --- |
| `GO111MODULE` | Reject | SkillsGo has no legacy non-module execution mode. |
| `GOMODCACHE` | Adapt | One override for the SkillsGo state/cache root is useful for CI, isolation, and portable testing. |
| `GOINSECURE` | Reject | Public Hub and source access should require HTTPS; allow explicit loopback development, not path-pattern insecure transport. |
| `GONOPROXY` | Reject now | CLI direct-to-VCS bypass would evade Hub assessment and publication authority. |
| `GONOSUMDB` | Adapt later | Private visibility should select a separately keyed private log or exclusion; raw user glob bypass should follow the visibility model. |
| `GOPATH` | Reject | Agent targets and SkillsGo state roots are separate domain concepts. |
| `GOPRIVATE` | Adapt | Hub-side trusted Repository visibility/source policy is required, but it must not be an untrusted CLI hint. |
| `GOPROXY` | Adapt | `SKILLSGO_HUB_URL` selects one authoritative Hub today; a typed trusted-origin list may come later. |
| `GOSUMDB` | Adapt later | Future CLI configuration needs log name, verifier key, URL/mirror, and an explicit private/off policy. |
| `GOVCS` | Simplify | SkillsGo supports Git only; use a Hub source-host/repository allowlist and hardened Git runner instead of a VCS command language. |
| `GOWORK` | Reject | SkillsGo Workspaces are independent installation scopes, not a composed dependency build list. |

### CLI configuration gaps

The CLI currently has a very small public surface: `SKILLSGO_HUB_URL`, `SKILLSGO_LANG`, and per-command `--hub`, plus platform environment used to locate Agent directories. This simplicity is good, but three capabilities lack a supported contract:

1. **State root override.** Store, Info cache, and user-scope declaration are hard-coded below the OS user's home. Define one `SKILLSGO_HOME` (or equivalent platform-aware config root) rather than separate path variables for every sub-cache. It should move the coherent user state root, not Agent-owned targets.
2. **Hub credentials.** A credential provider must authenticate to a globally protected private Hub without URL userinfo. Secrets should come from OS credential storage, permission-checked files, or narrowly documented non-interactive environment fallback.
3. **Future SumDB trust.** The verifier key is configuration, not server-fetched data. A future setting should bind log name, public key, and URL/mirror with clear `off` and private-log behavior.

Use one precedence rule across commands: explicit flag/config invocation, then environment, then persisted user configuration, then default. Secrets must never be echoed in diagnostics, URLs, plan files, or App machine contracts.

The CLI currently accepts any HTTP or HTTPS Hub URL. Require HTTPS for non-loopback origins by default and expose any development exception explicitly. This is especially important once Basic Auth credentials are sent.

### Hub configuration drift

Hub configuration is typed through TOML plus `SKILLSGO_HUB_*` environment overrides, with useful startup validation for many fields. Three source controls bypass that system through direct `os.Getenv` calls:

- `SKILLSGO_REPOSITORY_TAG_TTL`
- `SKILLSGO_REPOSITORY_MAX_BYTES`
- `SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS`

They are not represented in the main Config, do not consistently use the Hub prefix, and are validated only when an affected code path runs. Move them into typed startup configuration. Replace the private-host boolean with explicit host/CIDR/source policy; a global validation bypass is not a production setting.

The inherited Athens surface still contains configuration that is dead, misleading, or outside the narrowed SkillsGo model:

- `GlobalEndpoint` is marked unimplemented;
- `HGRCPath` and Mercurial auth remain despite Git-only source support;
- `NetworkMode` and `DownloadMode` form the ambiguous matrix described in Task 10;
- comments, error types, request headers, database defaults, and helper tests still use Athens/module/go-binary terminology;
- several storage and distributed-singleflight backends expose large operational matrices before the core immutable storage contract is uniform.

Remove dead settings instead of preserving compatibility. Rename retained settings around SkillsGo domain terms and document whether each is startup-static or dynamically reloadable. Generate a sanitized effective-configuration report that redacts secrets; this is more useful than allowing hidden ad hoc environment behavior.

### Proposed minimal policy surface

Avoid mirroring Go's eleven variables one-for-one. The eventual user/operator model can remain small:

```text
CLI
  SKILLSGO_HOME
  SKILLSGO_HUB_URL
  Hub credential provider
  SumDB trust configuration (future)

Hub
  SourceAccessPolicy + source allowlists/private visibility
  DiscoveryPolicy
  ArtifactMissPolicy
  Hot/cold artifact lifecycle policy
  Global/Admin authentication
  storage/database/task worker configuration
```

Coordinate-specific exceptions should use one validated policy document with ordered rules, not a mix of booleans, HCL mode files, direct environment reads, and implicit provider behavior.

### Disposition

- **Copy:** explicit cache root, secure-by-default transport, independently trusted SumDB verifier configuration, and clear config precedence.
- **Adapt:** one Hub origin instead of `GOPROXY`; trusted visibility/source rules instead of `GOPRIVATE/GONOPROXY`; Git-only execution policy instead of `GOVCS`.
- **Reject:** legacy mode flags, GOPATH/GOWORK analogues, direct CLI VCS bypass, and pattern-based insecure HTTP.
- **Fix:** add a coherent CLI state-root override and credential provider; enforce HTTPS outside loopback.
- **Consolidate:** bring all Hub source limits/policies into typed startup config and replace the inherited mode matrix.
- **Remove:** unimplemented GlobalEndpoint, HGRC/Mercurial support, and stale Athens/Go-binary configuration vocabulary.

### Task 17 review verdict

SkillsGo does not need Go's environment-variable surface. Its current CLI simplicity is an asset, but the missing state-root and credential seams encourage unsafe workarounds. On the Hub, ad hoc environment reads and inherited Athens modes undermine typed configuration. A small orthogonal policy model will be easier to secure and test than continuing to rename legacy switches.

## Task 18 — Glossary and final architecture synthesis

### Coverage of the official reference

The review inventory covers every normative subject area exposed by the Go Modules Reference. The grouping below makes the crosswalk explicit; a row may map to more than one task when the official page combines syntax, resolution, transport, and trust concerns.

| Official Go Modules Reference subject | Review task(s) | SkillsGo result |
| --- | --- | --- |
| Modules, packages, paths, versions, pseudo-versions, major suffixes, package resolution | 01 | Adapt the release/member split; reuse version primitives; reject major suffixes and prefix discovery. |
| `go.mod` lexical elements, grammar, directives, and updates | 02 | Copy declarative-manifest principles, but use a SkillsGo-native structured schema with first-class intent fields. |
| Minimal version selection, upgrades, downgrades, replacement, exclusion | 03 | Reject graph algorithms; define one selector and update-intent model. |
| Graph pruning and lazy module loading | 04 | Adapt to demand-driven publication and independent metadata/ZIP residency. |
| Workspaces and `go.work` | 05 | Keep independent installation scopes; reject build-graph composition. |
| Non-module repositories and `+incompatible` | 06 | Treat pseudo-versions as first class; reject `+incompatible`. |
| Module-aware commands | 07 | Preserve add/restore/verify lifecycle concepts without build commands. |
| Version queries | 08 | Separate movable typed selectors from canonical immutable versions. |
| GOPROXY endpoint protocol | 09 | Keep a Go-shaped `/mod` artifact API without claiming cmd/go compatibility. |
| Proxy communication, fallback, serving, and publication | 10–11 | Keep one Hub authority; enforce source-access policy and create-only publication. |
| VCS discovery, mapping, and direct access | 12 | Keep one hardened Git adapter and Tag catalog; reject CLI VCS fallback. |
| Module ZIP layout and limits | 13 | Keep deterministic per-Skill ZIPs; share bounded cross-platform validation. |
| Private modules and credentials | 14 | Add end-to-end Repository visibility and first-class Hub credentials. |
| Module cache | 15 | Separate content objects, coordinate refs, metadata, and artifact residency. |
| Authentication, `go.sum`, checksum database | 16 | Keep one Skill-relative h1 and reuse the public SumDB stack later. |
| Environment variables | 17 | Keep a minimal typed policy/configuration surface. |
| Glossary | 18 | Establish SkillsGo-native terms and retire false Go equivalences. |

No Go section is an unreviewed implementation obligation. A **Reject** result is deliberate coverage, not an omission.

### Canonical SkillsGo vocabulary

The existing Hub and CLI context glossaries are broadly correct. The following compact vocabulary should be the protocol and implementation source of truth. Existing longer product definitions remain valid where they add lifecycle detail.

| Term | Canonical meaning | Must not mean |
| --- | --- | --- |
| **Repository** / **Source Repository** | The canonical VCS source and version-selection unit. | One installable Skill or a local Workspace. |
| **Repository ID** | The canonical public coordinate of a Repository. | A mutable clone URL spelling or database row ID. |
| **Repository Publication** | The atomic immutable release snapshot for one Repository version and commit, containing the complete accepted member set. | A River job, a Repository ZIP, or partial member uploads. |
| **Repository Release Record** | The canonical immutable bytes/Sum that bind Repository ID, version, commit, and ordered member artifact identities. | Enriched Repository detail or mutable assessment state. |
| **Skill** | One valid `SKILL.md` root and its supporting files inside a Repository Publication. | The whole Repository release unit. |
| **Skill ID** | The canonical member coordinate using the explicit `/-/` boundary. | `SkillPath`, a display name, or a mutable source URL. |
| **Selector** | User intent such as exact version, `latest`, branch, Tag, or commit. | A value safe to persist as the selected version. |
| **Immutable Version** | The canonical semantic or pseudo-version returned after resolution. | A branch, `latest`, or other movable selector. |
| **Skill Artifact** | The immutable installable file set for one Skill at one immutable version. | Its ZIP encoding, Info document, assessment, or installation target. |
| **Skill Info** | Immutable artifact metadata: identity, version, source revision, content-derived metadata, Sum, and archive size. | Current Risk, ranking, translations, or ZIP-residency state. |
| **Sum** | The Go-compatible `h1:` of sorted Skill-relative paths and contents, independent of ZIP prefix and compression. | Commit SHA, Tree SHA, exact ZIP digest, signature, or risk fingerprint. |
| **ZIP Envelope Digest** | Optional digest of the exact restorable ZIP bytes when byte-for-byte envelope authentication is required. | A replacement for Sum or a routine public content identity. |
| **Artifact Residency** | Whether exact ZIP bytes are hot, cold-only, restoring, unavailable, or corrupt. | Whether the immutable publication exists. |
| **Catalog Projection** | Search/discovery state derived from immutable publications plus mutable product metadata. | The publication authority or integrity record. |
| **Risk Assessment** | Append-only scanner evidence attached to an immutable artifact. | A field whose refresh changes authenticated artifact Info. |
| **Backfill Request** | One authenticated admin request containing a duplicate-free list of Repository IDs. | One atomic multi-Repository transaction. |
| **Backfill Run** | One durable per-Repository attempt to publish unprocessed and failed semantic Tags. | A River transport job or interactive CLI add. |
| **Workspace** | A local declaration and installation scope that shares the user Store. | A Go build workspace or composed dependency graph. |
| **Store** | The CLI's verified immutable extracted-content storage. | The Hub's publication database, a mutable Agent directory, or a raw download cache. |
| **Info Cache** | Exact immutable Hub response bytes needed for verification and offline restore. | A mutable resolution result or Workspace membership source. |
| **SumDB Checkpoint** | A signed tree size/root that authorizes one append-only log head. | An artifact signature or Merkle inclusion proof. |

Use **Skill ID**, not `SkillPath`, as the public identity term. Use `path` only for the member's source-tree subdirectory or a filesystem path. Retire `ContentDigest`, `contentSum`, generic `fingerprint`, and maintained `module/package` vocabulary where `Sum`, Repository, Skill, or artifact is the precise term.

### Target data flow

The architecture needs two ingestion triggers and one publication seam. River provides durable orchestration; it does not own publication truth.

```text
Interactive add                          Admin history Backfill
      |                                           |
parse Repository/Skill ID + Selector    validate auth + Repository ID list
      |                                           |
resolve one immutable Repository         create one Backfill Run per Repository
version through the Hub                            |
      |                                  enumerate canonical semantic Tags
      +----------------------+--------------------+
                             |
                   PublishRepositoryVersion
                             |
            fetch one immutable Repository snapshot
                             |
              discover every valid visible Skill
                             |
          build + validate every deterministic Skill ZIP
                             |
       compute Skill-relative h1 and immutable Skill Info
                             |
       durably retain exact ZIPs and Repository release record
                             |
         atomically expose the complete Repository Publication
                             |
              update catalog/search projections asynchronously
                             |
        serve immutable Info/ZIP to the requesting CLI, if any
                             |
             verify h1 -> Store -> sum -> manifest -> targets
```

The shared `PublishRepositoryVersion` operation is the architectural seam. It accepts a canonical Repository ID plus immutable resolved version/source revision and returns one already-existing or newly committed Repository Publication. It must be idempotent, create-only, collision-detecting, visibility-aware, and independent of whether the caller was an HTTP cache miss, interactive add, Backfill Run, retry, or repair operation.

#### Interactive add

1. The CLI parses a canonical Repository or Skill ID and a typed Selector.
2. The Hub resolves the Selector to one canonical immutable Repository version. The CLI persists only this result.
3. If the Repository Publication is missing, the Hub fetches that one snapshot and materializes **all valid member Skill artifacts**, not only the requested member. This is the agreed full-pull behavior for the selected release.
4. The Hub commits all immutable Skill Info, exact ZIPs/cold receipts, and the Repository Release Record before publication becomes visible.
5. The CLI downloads only the requested Skill artifacts, verifies Info and h1, writes the Store and Info Cache, updates `skillsgo.sum` and `skillsgo.mod`, then projects installation targets through the existing transactional lifecycle.

Full-pull is bounded by one selected Repository version during ordinary add. It is not an implicit history crawl and does not make Backfill a CLI option.

#### Repository history Backfill

1. `POST /api/v1/admin/...` accepts multiple Repository IDs and returns one result/run reference per Repository. Duplicate IDs are rejected or normalized away deterministically.
2. The admin route is present only when authentication is configured. Global Basic Auth credentials protect all Hub routes and also authorize admin routes. Otherwise the separate `SKILLSGO_HUB_ADMIN_AUTH_USER` / `SKILLSGO_HUB_ADMIN_AUTH_PASS` pair protects only admin routes. If both complete pairs are set, global credentials win and startup emits a warning without failing. A partial pair is a startup error.
3. River persists scheduling, retries, and recovery. Business state belongs to a Backfill Run, not River job state.
4. Each per-Repository run enumerates canonical semantic-version Tags and calls the ordinary publication seam for every unprocessed or previously failed version. One Repository failure does not roll back another Repository or already committed immutable versions.
5. Historical publications remain downloadable and eligible for exact Content Match. Catalog policy may hide members absent from the current publication without deleting their immutable history.

The API is intentionally not exposed by the CLI. Audit/enrichment is outside this flow and can be added later as a separate consumer of immutable publications.

#### ZIP eviction and restoration

Metadata-only hot residency is safe only after publication owns durable restorable bytes:

1. Publication writes an exact ZIP to authoritative cold storage and verifies its size, Sum, and optional envelope digest before marking it durable.
2. A hot copy may be added for low-latency reads. Access accounting is sampled or batched so downloads do not create a database write per request.
3. The eviction worker deletes only the hot ZIP after an age/quota policy and an atomic cold-copy check. It retains Skill Info, Repository Release Record, SumDB evidence, and catalog history.
4. A ZIP request for a cold-only artifact acquires a per-artifact restore lease/singleflight, streams the cold object into a temporary hot object, revalidates it, atomically publishes the hot copy, and serves it. Concurrent callers share the restoration.
5. Cold loss or verification failure marks the artifact corrupt/unavailable and alerts operators; it must never silently refetch a movable upstream Tag and claim the old publication was restored.

This gives the desired resource savings without weakening “published versions remain downloadable.” Deleting the sole exact ZIP and relying on Git is not eviction; it is discarding the artifact guarantee.

### Required boundaries and state model

The target model needs fewer concepts than the inherited implementation, not more polymorphism:

```text
Immutable publication state
  Repository Release Record
    -> ordered Skill Info records
      -> Skill Sum

Independent artifact residency
  hot | cold_only | restoring | unavailable | corrupt

Mutable projections
  Risk Assessments | enrichment | popularity | search/ranking | access samples
```

These three state families have different mutation and authentication rules. Do not put them back into one `Info` blob or infer ZIP presence from publication existence.

Only four high-level seams are required:

1. **Resolver:** typed Selector to immutable Repository revision using one Tag catalog.
2. **Publisher:** immutable Repository revision to create-only Repository Publication.
3. **Artifact repository:** get/put-if-absent hot and cold ZIPs, report residency, evict hot, restore with verification.
4. **Projection consumers:** catalog, search, assessment, enrichment, access accounting, and future SumDB subscribe to committed publications without controlling their atomicity.

River belongs around the Publisher for Backfill and other durable asynchronous triggers. It should not be visible in protocol domain types, publication idempotency keys, or Backfill business status.

### Duplication and drift ledger

| Current wheel or drift | Target owner | Disposition |
| --- | --- | --- |
| Local proxy path decode/escape | `x/mod/module` plus SkillsGo ID parser | Replace copied escaping; test `/-/` at the SkillsGo boundary. |
| Multiple SemVer/pseudo-version checks | `protocol/version` backed by `x/mod` | Route every selector/version check through one typed package. |
| Vendored Hash1 plus active custom framing | `x/mod/sumdb/dirhash` or one private differential-tested accumulator | Remove the unused public vendored path. |
| Producer/consumer ZIP limits and path checks | One protocol artifact validator | Share limits and collision rules; use bounded streaming. |
| Several Tag namespaces and Git queries | One Repository Tag Catalog | Make resolver, latest, pseudo-base, and Backfill depend on it. |
| Nested/local/distributed singleflight | One publication/restore coordination layer | Use `x/sync/singleflight` locally and storage uniqueness across processes. |
| Backend-dependent overwrite behavior | Immutable artifact repository conformance contract | Add put-if-absent, collision verification, partial-pair, and concurrent tests. |
| Info reopen/re-enrichment on reads | Persisted immutable Info plus separate projections | Read exact committed bytes; enrich asynchronously. |
| `NetworkMode` × `DownloadMode` | SourceAccessPolicy, DiscoveryPolicy, ArtifactMissPolicy | Replace the inherited matrix with orthogonal policy. |
| Custom stale locks and last-writer Info cache | Platform file locks plus immutable create/verify semantics | Simplify around one lock package and idempotent publication. |
| Athens/Go module vocabulary and dead settings | SkillsGo Config and context glossary | Delete or rename on touch; do not preserve compatibility. |

### Prioritized implementation sequence

The following order preserves the new design while avoiding a broad rewrite.

#### Phase 0 — Release-blocking invariants

1. **Close the private-source publication leak.** Add Repository visibility and authorization to source resolution, publication keys, artifact reads, catalog/search, Backfill, and future log routing. Until then, a public Hub must not possess credentials that can read private source.
2. **Make storage publication truly immutable.** Define create-only Skill Info, ZIP, and Repository Release Record operations; verify identical collisions; reject differing bytes; add backend conformance tests for concurrency and partial failure.
3. **Make offline a hard policy.** Move source/network authorization into the resolver/publisher boundary so no Info, ZIP, List, Latest, or queued job can bypass it.
4. **Unify the Tag catalog.** Use one fetched Tag view for exact queries, `latest`, commit canonicalization, pseudo-version ancestry, and Backfill.
5. **Unify and bound artifact validation.** Enforce maximum transport bytes before allocation, bounded `SKILL.md` reads, Unicode/case collisions, portable path rules, and identical producer/consumer limits.

#### Phase 1 — Establish the publication and residency model

1. Split immutable Skill Info and Repository Release Record from Risk/enrichment/product projections.
2. Introduce one idempotent `PublishRepositoryVersion` seam and route ordinary cache misses and Backfill through it.
3. Make ordinary add materialize every valid member of the selected Repository version while the CLI downloads only requested members.
4. Introduce explicit artifact residency and storage methods: `PutHotIfAbsent`, `PutColdIfAbsent`, `State`, `EvictHot`, and `RestoreHot` (names illustrative, behavior normative).
5. Add authenticated multi-Repository Backfill as a Hub admin API with one durable run per Repository and the agreed global/admin Basic Auth precedence.
6. Persist exact immutable Info bytes and stop recomputing enrichment or reopening every member ZIP during reads.

#### Phase 2 — Client and protocol closure

1. Introduce typed Selector and Immutable Version values; close query grammar, branch/Tag ambiguity, `v`-prefix, and unsupported npm-style range behavior.
2. Normalize `/mod` methods, media types, immutable/movable cache headers, status codes, and error bodies without claiming cmd/go compatibility.
3. Add a first-class private-Hub credential provider, require HTTPS outside loopback, and define one CLI state-root override.
4. Make Store objects read-only, harden cross-process Info Cache publication, serialize portable installation mode, and remove dead placeholder commands/actions.
5. Replace direct environment reads and inherited mode/config settings with typed startup policy.

#### Phase 3 — Resource optimization

1. Provision authoritative cold storage and migrate/verify every historical exact ZIP.
2. Implement access sampling, hot quotas/age policy, restore leases, integrity verification, and observability.
3. Enable hot ZIP eviction only after a restore drill proves that every eligible artifact remains downloadable without source access.
4. Add separate CLI Store garbage collection only with complete live-reference discovery, dry run, grace periods, and permanent protection for Local/captured artifacts.

#### Phase 4 — Transparency

1. Freeze canonical immutable Repository Release Record serialization.
2. Remove duplicate Hash1 code and validate all `skillsgo.sum` h1 values through the shared 32-byte validator.
3. Implement SkillsGo storage adapters around `x/mod/sumdb`, `tlog`, and `note`; establish public/private log policy and independently distributed verifier keys.
4. Require inclusion and consistency verification for new public Sums before treating SumDB as a trust boundary.

SumDB is intentionally last. It would otherwise make current storage collisions, mutable Info, or visibility mistakes permanent and globally auditable without first making them correct.

### What not to build now

- no dependency graph, MVS, `replace`, `exclude`, or `go.work` analogue;
- no general multi-origin proxy cascade or direct CLI VCS fallback;
- no audit/enrichment job in the publication transaction;
- no custom Merkle tree, checkpoint signature scheme, h1 fork, or BLAKE3 parallel identity;
- no universal storage abstraction rewrite beyond the immutable operations needed by publication and residency;
- no eviction before authoritative cold restoration is operational;
- no automatic full-history crawl from `add`; history remains an explicit admin Backfill operation.

### Final verdict

The agreed design is not overengineered when implemented in the sequence above. Its essential complexity comes from three promises SkillsGo has chosen to make simultaneously: complete Repository-version publication, independently installable Skill artifacts, and permanent downloadability with bounded hot storage. Those promises require a publication seam, immutable metadata, and explicit artifact residency. They do not require Go's dependency solver, cmd/go compatibility, a second digest, or a large proxy ecosystem.

The highest-value simplification is to make one immutable Repository Publication the center of the system. Interactive add and admin Backfill become two triggers for the same operation; catalog, assessment, enrichment, eviction, and future SumDB become downstream consumers with separate state. That structure preserves the useful parts of Go's protocol while keeping SkillsGo's domain model explicit.

### Task 18 review verdict

The official reference is fully classified, the target data flow is closed, and every deferred mechanism now has a prerequisite. Implementation should begin with visibility, storage immutability, offline enforcement, Tag consistency, and bounded artifact validation. Full-pull add and multi-Repository Backfill then share one Publisher; ZIP eviction follows only after exact cold restoration; SumDB follows only after immutable records and privacy boundaries are stable.

## Hub v1 release compatibility classification

The release decision should freeze interfaces, not implementations. A seam must be settled before public publication when changing it later would alter what an existing coordinate means, invalidate authenticated bytes, require rewriting portable client state, or disclose data irreversibly. Internal adapters and optimizations may continue evolving as long as they preserve those interfaces.

### Must be settled before durable public publication

| Interface to freeze | Decisions required now | Damage if deferred |
| --- | --- | --- |
| **Canonical identity** | Repository ID and Skill ID grammar; `/-/`; host-only versus provider-specific path case normalization; source moves create new IDs. | Existing Catalog rows, URLs, manifests, sums, receipts, and links refer to the wrong identity. Fixing case rules creates duplicates or requires a global key migration. |
| **Version and selector semantics** | Repository-wide versions; pseudo-version rules; distinct `head` and `release` candidates; default add selector; exact pins; one Tag Catalog used by resolution and Backfill. | The same user query changes meaning, incorrect pseudo-versions become permanently published, or a later change to `latest` breaks client behavior. Existing immutable versions cannot be silently reassigned. |
| **Repository Publication membership** | One immutable Repository snapshot, complete accepted member set, full-pull publication, hidden/nested Skill inclusion, and atomic visibility. | A Repository version initially published with a partial member set would need its Repository Info/release record rewritten later, violating immutability. |
| **Skill artifact format** | ZIP root prefix; included file tree; nested Skill treatment; root-License policy; path/case collision rules; regular-file and executable-mode policy; compressed/uncompressed limits as protocol limits. | Rebuilding the same Skill ID/version produces different files or becomes newly invalid on some clients. Existing archives may no longer be extractable under the corrected contract. |
| **Sum contract** | One Skill-relative Go h1, exact path/content framing, prefix removal, and whether modes belong only to an optional envelope digest. | Changing the algorithm or included bytes changes every Sum, invalidates `skillsgo.sum`, Store objects, Content Match, and future transparency records. |
| **Immutable metadata model** | Immutable Skill Info fields; canonical Repository Release Record/member ordering; mutable Risk/enrichment kept outside authenticated bytes; exact resource suffixes used by `skillsgo.sum`. | Splitting mutable fields later changes cached/authenticated Info bytes and Repository sums, requiring a new wire resource/version plus data and client migration. |
| **Immutable publication storage** | Put-if-absent/identical-content semantics, collision rejection, atomic Repository commit, and explicit Info versus ZIP residency. | An already published coordinate may have been overwritten or half-published. No later migration can prove which bytes were originally authoritative. |
| **Public artifact protocol** | Canonical `/mod` coordinate escaping, Repository versus Skill routes, Info/ZIP resource meaning, exact-version behavior, and supported methods. | Clients and cached URLs depend on the old route or response meaning; corrections require parallel protocol versions or coordinated client upgrades. |
| **Workspace Manifest grammar** | The compact native `require ID version [agents] [mode]` grammar, omitted-mode=`symlink`, explicit `copy`, exact-version persistence, and canonical writer behavior. | Released Workspaces require a dual parser/migration. The current inability to serialize `copy` silently loses non-default portable intent. This is a CLI compatibility gate even though it is not Hub storage. |

The implementation may still be replaced behind these seams. For example, Hash1 can move from local framing to `dirhash`, or filesystem storage can be replaced with object storage, if golden/conformance tests prove the same public result.

### Must be safe before production, but need not freeze the public model

These issues do not inherently require a v2 protocol, yet shipping them is operationally unsafe or makes the first data set unreliable:

1. **Bounded, shared ZIP validation.** Enforce the transport limit before allocation, bound `SKILL.md` reads, reject Unicode/case/Windows collisions, and use one producer/consumer contract. Streaming can come later; bounds cannot.
2. **One consistent Tag view.** Resolver, points-at, pseudo-version ancestry, list, and Backfill must not publish from different ref namespaces.
3. **Hardened Git execution.** Controlled configuration/environment, HTTPS-only protocols, non-interactive credentials, source allowlists, SSRF/egress controls, and repository/disk/process limits are required before a public Hub executes Git for arbitrary hosts.
4. **Offline as a real invariant.** If `offline` is exposed, no Info/ZIP miss or queued work may contact VCS. The internal policy implementation may later change.
5. **Update-check freshness.** If update checking ships as a product claim, it must refresh or freshness-cache `head` and `release` once per Repository. A Catalog-only response must identify itself as stale rather than report “current.” This is behavior correctness, not artifact migration.
6. **Transactional whole-Repository add.** Either compensate all local target/Manifest changes on failure or expose accurate partial-success recovery. This is a CLI correctness gate, not a Hub identity gate.
7. **Secure private-Hub transport.** Non-loopback HTTPS and an origin-scoped CLI credential provider are required before globally authenticated private Hub support is advertised.

### Conditional gates: defer the feature, not its prerequisite

| Feature | Safe to defer | Required before enabling it |
| --- | --- | --- |
| Private remote Repositories on a public/mixed Hub | Yes | End-to-end Repository visibility and authorization before source access, publication, reads, Catalog/search, logging, Backfill, and log inclusion. Until then, public Hub credentials must not read private source. |
| Hot ZIP eviction | Yes; retain all ZIPs initially | Authoritative exact cold copy, explicit residency, ZIP-only deletion, restore lease, and restore verification without source access. |
| SumDB | Yes | Frozen immutable Skill Info/Repository Release Record, visibility routing, canonical leaf format, client checkpoint persistence, and inclusion/consistency verification. |
| Automatic tracking updates | Yes | A first-class `track head`, `track release`, or `track branch:<name>` intent. Do not infer it from an exact installed version. Advisory update checking can ship without tracking. |
| Multi-origin Hub fallback | Yes | Typed trusted-origin policy, privacy routing, stop-on-auth semantics, and identical expected Sum verification. |
| Audit/enrichment jobs | Yes | Keep them downstream from committed immutable publications and outside publication atomicity. |

### Internal optimizations that may follow incrementally

- remove duplicate Hash1, pseudo-version regex, path decoder, and ZIP validators **after** output-equivalence tests exist;
- collapse nested/custom singleflight into one local group plus storage uniqueness or an optional distributed lease;
- implement true CLI CAS/deduplication, read-only Store objects, stronger file locks, Info Cache enumeration, and reference-aware CLI GC;
- add file-backed/streaming ZIP generation and download after hard byte limits are already enforced;
- add retries, `Retry-After`, ETags, conditional GET, immutable cache headers, request coalescing, and CDN tuning;
- add Git-cache quotas/TTL/cleanup and sampled artifact access accounting;
- add cold-tier lifecycle policy and eviction workers after the conditional gate is satisfied;
- consolidate typed configuration, remove dead Athens/Mercurial settings, and improve sanitized effective-config diagnostics, subject to ordinary operator configuration migration;
- add explicit `verify`, `why`, cache-warm, and GC commands; remove placeholders and inert flags;
- add search/ranking/enrichment improvements and River worker tuning without changing publication truth.

### Minimum credible Hub v1 cut line

A public-only Hub may launch without private Repository support, eviction, SumDB, automatic tracking, multi-origin fallback, audit, or enrichment. It should not launch durable public publication until canonical identity, head/release/version semantics, Repository membership, artifact/Sum format, immutable metadata, create-only publication, and `/mod` resource meaning are fixed and tested. Security and bounded-input items above must also be operational before accepting arbitrary public Repository coordinates.

## Hub v1 implementation checkpoint — 2026-07-22

The implementation now rejects the ambiguous `latest` selector instead of assigning it an implicit meaning. `head` resolves the Repository default branch, `release` resolves the highest stable canonical semantic-version tag and falls back to the highest pre-release tag, and an omitted CLI selector means `head`. Resolution always produces an immutable semantic or pseudo-version before it is persisted. The Catalog field historically named `latestVersion` remains a recommendation value, not a public selector; it should be renamed separately if the wire model is revised before v1.

The following v1 seams are implemented and covered by focused tests:

- provider-aware canonical Repository and Skill identity, including GitHub path folding and case-preserving non-GitHub paths;
- a native Workspace Manifest parser for `require ID version [agents] [mode]`, with omitted mode defaulting to `symlink` and explicit `copy` preserved;
- one shared artifact traversal and validation contract for producer and consumer, with bounded input, portable-path collision checks, regular-file policy, deterministic ZIP metadata, root-License inheritance, and Skill-relative Go `h1` sums;
- immutable Skill Info separated from deferred mutable Risk/audit data;
- an exact Repository Release Record persisted in the Catalog transaction and returned byte-for-byte by the Repository protocol;
- public `/mod` routes for immutable exact versions plus movable `head` and `release` selectors, with method constraints and cache-control semantics; `/@latest` is intentionally absent;
- a unified canonical Git tag view for release selection, points-at queries, pseudo-version ancestry, list, and Backfill;
- bounded CLI downloads, a real offline miss boundary, controlled Git configuration, non-interactive execution, HTTPS restrictions for canonical remote sources, and repository resource checks;
- an immutable storage membrane that accepts identical repeated publication and rejects different bytes for an existing Info or ZIP coordinate.

The remaining correctness work is deliberately explicit rather than hidden behind the frozen interfaces:

1. create-only object writes are currently process-safe but still need backend-native preconditions for multi-instance publication;
2. public-Hub publication must stop passing GitHub source tokens to Git so that public-only operation cannot accidentally read private Repositories;
3. whole-Repository CLI add still needs one rollback boundary spanning all targets, receipts, sums, and the Manifest;
4. update checking needs one freshness-cached Repository `head`/`release` resolution instead of presenting a Catalog-only value as current;
5. stale Athens/Mercurial configuration and documentation must be removed;
6. complete CLI/Hub unit suites and split-container end-to-end journeys must be added or updated for `head`, `release`, immutable publication, offline behavior, and transactional add.

Hot ZIP eviction is not part of this first safe cut. Metadata-only retention is valid only after an authoritative exact cold artifact copy, explicit residency state, restore coordination, and post-restore Sum verification exist. Until that gate is implemented, published ZIPs remain resident so every immutable coordinate remains downloadable.

## Hub v1 implementation checkpoint 2 — 2026-07-22

The first checkpoint's items 2–6 are now closed. Public Git synchronization is credential-free even when GitHub metadata tokens are configured; whole-Repository add has one rollback boundary across every target and all declaration metadata; update checks resolve fresh `head` and `release` candidates once per Repository; maintained runtime configuration no longer exposes the unused Athens `GlobalEndpoint`; and the split CLI/Hub E2E workspace now contains J46 for whole-Repository atomicity.

The E2E contract was migrated from ambiguous or source-native selectors to the frozen public vocabulary. `latest`, branch names such as `main`, and raw commit hashes are rejected at the CLI boundary. J28 proves omitted selector = `head`, release stable-first selection, prerelease fallback, and explicit `latest` rejection. J32 proves `/@latest` is absent and movable values cannot be smuggled through exact `.info` routes. J43/J44 prove refreshed `head`, immutable historical pseudo-versions, and the untagged-to-tagged transition. J45 proves one batch returns independent Repository-fresh head and release candidates. J46 proves one later target conflict removes all earlier targets and leaves Manifest, Sum, and Receipts absent.

The full E2E run passed 41 unchanged journeys and exposed five obsolete assertions. Those five were migrated and then passed independently: audit is deferred and outside immutable Info; exact selectors are pinned; inventory no longer installs by raw commit; Catalog detail authenticates content with `sum`, not the removed `contentDigest`; and only GitHub Repository paths are case-folded while non-GitHub paths preserve casing. A final full rerun remains required after the remaining code work.

Additional safety and operational improvements are now implemented:

- `--yes` only suppresses interaction and no longer grants replacement authority; a different existing target still requires `--replace`, while an already managed matching member can be updated idempotently.
- CLI Store locks use operating-system `flock` locks rather than stale timestamp files, so process exit releases ownership without unsafe lock stealing.
- Exact Info and ZIP responses have stable strong ETags derived from their immutable coordinate and return 304 for matching conditional GET/HEAD requests.
- CLI immutable GETs retry only 429/502/503/504, at most three attempts, honor bounded `Retry-After`, and never retry terminal 4xx responses.
- The external-storage server applies the immutable write membrane itself, bounds multipart and Info bytes with the shared artifact limit, and returns 409 for conflicting publication.
- E2E Git fixtures no longer depend on ambient global Git configuration. Their source rewrite is explicitly injected by the test-only Git executable, so controlled production Git configuration remains testable.
- The maintained Hub configuration uses `skillsgo-hub.toml` and `/var/lib/skillsgo/home.html`; the Hub image no longer installs Mercurial, Subversion, Fossil, or Git LFS for unsupported source transports.

One launch-significant storage limitation remains open. Native filesystem `PutIfAbsent` is safe across processes and hosts sharing that filesystem, and an external storage service is safe across clients when it has one authoritative server process. GCS already exposes object-generation preconditions, S3 and Azure expose conditional create, Mongo can use its unique coordinate record, but the currently pinned MinIO v6 client does not expose conditional PUT. The generic wrapper prevents conflicts within one Hub process and detects mixed post-write state, but it cannot prevent two Hub instances from racing on a non-native backend. Hub v1 must either implement a backend-native reservation protocol for every advertised multi-instance backend, upgrade/remove unsupported backends, or explicitly reject multi-instance use for them. This is not equivalent to the already-closed immutable filesystem path and must not be reported as complete.

## Hub v1 implementation checkpoint 3 — 2026-07-22

The remaining production-storage ambiguity is closed. The shared immutable-write membrane now exports bounded archive reading and existing-byte comparison primitives, while each supported production backend owns an authoritative create-only decision:

- GCS uses an object generation `DoesNotExist` precondition and verifies existing Info and ZIP bytes on a failed create.
- S3 uses `If-None-Match: *`, recognizes both precondition and conditional-request conflicts, and verifies the winning bytes.
- Azure Blob uses `If-None-Match: *` through the provider ETag condition and treats 409/412 as an existing reservation to verify.
- MongoDB inserts a unique coordinate record containing immutable Info and an archive SHA-256 reservation before GridFS upload. An identical retry can complete a missing ZIP after interruption; different Info or archive bytes conflict.
- The external-storage HTTP server is the single authority for `PutIfAbsent`. It returns 201 for a newly created coordinate, 200 for an identical existing coordinate, and 409 for a conflict; clients no longer rely on a Hub-process-local lock.
- The pinned legacy MinIO v6 client cannot express the required conditional create. Hub v1 configuration therefore rejects `StorageType = "minio"` with an explicit reason instead of advertising unsafe multi-instance semantics. The legacy package remains source history and is not a selectable v1 backend.

The documentation loop also found and removed a real contract contradiction: an earlier ADR sentence and the Hub glossary still said raw commits and arbitrary branches could resolve publicly. The frozen public vocabulary is now consistent everywhere: `head`, `release`, exact canonical semantic versions, and exact canonical pseudo-versions. Raw branches, raw commits, ranges, and `latest` are rejected. Storage now has an F3 module map recording native conditional-write ownership and the immutable collision boundary.

Final verification after these changes is green:

- `go test ./...` passed in the Protocol workspace.
- `go test ./...` passed in the CLI workspace.
- `go test ./...` passed in the Hub workspace, including storage, source, publication, download, and application-router packages.
- `GOWORK=off go test -v -count=1 ./...` passed in the split CLI/Hub E2E workspace in 322.249 seconds. All 46 numbered journeys passed. J28 covers stable-first `release`, prerelease fallback, omitted-selector `head`, ancestor-based pseudo-versions, and explicit `latest` rejection. J32 covers exact protocol immutability and rejects legacy/raw selector routes. J43–J45 cover movable refresh, no-Tag-to-Tag evolution, and Repository-fresh batch update checking. J46 passes `--yes` and proves whole-Repository local rollback without granting replacement authority.

This closes the Hub v1 compatibility and production-safety cut line described by this review. Deferred features remain intentionally deferred rather than partially implemented: audit/enrichment, private source publication, hot ZIP eviction without an authoritative cold copy, and SumDB. Internal improvements such as cross-coordinate CLI CAS deduplication, reference-aware CLI GC, Git-cache lifecycle policy, additional operator commands, and ranking/River tuning may continue behind the frozen interfaces without changing existing coordinates, immutable bytes, Manifest grammar, or `/mod` resources.
