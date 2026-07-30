---
status: accepted
---

# Distribute Package Artifacts as static Git repositories

ADR-0019 supersedes this decision's complete Source Repository snapshot boundary. Static Git distribution now stores the minimal union of accepted self-contained Skill directory subtrees; all Git object, Pack, tag, Sum, and dumb HTTP decisions remain unchanged.

SkillsGo currently publishes one complete deterministic ZIP for every immutable Package Version. This preserves the Package-level distribution model established by ADR-0010, but stores repeated files once per version even when adjacent versions differ only slightly. At community scale, historical publication and copied Skill collections can make immutable ZIP retention a larger cost than metadata or search. Serving those ZIPs through the Hub application also makes the application origin part of the artifact data path unless a separate artifact redirect is configured.

This proposal changes only the physical representation and transport of a Package Artifact. A Package remains the complete distribution, lock, Scope Package Store, and reconciliation unit. A Package Version remains an immutable safe snapshot of one Source Repository revision. Skills remain selectable members identified by their path inside that snapshot and are never independently archived or installed.

## Context

### Current publication and installation

The Hub resolves a Version Query to a canonical immutable semantic or pseudo-version, discovers the complete accepted Skill membership, builds the minimal safe Git-tracked union of accepted Skill directory subtrees, serializes that tree as a deterministic ZIP, computes its Package `h1:`, and atomically publishes ZIP, Package Info, Catalog identity, and Skill document content. R2 may store the ZIP through its S3-compatible API, but storage selection and public download routing are independent. Without an artifact origin, ZIP bytes flow from R2 through Hub to the CLI. With an artifact origin, only eligible ZIP requests are redirected; Package Info and other Hub reads remain on the Hub origin.

The CLI resolves Package Info, downloads the complete ZIP, validates byte length and Package `h1:`, materializes an authoritative Scope Package Store, and creates projections only for the selected member paths. Workspace Lock persists the immutable Package Version and Package `h1:`. The Package Store, not a downloaded archive or an Agent projection, remains the local authority after installation.

### Required invariants

Any replacement must preserve these invariants:

- one Source Repository maps to one Package in the current source model;
- one Package Version publishes one complete accepted membership and one safe Package Artifact containing the minimal union of those member directory subtrees;
- exact semantic and pseudo-versions remain immutable and independently addressable;
- Backfill may publish historical Versions in any order without rewriting already published identities;
- every Skill's self-contained resources and safe relative symlinks survive installation;
- escaping, absolute, broken, cyclic, or otherwise invalid symlinks never enter the installable Artifact;
- Package Info remains the authoritative immutable membership document;
- Workspace Lock authenticates Package Path, Version, and content independently of the transport encoding;
- the CLI prepares and validates a complete staging Package Store before the existing atomic mutation boundary;
- presentation localization and source document sidecars remain outside the installable Artifact.

### Why standard Git objects fit the Artifact

Git already provides content-addressed Blob and Tree objects, cross-version object reuse, Pack delta compression, Pack indexes, integrity checks, garbage collection, and standard readers and writers. Hub and CLI are both implemented in Go, and go-git exposes the object, Pack, index, repository, and HTTP transport layers without requiring a system Git executable or CGO.

The Artifact is not an upstream repository mirror. The upstream Source Commit may contain entries that Hub's Package safety rules omit. SkillsGo therefore needs a Hub-authored Git object database whose commits identify installable Artifact trees rather than source history.

## Decision

SkillsGo replaces retained per-Version ZIPs with one standard bare Git Artifact Repository per Package. Hub authors the repository, R2 stores its files, Cloudflare distributes it as immutable static content plus small mutable discovery indexes, and CLI uses go-git dumb HTTP support to restore the exact tagged Artifact tree.

The implementation intentionally provides no artifact migration or wire compatibility. Existing R2 objects and Catalog data are disposable and deployments recreate both stores with the new representation.

### Artifact Repository identity

The Artifact Repository URL is derived from the canonical Package Path under one deployment-discovered origin:

```text
{ArtifactOrigin}/packages/{packagePath}
```

For example:

```text
Package Path: github.com/mattpocock/skills
Repository:   https://cdn.skillsgo.ai/packages/github.com/mattpocock/skills
```

