# SkillsGo Hub

The Hub context turns public Skill sources into stable identities and immutable artifacts, then serves discovery and distribution APIs.

## Language

**Skill**:
A set of Agent instructions and supporting resources rooted at a valid `SKILL.md`. Its canonical Skill Name identifies the member within a Module; its display title and description are presentation metadata.
_Avoid_: plugin, application, extension

**Skill Name**:
The canonical, normalized name declared by `SKILL.md`. Together with Module Path it identifies a logical ranking and default-selection group across Module Versions, but it is not unique inside a Module Publication. A name-only selection resolves deterministically to the lexicographically first Skill Path.
_Avoid_: display title, source directory name, global name, Skill ID

**Skill Path**:
The normalized Module-relative directory containing one member's `SKILL.md`. It uniquely identifies membership within a Module Publication and is the exact selector persisted when a product surface installs a specific result. Same-name members at distinct paths retain independent metadata.
_Avoid_: Skill Name, display path, generated suffix

**Skill Source**:
A GitHub, GitLab, well-known endpoint, or other supported public source containing a `SKILL.md` and its resources.
_Avoid_: Hub-owned repository, cloud Skill

**Module**:
The Hub distribution unit named by a canonical Module Path. A Module owns an ordered history of immutable Versions, and each Version owns the complete Skill snapshots discovered in that source revision. In the current source model, one Module is backed by exactly one Source Repository and one Source Repository maps to exactly one Module.
_Avoid_: Source Repository, Skill collection projection, provider

**Module Path**:
The canonical slash-separated identity of a Module, such as `github.com/acme/skills`. It is a logical distribution coordinate; its Git-host-shaped spelling does not make the Module itself a Repository.
_Avoid_: Repository ID, clone URL, database row ID

**Source Repository**:
A public version-control repository registered as the source of one Module under a canonical, case-normalized host and arbitrary-depth repository path. It is the unit of remote revision discovery; Skill paths inside it retain their source-tree casing.
_Avoid_: Module, Skill ID, repository URL spelling, refresh schedule

**Source Path**:
The canonical host-relative path of a Module's Source Repository, such as `acme/skills`. Together with Source Host it locates the repository, while Module Path remains the public distribution identity.
_Avoid_: Module Path, clone URL, Skill Path, repository URL

**Version Query**:
An add-time Go-compatible query: an exact semantic version, semantic-version prefix or comparison, `latest`, branch, Tag, or commit. Every query resolves once to a canonical immutable semantic or pseudo-version; only that immutable result is persisted and accepted by exact Module Version resources. The `go get`-specific `upgrade`, `patch`, and `none` operations are outside this stateless resolution contract, and SkillsGo defines no ambiguous `head` alias.
_Avoid_: persisted branch, `latest`, version range, refresh subscription, raw transport URL

**Module Distribution API**:
The immutable distribution surface rooted at `/api/v1/{modulePath}`. It exposes `/api/v1/{modulePath}/versions`, `/api/v1/{modulePath}/versions/{version}`, and `/api/v1/{modulePath}/versions/{version}.zip`.
_Avoid_: Go Proxy, `/mod`, `@v`, product API, Skill ZIP endpoint

**Module Publication**:
The atomic visibility change that publishes one immutable Module Version, its complete accepted Skill membership, one Module ZIP, and one Module Sum for a resolved source commit. A `SKILL.md` beneath a hidden directory is treated as installed consumer state rather than a publication candidate; no partial accepted membership becomes visible.
_Avoid_: per-Skill publication, Repository Batch table, all-or-nothing source validation

**Module History Backfill**:
An authenticated Hub administration operation that accepts one or more Module Paths and incrementally publishes every canonical semantic-version Tag discovered from each Module's Source Repository. Each Module owns an independent durable run that commits valid versions and retains diagnosable partial failures.
_Avoid_: add option, commit crawl, branch subscription, automatic repository refresh

**Backfill Request**:
A bounded administration request that validates and submits a duplicate-free set of Module Paths while preserving one independent Backfill Run and result per Module.
_Avoid_: Backfill Run, atomic multi-repository import, combined repository status

**Backfill Run**:
One durable, deduplicated attempt to publish unprocessed and previously failed semantic-version Tags for a Source Repository. Its business status is queued, running, complete, or complete with errors and is independent of River's transport state.
_Avoid_: River job, atomic repository import, installation request

