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
A canonical semantic version, `latest`, branch, or commit supplied to an Info request. A semantic-looking branch cannot impersonate a published Tag. The response always names a canonical immutable semantic or pseudo-version; clients persist that result rather than the movable query. HTTP responses addressed by non-canonical movable queries disable intermediary caching so repeating `main` or another branch observes a newly resolved commit, while exact canonical-version resources retain their separate cache policy.
_Avoid_: refresh command, subscription, raw transport URL

**Repository Publication**:
The atomic visibility change that publishes every repository-owned Skill observed at one repository tag and commit. A `SKILL.md` beneath a hidden directory is treated as installed consumer state rather than a repository publication candidate. Invalid or missing visible candidates are omitted without blocking other valid Skills; no partial set of accepted Skill versions becomes visible.
_Avoid_: Repository Batch table, repository ZIP, all-or-nothing source validation

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
The canonical immutable version shared by Repository Info and every Skill Info member observed at one source commit. `latest` selects the highest stable canonical semantic-version Tag, falls back to the highest canonical prerelease Tag, or resolves the default-branch HEAD to a commit-based pseudo-version when no canonical semantic Tag exists. An untagged revision derives its pseudo-version base from the highest canonical semantic-version Tag among its ancestors, so the pseudo-version sorts above that base and below the next tagged version; without an ancestor Tag, it uses the `v0.0.0` form. Exact pseudo-version requests must authenticate their canonical 12-character commit suffix, commit timestamp, and optional ancestor base Tag while preserving a historically generated no-Tag pseudo-version if that commit is tagged later. A member's Git Tree SHA identifies that Skill directory's content for change detection; it never replaces the shared batch version or the pseudo-version's commit suffix.
_Avoid_: per-Skill pseudo-version, Tree-SHA version suffix, mutable `latest` in persisted dependencies

**Published Version**:
An immutable Skill version declared by a canonical semantic-version Git tag. The tag resolves to one commit permanently; moving a previously published tag is a conflict and never overwrites Hub data. A GitHub Release is optional presentation metadata and is not a version signal.
_Avoid_: GitHub Release, mutable branch head, npm-style publish event

**Revision Resolution**:
An explicit, user-triggered resolution of a branch, tag, or commit to one immutable commit and canonical version. Branches may resolve to pseudo-versions, but they do not advance automatically; a user must resolve the branch again to observe a later commit.
_Avoid_: branch subscription, automatic default-branch refresh, mutable artifact

**Skill ID**:
The public canonical identity of a logical Skill, such as `github.com/owner/repository/-/skills/example`. A source or path move creates a new Skill ID; verified migration is an explicit relationship between the old and new IDs rather than hidden identity continuity.
_Avoid_: Skill Identity, Skill Coordinate, opaque database ID, name-only lookup

**Skill Info**:
The single immutable structured metadata resource for one Skill version. It contains canonical identity and version, normalized `SKILL.md` frontmatter, and flat `Ref`, `CommitSHA`, and `TreeSHA` source fields alongside Risk, Content Digest, and Archive Size. Source URL and subdirectory are derived from the Skill ID rather than repeated in an Origin object. The original `SKILL.md` remains authoritative inside the ZIP.
_Avoid_: separate artifact manifest, nested Origin object, repeated source URL, mutable branch response

**Repository Info**:
The immutable metadata resource for one Repository version and commit, embedding the complete Skill Info records for every valid root or nested Skill observed in that source snapshot.
_Avoid_: editorial member list, Repository ZIP, persisted expansion graph

**Immutable Skill Artifact**:
The installable file set for one Skill at one resolved source commit. A branch such as `main` is a movable reference that resolves to an immutable artifact before download and caching.
_Avoid_: live repository directory, mutable cache entry

**Source Presentation**:
Author-maintained Repository or Skill description found in source metadata or a localized source document. It may be displayed and indexed but never replaces the canonical `SKILL.md` in an Immutable Skill Artifact.
_Avoid_: localized README body, translated instructions, generated Skill

**Hub Enrichment**:
Presentation-only Repository Description or Skill Description produced by Hub analysis for one immutable source revision and locale. It belongs to the Hub catalog and may improve discovery or detail views without changing Skill Info, Content Digest, installation, or execution semantics.
_Avoid_: artifact translation, localized Skill version, source rewrite

**Localized Search Document**:
The locale-specific search projection of canonical identity plus localized Repository and Skill descriptions for one Skill. It determines retrieval and ranking text but is not an installable resource.
_Avoid_: localized artifact, translated package, Skill Info

**Enrichment Run**:
One auditable analysis attempt over a specific immutable source revision, analyzer identity, prompt revision, and requested locale set. Its outputs become active only after validation and never overwrite historical run evidence.
_Avoid_: cron result, mutable translation row, artifact scan

**Content Digest**:
The deterministic SHA-256 identity of a normalized Skill artifact. Archive compression has its own digest and must not change the content identity.
_Avoid_: archive hash, Git tree SHA

**Content Match**:
An exact lookup of immutable Hub artifacts by complete Content Digest, optionally ranked by a source hint. It can support a later reviewed association flow for External Installations that are absent from supported locks, but the current lock-backed Batch Takeover does not call the Hub. It never treats matching metadata as evidence of identity.
_Avoid_: fuzzy name match, metadata fingerprint, mutable branch lookup, automatic ownership claim

**Hub Origin**:
The trusted Hub base used to resolve metadata and download an artifact. Clients may use the official service or a self-hosted Origin and still verify content digests.
_Avoid_: Hub account, mirror name

**Trust Level**:
The Hub's statement about source ownership and maintenance, including unverified, community verified, publisher verified, official, warned, and delisted states.
_Avoid_: safety score, popularity rank

**Risk Assessment**:
An append-only assessment bound to an immutable artifact. Re-scanning creates a new assessment rather than overwriting historical evidence.
_Avoid_: mutable Skill status, trust level

**Install Event**:
An idempotent, privacy-limited event reporting that a Skill version was installed for a scope and set of Agents. Install events power aggregate ranking without becoming an account activity log.
_Avoid_: Agent invocation telemetry, user tracking event

**Repository Popularity**:
The source repository's current public star count, recorded as contextual discovery metadata. Every Skill in the same repository shares this repository-level signal; it is not a Skill rating.
_Avoid_: Skill stars, quality score, recommendation score

**Source Updated At**:
The source commit time of an immutable Skill version. It describes when the served source revision changed, not when the Hub fetched, indexed, or audited it.
_Avoid_: Hub update time, cache refresh time, repository API updated_at

**Archive Size**:
The exact byte length of the deterministic ZIP artifact served by the Hub for one immutable Skill version.
_Avoid_: extracted directory size, source repository size, transport-compressed response size

**All-time Ranking**:
The ordering of public Skills by total accepted install events.
_Avoid_: recommendation feed

**Trending Ranking**:
The ordering of public Skills by install events during the latest 24-hour window.
_Avoid_: all-time ranking

**Hot Ranking**:
The ordering of public Skills with at least three accepted installs during the latest rolling hour by standardized growth above their preceding 24-hour hourly baseline. The public metric reports rolling-hour installs and their integer change from that baseline; the normalized score is ordering-only.
_Avoid_: editorial recommendation, trending alias

**Provider Counter Observation**:
One cumulative install counter observed from an external provider during a complete, generation-fenced crawl. It preserves provider provenance and may support later projection, but it is never an accepted install event.
_Avoid_: exact install event, deduplicated cross-provider total