Package Info does not enumerate Pack offsets, object locations, or delta bases. Git owns those physical details. Package Info exposes the complete Artifact Repository URL; Package Path determines the repository location and immutable Version determines the tag.

### Artifact commits

Every published Package Version creates one synthetic, parentless Artifact commit:

```text
refs/tags/v1.0.0
  -> Artifact Commit A
     -> Safe Artifact Tree T1

refs/tags/v1.1.0
  -> Artifact Commit B
     -> Safe Artifact Tree T2

refs/tags/v0.0.0-20260729123000-abcdef123456
  -> Artifact Commit C
     -> Safe Artifact Tree T3
```

Artifact commits have no parent. Parentless commits make every Version independently reachable, allow Backfill to publish Versions in any order, and prevent a later historical publication from changing the identity of a previously published descendant. Lack of ancestry does not duplicate unchanged Blobs or Trees in one object database and does not prevent Pack delta compression across similar objects.

Each Version uses an immutable lightweight tag at `refs/tags/{canonicalVersion}`. Annotated tag objects, branches, upstream refs, and upstream commit history are not retained. Moving an existing published tag to another Artifact commit is an immutable conflict.

### Deterministic Artifact identity

Source Commit and Artifact Commit are distinct identities:

- Source Commit and Source Tree identify provenance and remain Hub Catalog facts.
- Artifact Commit and Artifact Tree identify the normalized installable snapshot distributed to CLI.

Hub creates the Artifact Tree only after applying the existing tracked-file, path, symlink, size, and membership rules. Artifact commit encoding is deterministic:

- no parent;
- fixed author and committer identity;
- source commit time with a fixed timezone;
- fixed commit-message grammar containing canonical Package Path and Version;
- deterministic file modes and Tree ordering;
- no Hub publication time, database identifier, host name, random value, or storage location.

Repeated materialization of the same Package Version from the same accepted source snapshot must produce the same Artifact Tree and Artifact commit IDs.

### Package Info and Package Sum

Package Info remains the immutable SkillsGo distribution document. It continues to carry Package Path, canonical Version, source commit time, Package Sum, and complete path-ordered `{name, path}` Skill membership. It does not become a file manifest and does not duplicate Git refs or object indexes.

Package Info schema version 2 removes `ArchiveSize` and adds `artifactRepository` because no independent archive exists and one Pack may serve several Versions. Each fetched Pack has its own transport size, and CLI derives progress from actual dumb-HTTP response bytes relative to its local cache.

Package `h1:` remains the Workspace Lock integrity identity. Git object IDs authenticate Git objects, while Package `h1:` authenticates the normalized file set under its Package Path and immutable Version. The shared Protocol implementation will compute the same Package `h1:` directly from an ordered Artifact tree or verified Scope Package Store instead of requiring ZIP bytes. Hub computes it before publication; CLI recomputes it after staging and before commit.

### Static dumb HTTP distribution

The public repository uses standard Git dumb HTTP layout. At minimum, Cloudflare-backed R2 serves:

```text
HEAD
packed-refs or refs/tags/*
info/refs
objects/info/packs
objects/pack/pack-*.pack
objects/pack/pack-*.idx
```

`info/refs` and `objects/info/packs` provide the auxiliary discovery state normally produced by `git update-server-info`. Pack and index names are content-derived, immutable, and cacheable for one year. Ref and discovery files are small mutable publication pointers and use revalidation rather than immutable caching.

Smart HTTP is not required for the first release. R2 cannot execute `git-upload-pack`, and placing that operation on application compute would return Artifact payload and dynamic work to the application origin. Dumb HTTP permits Cloudflare and R2 to serve repository files without a Git-aware process in the request path.

CLI uses a pinned go-git v6 version with dumb HTTP explicitly enabled. No user-installed Git executable and no libgit2 or CGO dependency is introduced. If go-git v6 cannot satisfy the validation gates, the fallback under consideration is a narrow read-only dumb HTTP adapter over go-git v5 Pack and object APIs, not a new SkillsGo Pack format.

### Hub publication transaction

Hub publication prepares a new Artifact generation without exposing partial refs:

