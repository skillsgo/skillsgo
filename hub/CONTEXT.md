# SkillsGo Hub

The Hub context turns public Skill sources into stable identities and immutable artifacts, then serves discovery and distribution APIs.

## Language

**Skill**:
A set of Agent instructions and supporting resources rooted at a valid `SKILL.md`. A Skill's name and description are mutable metadata, not its identity.
_Avoid_: plugin, application, extension

**Skill Source**:
A GitHub, GitLab, well-known endpoint, or other supported public source containing a `SKILL.md` and its resources.
_Avoid_: Hub-owned repository, cloud Skill

**Source Repository**:
A public version-control repository registered with the Hub under a canonical, case-normalized host and arbitrary-depth repository path. It is the unit of demand-driven remote version discovery; Skill paths inside it retain their source-tree casing.
_Avoid_: Skill ID, repository URL spelling, refresh schedule

**Version Query**:
An add-time Git revision such as a canonical semantic Tag, branch name, or commit hash, or an exact canonical immutable semantic/pseudo-version. A movable revision resolves once to a commit and immutable version; only that immutable version is persisted and accepted by exact Repository Proxy resources. The ambiguous `latest` and version ranges are rejected.
_Avoid_: persisted branch, `latest`, version range, refresh subscription, raw transport URL

**Repository Proxy**:
The Go-proxy-shaped immutable distribution surface rooted directly at the Artifact Origin. A Repository resource uses `/<escaped-repository-id>/@v/...` without a product namespace prefix; `/api/v1` remains reserved for product APIs and takes routing precedence.
_Avoid_: `/mod`, product API, Skill ZIP endpoint

**Repository Publication**:
The atomic visibility change that publishes one immutable Repository Release, its complete accepted Skill membership, one Repository ZIP, and one Repository Sum for a resolved source commit. A `SKILL.md` beneath a hidden directory is treated as installed consumer state rather than a publication candidate; no partial accepted membership becomes visible.
_Avoid_: per-Skill publication, Repository Batch table, all-or-nothing source validation

**Repository History Backfill**:
An authenticated Hub administration operation that accepts one or more Source Repositories and incrementally publishes every canonical semantic-version Tag without changing demand-driven installation behavior. Each Repository owns an independent durable run that commits valid versions and retains diagnosable partial failures.
_Avoid_: add option, commit crawl, branch subscription, automatic repository refresh

**Backfill Request**:
A bounded administration request that validates and submits a duplicate-free set of Source Repositories while preserving one independent Backfill Run and result per Repository.
_Avoid_: Backfill Run, atomic multi-repository import, combined repository status

**Backfill Run**:
One durable, deduplicated attempt to publish unprocessed and previously failed semantic-version Tags for a Source Repository. Its business status is queued, running, complete, or complete with errors and is independent of River's transport state.
_Avoid_: River job, atomic repository import, installation request

**Historical Publication**:
An immutable Repository Publication created by Repository History Backfill that remains downloadable and eligible for Content Match without making a Skill absent from the current publication visible in discovery or rankings.
_Avoid_: current catalog entry, archived metadata, resurrected Skill

**Repository Batch Version**:
The canonical immutable version shared by Repository Info and every Skill Info member observed at one source commit. `release` selects the highest stable canonical semantic-version Tag and falls back to the highest canonical pre-release; `head` resolves the default-branch HEAD to a commit-based pseudo-version. An untagged revision derives its pseudo-version base from the highest canonical semantic-version Tag among its ancestors, so the pseudo-version sorts above that base and below the next tagged version; without an ancestor Tag, it uses the `v0.0.0` form. Exact pseudo-version requests must authenticate their canonical 12-character commit suffix, commit timestamp, and optional ancestor base Tag while preserving a historically generated no-Tag pseudo-version if that commit is tagged later. A member's Git Tree SHA identifies that Skill directory's content for change detection; it never replaces the shared batch version or the pseudo-version's commit suffix.
_Avoid_: per-Skill pseudo-version, Tree-SHA version suffix, mutable selector in persisted dependencies

**Published Version**:
An immutable Skill version declared by a canonical semantic-version Git tag. The tag resolves to one commit permanently; moving a previously published tag is a conflict and never overwrites Hub data. A GitHub Release is optional presentation metadata and is not a version signal.
_Avoid_: GitHub Release, mutable branch head, npm-style publish event

**Revision Resolution**:
An explicit add-time resolution of a semantic Tag, branch, commit hash, or exact canonical semantic/pseudo-version to one immutable commit and canonical version. Branches may advance between requests, but each result names an immutable version that never advances; install and exact artifact reads never resolve the movable input again.
_Avoid_: branch subscription, persisted branch, mutable artifact

