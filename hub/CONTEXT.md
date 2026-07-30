# SkillsGo Hub

The Hub context turns public Skill sources into stable identities and immutable artifacts, then serves discovery and distribution APIs.

## Language

**Skill**:
A set of Agent instructions and supporting resources rooted at a valid `SKILL.md`. Its canonical Skill Name identifies the member within a Package; its display title and description are presentation metadata.
_Avoid_: plugin, application, extension

**Skill Name**:
The canonical, normalized name declared by `SKILL.md`. Together with Package Path it identifies a logical ranking and default-selection group across Package Versions, but it is not unique inside a Package Publication. A name-only selection resolves deterministically to the lexicographically first Skill Path.
_Avoid_: display title, source directory name, global name, Skill ID

**Skill Path**:
The normalized Package-relative directory containing one member's `SKILL.md`. It uniquely identifies membership within a Package Publication and is the exact selector persisted when a product surface installs a specific result. Same-name members at distinct paths retain independent metadata.
_Avoid_: Skill Name, display path, generated suffix

**Skill Source**:
A GitHub, GitLab, well-known endpoint, or other supported public source containing a `SKILL.md` and its resources.
_Avoid_: Hub-owned repository, cloud Skill

**Package**:
The Hub distribution unit named by a canonical Package Path. A Package owns an ordered history of immutable Versions, and each Version owns the complete Skill snapshots discovered in that source revision. In the current source model, one Package is backed by exactly one Source Repository and one Source Repository maps to exactly one Package.
_Avoid_: Source Repository, Skill collection projection, provider

**Package Path**:
The canonical slash-separated identity of a Package, such as `github.com/acme/skills`. It is a logical distribution coordinate; its Git-host-shaped spelling does not make the Package itself a Repository.
_Avoid_: Repository ID, clone URL, database row ID

**Source Repository**:
A public version-control repository registered as the source of one Package under a canonical, case-normalized host and arbitrary-depth repository path. It is the unit of remote revision discovery; Skill paths inside it retain their source-tree casing.
_Avoid_: Package, Skill ID, repository URL spelling, refresh schedule

**Source Path**:
The canonical host-relative path of a Package's Source Repository, such as `acme/skills`. Together with Source Host it locates the repository, while Package Path remains the public distribution identity.
_Avoid_: Package Path, clone URL, Skill Path, repository URL

**Version Query**:
An add-time Go-compatible query: an exact semantic version, semantic-version prefix or comparison, `latest`, branch, Tag, or commit. Every query resolves once to a canonical immutable semantic or pseudo-version; only that immutable result is persisted and accepted by exact Package Version resources. The `go get`-specific `upgrade`, `patch`, and `none` operations are outside this stateless resolution contract, and SkillsGo defines no ambiguous `head` alias.
_Avoid_: persisted branch, `latest`, version range, refresh subscription, raw transport URL

**Package Distribution API**:
The metadata surface rooted at `/api/v1/{packagePath}`. It exposes `/api/v1/{packagePath}/versions` and `/api/v1/{packagePath}/versions/{version}`; Artifact bytes are standard static Git repository objects served from the repository URL in Package Info.
_Avoid_: Go Proxy, `/mod`, `@v`, product API, Skill ZIP endpoint

**Package Publication**:
The atomic visibility change that publishes one immutable Package Version, its complete accepted Skill membership, one tagged Git Artifact tree, and one Package Sum for a resolved source commit. Membership uses skills.sh-compatible convention-first discovery with bounded recursive fallback, and no partial accepted membership becomes visible.
_Avoid_: per-Skill publication, Repository Batch table, all-or-nothing source validation

**Package History Backfill**:
An authenticated Hub administration operation that accepts one or more Package Paths and incrementally publishes at most the twenty highest canonical semantic-version Tags discovered from each Package's Source Repository. When a Repository has no canonical Tags, the run instead publishes up to the twenty most recent default-branch commits as immutable pseudo-versions. This keeps prewarming bounded without turning Backfill into unbounded commit crawling or branch subscription. Each Package owns an independent durable run that commits valid versions and retains diagnosable partial failures.
_Avoid_: add option, commit crawl, branch subscription, automatic repository refresh

**Backfill Request**:
A bounded administration request that validates and submits a duplicate-free set of Package Paths while preserving one independent Backfill Run and result per Package.
_Avoid_: Backfill Run, atomic multi-repository import, combined repository status

**Backfill Run**:
One durable, deduplicated attempt to publish at most the twenty highest unprocessed or previously failed semantic-version Tags for a Source Repository, or pseudo-versions for up to its twenty most recent default-branch commits when no canonical Tags exist. Its business status is queued, running, complete, or complete with errors and is independent of River's transport state.
_Avoid_: River job, atomic repository import, installation request