1. Resolve the source revision and construct the validated safe Artifact tree.
2. Compute Package `h1:` and complete Skill membership from the same accepted file set.
3. Write missing Git Blobs and Trees into a local staging object database.
4. Create the deterministic parentless Artifact commit and lightweight Version tag.
5. Generate and verify Pack and index files.
6. Upload new immutable Pack and index objects to R2.
7. Verify uploaded object size, checksum, index readability, tag closure, and complete Artifact Tree restoration.
8. Publish new `objects/info/packs` and ref discovery content so no visible tag references an unavailable object.
9. Commit Package Version, Package Info, membership, source provenance, and publication visibility in PostgreSQL.

The implementation must define recovery for the two external publication boundaries. An uploaded but undiscoverable Pack is safe orphaned data eligible for later collection. A discoverable tag whose Catalog transaction failed must either be completed idempotently with the same immutable facts or removed before it is advertised by Hub Package Info. Publication retries compare all source, Artifact, Sum, and membership identities and never silently move a tag.

### Incremental Packs and repacking

The first implementation writes one self-contained incremental Pack for only the loose objects created by a publication:

```text
pack-base.pack
pack-increment-001.pack
pack-increment-002.pack
```

Hub computes each candidate object ID before storage, writes only missing Blobs, Trees, and the new parentless commit as loose objects, and passes exactly those object IDs to go-git's standard Pack encoder. The encoder may delta-compress only within that selected object set, so every incremental Pack contains any delta bases it requires. After the Pack and index close successfully, Hub removes the corresponding loose copies. Existing Packs are neither rewritten nor uploaded again. R2 publication verifies immutable objects by key and size, uploads only absent immutable files, then refreshes the small mutable discovery files.

The first Pack in an empty Artifact Repository uses a Pack Window of 5. Five-repository local benchmarks repeated five times measured a 14.1% aggregate initial-Pack wall-time reduction for a 0.15% total Pack-size increase relative to the go-git default. Once any Pack exists, incremental publication retains the configured go-git Pack Window because normal first-parent increments are already small and did not show a stable timing improvement. Full compaction also retains go-git's configured default.

Unchanged Blobs and Trees remain single Git objects. A warm CLI cache requests only an incremental Pack whose index contains an object missing from the requested tag closure. A cold client may need a base Pack and multiple increments, so Hub periodically compacts every reachable tagged object into one replacement base Pack. Compaction improves final storage through cross-generation delta selection and bounds cold request amplification, but is not part of every publication.

Compaction is triggered asynchronously when either Pack count or incremental bytes cross an operator threshold. The initial operating policy starts with 16 incremental Packs or incremental bytes greater than 25% of the current base Pack, then tunes those values from production telemetry. Publication remains correct without compaction; compaction is an optimization, not a prerequisite for Version visibility.

Repacking is never performed in an interactive download request. It follows an immutable generation switch:

1. Build and verify the replacement Pack and index from every tagged Artifact commit.
2. Upload replacement immutable objects.
3. Publish a new `objects/info/packs` generation.
4. Retain old Packs for a measured grace period covering stale CDN indexes and active clients.
5. Delete old Packs only after observability confirms the new generation is healthy and no supported index can reference them.

Compaction must preserve every published tag, Artifact Tree, and Package `h1:`. It changes only physical Pack encoding.

The five-repository POC measured 132 publishable snapshots. Repacking and uploading the full repository after every Version transferred 1,172,086,760 bytes, while self-contained increments transferred 93,211,672 bytes, a 92.0% reduction. The uncompacted repositories occupied the same 93,211,672 bytes; one final compaction reduced them to 60,673,328 bytes. Detailed method and per-repository results are recorded in `docs/research/git-artifact-pack-benchmark.md`.

### CLI materialization

Confirmed installation or update follows this flow:

1. Resolve Package Info through Hub and obtain a canonical immutable Version.
2. Derive the Artifact Repository URL and fetch `refs/tags/{version}` through Cloudflare.
3. Reuse locally cached immutable Packs and download only missing repository files selected by the dumb HTTP implementation.
4. Resolve the tagged Artifact commit and restore its complete Tree into a new staging Package Store.
5. Enforce path, entry-count, expanded-size, file-size, mode, duplicate-path, case-collision, and symlink safety limits during restoration even though Hub already validated publication.
6. Compute Package `h1:` from the staged tree and compare it with Package Info and Workspace Lock.
7. Verify every selected Skill Path against Package Info membership.
8. Hand the verified staging Store to the existing Package reconciliation and atomic projection transaction.

The Git download cache is disposable and may be shared across Scopes. Scope Package Stores remain independent authoritative copies as required by the current CLI model. A cache hit never permits skipping Package `h1:` or Store verification.

## Implementation plan

### Phase 0: measurement baseline

Before changing a protocol, record the current ZIP baseline over the agreed representative repositories and a larger sampled corpus:

- total retained ZIP bytes across published Versions;
- unique uncompressed file-content bytes;
- duplicate rate within one Package across Versions;
- duplicate rate across Packages and forks;
- median and percentile files, bytes, versions, and binary share per Package;
- cold install and one-Version update download bytes;
- Hub CPU, memory, R2 operations, application-origin egress, and installation latency.

Cross-Package duplication is recorded separately because one bare repository per Package does not deduplicate objects across Packages.

### Phase 1: isolated Artifact Repository proof of concept

Build a disposable experiment outside production publication that:

- converts each accepted safe Package tree into deterministic go-git Blob and Tree objects;
- creates one parentless deterministic commit and lightweight Version tag;
- publishes several semantic and pseudo-versions in nonchronological order;
- generates standard Pack, index, `info/refs`, and `objects/info/packs` files;
- serves the directory through a plain static HTTP server with semantics matching Cloudflare;
- clones or fetches exact tags with pinned go-git v6 dumb HTTP;
- restores the complete Package Store and reproduces the current Package `h1:`;
- proves invalid symlinks and paths remain excluded;
- tests interrupted fetches, corrupt Pack/index data, missing objects, stale discovery files, and concurrent Version publication;
- measures full ZIP history versus bare repository size before and after repack;
- measures cold fetch, cached update fetch, memory, request count, and restored-tree time.

The initial repository set includes `anthropics/skills`, `mattpocock/skills`, `vercel-labs/agent-skills`, `garrytan/gstack`, and `microsoft/azure-skills`, plus fork-heavy and binary-heavy samples from the broader corpus.

### Phase 2: Cloudflare and R2 validation

Publish POC repositories under a nonproduction R2 prefix and Cloudflare hostname. Validate:

- range and complete Pack behavior through the actual CDN;
- cache keys and cache headers for immutable Pack/index files;
- revalidation behavior for `info/refs` and `objects/info/packs`;
- stale-index behavior during generation switching;
- R2 Class A/Class B operations and Cloudflare-to-R2 behavior;
- cold and warm regional latency;
- large-Pack timeout and retry behavior;
- whether go-git downloads unrelated Packs under dumb HTTP;
- origin shielding and whether any Artifact payload reaches application compute.

The ADR cannot advance to accepted if cold or update download amplification materially erases the storage and application-compute savings.

### Direct replacement implementation

This decision is implemented as a clean replacement because the deployment explicitly permits deleting the Catalog and object-store contents. There is no dual-write, read fallback, feature flag, compatibility window, or data migration.

1. Reset the Catalog with the consolidated initial migration and delete every object under the configured Artifact bucket/root.
2. Require every storage backend to implement exactly two capabilities: complete static bare-Git repository replication and content-addressed Skill Markdown persistence.
3. Remove version-directory listing, Info objects, ZIP objects, archive writes, deletes, storage catalog enumeration, and their HTTP routes.
4. Make Catalog the sole owner of Package Version identity, membership, version listing, and Package Info generation.
5. Publish Git objects and Skill content before committing Catalog visibility; serialize a Package across instances with a PostgreSQL advisory lock and perform the Catalog transaction through the same locked connection.
6. Require Package Info to contain `artifactRepository`; the CLI has no ZIP fallback and restores only the exact immutable Git tag.
7. Validate the restored ordered tree against the coordinate-bound Package `h1:` before committing a Package Store transaction.

### Operational hardening