**Skill ID**:
The public canonical identity of a logical Skill, such as `github.com/owner/repository/-/skills/example`. A source or path move creates a new Skill ID; verified migration is an explicit relationship between the old and new IDs rather than hidden identity continuity.
_Avoid_: Skill Identity, Skill Coordinate, opaque database ID, name-only lookup

**Skill Info**:
The immutable member metadata for one Skill observed in a Repository Release. It contains canonical Skill identity, Repository ID and version, source-relative path, normalized `SKILL.md` frontmatter, and source tree identity, but no independent ZIP, archive size, or artifact Sum. Mutable Risk/audit evidence is excluded and belongs to a downstream assessment resource.
_Avoid_: Skill artifact, Skill ZIP, Skill Sum, mutable branch response

**Repository Info**:
The immutable metadata resource for one Repository version and commit, including Repository Sum, archive size, and the complete ordered Skill Info membership observed in that source snapshot.
_Avoid_: editorial member list, per-Skill artifact manifest, persisted expansion graph

**Repository Artifact**:
The complete safe Git-tracked regular-file tree for one immutable Repository Version, distributed as one ZIP and authenticated by one Repository Sum. Skills are selectable members of this artifact rather than independently archived artifacts.
_Avoid_: Skill artifact, live repository directory, mutable cache entry

**Source Presentation**:
Author-maintained Repository or Skill description found in source metadata or a localized source document. It may be displayed and indexed but never replaces the canonical `SKILL.md` member in a Repository Artifact.
_Avoid_: localized README body, translated instructions, generated Skill

**Hub Enrichment**:
Presentation-only Repository Description or Skill Description produced by Hub analysis for one immutable source revision and locale. It belongs to the Hub catalog and may improve discovery or detail views without changing Skill Info, Sum, installation, or execution semantics.
_Avoid_: artifact translation, localized Skill version, source rewrite

**Localized Search Document**:
The locale-specific search projection of canonical identity plus localized Repository and Skill descriptions for one Skill. It determines retrieval and ranking text but is not an installable resource.
_Avoid_: localized artifact, translated package, Skill Info

**Enrichment Run**:
One auditable analysis attempt over a specific immutable source revision, analyzer identity, prompt revision, and requested locale set. Its outputs become active only after validation and never overwrite historical run evidence.
_Avoid_: cron result, mutable translation row, artifact scan

**Sum**:
The deterministic Go-compatible `h1:` identity of a normalized Repository Artifact. It uses Go `dirhash.Hash1` over sorted relative file paths and contents after removing the archive's `<repositoryId>@<version>/` root, so archive compression and public coordinates do not change content identity.
_Avoid_: archive hash, Git tree SHA

**Content Match**:
An exact lookup of immutable Hub artifacts by complete Sum, optionally ranked by a source hint. It can support a later reviewed association flow for External Installations that are absent from supported locks, but the current lock-backed Batch Takeover does not call the Hub. It never treats matching metadata as evidence of identity.
_Avoid_: fuzzy name match, metadata fingerprint, mutable branch lookup, automatic ownership claim

**Hub Origin**:
The trusted Hub base used to resolve metadata and download an artifact. Clients may use the official service or a self-hosted Origin and still verify sums.
_Avoid_: Hub account, mirror name

**Trust Level**:
The Hub's statement about source ownership and maintenance, including unverified, community verified, publisher verified, official, warned, and delisted states.
_Avoid_: safety score, popularity rank

**Risk Assessment**:
An append-only downstream assessment bound to an immutable artifact Sum. It is not part of publication atomicity or immutable Skill Info; re-scanning creates a new assessment rather than overwriting historical evidence.
_Avoid_: mutable Skill status, trust level

**Cloud Deployment Discovery**:
The minimal public Hub declaration containing `mode` and, only in Cloud mode, the configured Cloud origin. It selects the independent Cloud data plane without becoming a capability-negotiation protocol.
_Avoid_: capability matrix, Cloud proxy, shared database

**Repository Popularity**:
The source repository's current public star count, recorded as contextual discovery metadata. Every Skill in the same repository shares this repository-level signal; it is not a Skill rating.
_Avoid_: Skill stars, quality score, recommendation score

**Source Updated At**:
The source commit time of an immutable Skill version. It describes when the served source revision changed, not when the Hub fetched, indexed, or audited it.
_Avoid_: Hub update time, cache refresh time, repository API updated_at

**Archive Size**:
The exact byte length of the deterministic Repository ZIP served by the Hub for one immutable Repository Version.
_Avoid_: extracted directory size, source repository size, transport-compressed response size