**Historical Publication**:
An immutable Package Publication created by Package History Backfill that remains exactly downloadable without making a Skill absent from the current publication visible in discovery or rankings.
_Avoid_: current catalog entry, archived metadata, resurrected Skill

**Package Version**:
An immutable snapshot of one Package at one source commit, including its canonical version, source ref, commit and root tree identities, Sum, archive size, commit time, and complete Skill membership. `latest` selects the highest stable canonical semantic-version Tag, falls back to the highest canonical pre-release, then falls back to the default-branch tip when no canonical Tags exist. An untagged revision derives its pseudo-version base from the highest canonical semantic-version Tag among its ancestors. A canonical semantic-version Tag resolves to one commit permanently; moving a published Tag is a conflict.
_Avoid_: Skill version, GitHub Release, mutable branch head, npm-style publish event

**Version Query Resolution**:
An explicit add-time resolution of a semantic Tag, branch, commit hash, or exact canonical semantic/pseudo-version to one immutable commit and canonical version. Branches may advance between requests, but each result names an immutable version that never advances; install and exact artifact reads never resolve the movable input again.
_Avoid_: branch subscription, persisted branch, mutable artifact

**Package Info**:
The standalone deterministic metadata resource for one Package Version. It contains schema kind, Package Path, canonical Version, commit time, Package Sum, Artifact Repository URL, and the complete path-ordered `{name, path}` Skill membership. Source ref, commit/tree identities, descriptions, `SKILL.md` frontmatter, mutable assessments, and source enrichment remain outside this distribution document.
_Avoid_: database record dump, Skill Info document, editorial member list, per-Skill artifact manifest

**Package Artifact**:
The minimal safe Git-tracked union of every accepted member's complete Skill directory subtree, the Source Repository's authored root `README.md` when present, plus applicable ancestor `.codex-plugin`, `.claude-plugin`, and `.cursor-plugin` manifests for one immutable Package Version, completed with deterministic missing root manifests for those three Agents, stored under a parentless synthetic commit and immutable tag in the Package's standard bare Git Artifact Repository, and authenticated by one Package Sum. Repository-relative paths remain stable. Relative symlinks whose fully resolved targets remain inside the same Package Artifact are preserved; escaping, absolute, broken, cyclic, and otherwise invalid symlinks are omitted. Skills are selectable members of this artifact rather than independently archived artifacts.
_Avoid_: Skill artifact, live repository directory, mutable cache entry

**Source Presentation**:
Author-maintained Source Repository description, Skill description, or canonical `SKILL.md` document. It may be displayed and indexed and remains the fallback for every presentation language, but it is never rewritten by Hub enrichment.
_Avoid_: generated source, localized artifact, inferred canonical language

**Hub Enrichment**:
Presentation-only Package Description, Skill Description, or Skill document body produced by Hub analysis for one source digest and language. Description text belongs to the Hub catalog; localized document bodies use deterministic `SKILL.{lang}.md` sidecars. Neither changes Package Info, Sum, installation, or execution semantics.
_Avoid_: artifact translation, localized Skill version, source rewrite

**Localized Search Document**:
The language-specific search projection of canonical identity plus localized Package and Skill descriptions for one Skill. It determines retrieval and ranking text but is not an installable resource.
_Avoid_: localized artifact, translated package, Package Info

**Enrichment Run**:
One auditable analysis attempt over a specific immutable source revision, analyzer identity, prompt revision, and requested locale set. Its outputs become active only after validation and never overwrite historical run evidence.
_Avoid_: cron result, mutable translation row, artifact scan

**Sum**:
The deterministic Go HashZip-compatible `h1:` identity of a normalized Package Artifact. It uses Go `dirhash.Hash1` over sorted full ZIP file names and contents, including the `<packagePath>@<version>/` root. Archive compression and metadata do not affect the result, while Package identity and immutable version are authenticated as part of the artifact coordinate.
_Avoid_: archive hash, Git tree SHA

**Hub Origin**:
The trusted Hub base used to resolve metadata and download an artifact. Clients may use the official service or a self-hosted Origin and still verify sums.
_Avoid_: Hub account, mirror name

**Repository Popularity**:
The source repository's current public star count, recorded as contextual discovery metadata. Every Skill in the same repository shares this repository-level signal; it is not a Skill rating.
_Avoid_: Skill stars, quality score, recommendation score

**Source Updated At**:
The source commit time of the Package Version containing a Skill member. It describes when the served source revision changed, not when the Hub fetched or indexed it.
_Avoid_: Hub update time, cache refresh time, repository API updated_at