After direct replacement:

- schedule repack according to measured Pack count and amplification rather than a fixed unvalidated cadence;
- audit every tag closure and sampled Package `h1:` restoration continuously;
- enforce R2 lifecycle rules only for proven orphan or superseded-generation Packs;
- retain generation-switch diagnostics sufficient to recover stale CDN behavior;
- publish dashboards and alerts for missing refs, missing Packs, corrupt indexes, repack failures, cache amplification, and CLI integrity failures;
- reevaluate a global object pool only if measured cross-Package duplication justifies its additional ownership and garbage-collection complexity.

## Validation gates

The ADR may move from proposed to accepted only when all of these conditions are demonstrated:

- deterministic Artifact commits and Trees reproduce across independent runs;
- semantic and pseudo-version tags remain immutable under concurrent publication and Backfill;
- Git restoration reproduces the Package `h1:` and accepted file set authored from the source tree;
- go-git v6 dumb HTTP is stable under supported operating systems and architectures, or a bounded fallback adapter is approved;
- Cloudflare/R2 static serving never requires application compute for Artifact payload;
- cold-install and cached-update amplification are within an explicitly accepted budget;
- Pack count and background repack can be bounded without breaking stale clients;
- crash recovery cannot expose a tag whose objects are unavailable;
- CLI safety limits prevent path escape, unsafe symlinks, excessive expansion, and partial Store publication;
- all configured storage backends satisfy the same executable Git Repository and Skill-content compliance contract.

## Considered options

### Retain immutable ZIPs and rely only on R2 plus CDN

This removes application-origin payload egress when redirects are complete and preserves the simplest client, but it retains one full compressed archive per Version and cannot reuse unchanged or similar files across Versions.

### Store Git Packs but define a custom SkillsGo manifest and object protocol

This permits precise range requests and global object placement but duplicates capabilities already present in Git refs, Trees, Pack indexes, and delta decoding. It creates a new long-lived storage protocol, compaction contract, and client decoder before standard Git transport has been disproven.

### Preserve complete upstream Git history

Mirroring upstream repositories retains commits unrelated to published Package Versions, preserves unsafe source trees, couples storage to force-push and history behavior, and makes Hub publication identity ambiguous. SkillsGo needs accepted Artifact snapshots, not source-host mirroring.

### Link Artifact commits through parent history

A parent chain makes Backfill order affect descendant commit identity and introduces ancestor reachability that Package Version installation does not need. It provides negligible compression benefit because object reuse and Pack delta selection do not require commit ancestry.

### Use Smart HTTP from the Application Origin

Smart negotiation can minimize transferred objects but requires a Git-aware request-time service and returns Artifact payload or dynamic Pack compute to the application origin. It conflicts with the objective of making Cloudflare and R2 the normal Artifact data path.

### Use system Git or git2go

System Git introduces an undeclared host dependency and inconsistent platform behavior. git2go introduces libgit2, CGO, and multi-platform native release complexity. A pure-Go Hub and CLI path is preferred.

### Build one global Git object database

A global pool could deduplicate copied content across Packages, but it couples Package retention, reachability, publication, compaction, and deletion. One repository per Package first captures cross-Version savings with standard Git ownership boundaries. Global deduplication requires separate evidence and a later decision.

## Consequences

The primary benefit is that unchanged Blobs and Trees are stored once per Package, similar changed files can use Git Pack deltas, cached clients can reuse existing repository data, and normal Artifact payload moves from application compute to Cloudflare-backed R2. ZIP generation, storage, redirect, reconstruction, and extraction-specific transport code can eventually be removed.

The design deliberately does not deduplicate equal content across different Packages or forks. Dumb HTTP may download more data than Smart HTTP, particularly before repack or for cold clients. Small mutable ref and Pack-list files require careful cache control and publication ordering. Background repack and generation cleanup become production responsibilities. go-git v6 maturity is a dependency risk and must be validated rather than assumed.

Package identity, membership, locks, Scope Package Stores, projections, update boundaries, and localization remain unchanged. Package Info remains a domain document rather than a Git manifest. Git is the immutable Artifact encoding and transport, not a replacement for the Hub Catalog or Package model.