**Historical Publication**:
An immutable Module Publication created by Module History Backfill that remains exactly downloadable without making a Skill absent from the current publication visible in discovery or rankings.
_Avoid_: current catalog entry, archived metadata, resurrected Skill

**Module Version**:
An immutable snapshot of one Module at one source commit, including its canonical version, source ref, commit and root tree identities, Sum, archive size, commit time, and complete Skill membership. `latest` selects the highest stable canonical semantic-version Tag, falls back to the highest canonical pre-release, then falls back to the default-branch tip when no canonical Tags exist. An untagged revision derives its pseudo-version base from the highest canonical semantic-version Tag among its ancestors. A canonical semantic-version Tag resolves to one commit permanently; moving a published Tag is a conflict.
_Avoid_: Skill version, GitHub Release, mutable branch head, npm-style publish event

**Version Query Resolution**:
An explicit add-time resolution of a semantic Tag, branch, commit hash, or exact canonical semantic/pseudo-version to one immutable commit and canonical version. Branches may advance between requests, but each result names an immutable version that never advances; install and exact artifact reads never resolve the movable input again.
_Avoid_: branch subscription, persisted branch, mutable artifact

**Module Info**:
The standalone deterministic metadata resource for one Module Version. It contains schema kind, Module Path, canonical Version, commit time, Module Sum, archive size, and the complete path-ordered `{name, path}` Skill membership. Source ref, commit/tree identities, descriptions, `SKILL.md` frontmatter, mutable assessments, and source enrichment remain outside this distribution document.
_Avoid_: database record dump, Skill Info document, editorial member list, per-Skill artifact manifest

**Module Artifact**:
The complete safe Git-tracked tree for one immutable Module Version, distributed as one ZIP and authenticated by one Module Sum. Relative symlinks whose fully resolved targets remain inside the same Module are preserved; escaping, absolute, broken, cyclic, and otherwise invalid symlinks are omitted. Skills are selectable members of this artifact rather than independently archived artifacts.
_Avoid_: Skill artifact, live repository directory, mutable cache entry

**Source Presentation**:
Author-maintained Source Repository or Skill description found in source metadata or a localized source document. It may be displayed and indexed but never replaces the canonical `SKILL.md` member in a Module Artifact.
_Avoid_: localized README body, translated instructions, generated Skill

**Hub Enrichment**:
Presentation-only Module Description or Skill Description produced by Hub analysis for one immutable source revision and locale. It belongs to the Hub catalog and may improve discovery or detail views without changing Module Info, Sum, installation, or execution semantics.
_Avoid_: artifact translation, localized Skill version, source rewrite

**Localized Search Document**:
The locale-specific search projection of canonical identity plus localized Module and Skill descriptions for one Skill. It determines retrieval and ranking text but is not an installable resource.
_Avoid_: localized artifact, translated package, Module Info

**Enrichment Run**:
One auditable analysis attempt over a specific immutable source revision, analyzer identity, prompt revision, and requested locale set. Its outputs become active only after validation and never overwrite historical run evidence.
_Avoid_: cron result, mutable translation row, artifact scan

**Sum**:
The deterministic Go HashZip-compatible `h1:` identity of a normalized Module Artifact. It uses Go `dirhash.Hash1` over sorted full ZIP file names and contents, including the `<modulePath>@<version>/` root. Archive compression and metadata do not affect the result, while Module identity and immutable version are authenticated as part of the artifact coordinate.
_Avoid_: archive hash, Git tree SHA

**Hub Origin**:
The trusted Hub base used to resolve metadata and download an artifact. Clients may use the official service or a self-hosted Origin and still verify sums.
_Avoid_: Hub account, mirror name

**Cloud Deployment Discovery**:
The minimal public Hub declaration containing `mode` and, only in Cloud mode, the configured Cloud origin. It selects the independent Cloud data plane without becoming a capability-negotiation protocol.
_Avoid_: capability matrix, Cloud proxy, shared database

**Repository Popularity**:
The source repository's current public star count, recorded as contextual discovery metadata. Every Skill in the same repository shares this repository-level signal; it is not a Skill rating.
_Avoid_: Skill stars, quality score, recommendation score

**Source Updated At**:
The source commit time of the Module Version containing a Skill member. It describes when the served source revision changed, not when the Hub fetched or indexed it.
_Avoid_: Hub update time, cache refresh time, repository API updated_at

**Archive Size**:
The exact byte length of the deterministic Module ZIP served by the Hub for one immutable Module Version.
_Avoid_: extracted directory size, source repository size, transport-compressed response size
