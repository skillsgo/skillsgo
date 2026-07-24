---
status: accepted; implementation pending
---

# Distribute source-independent Packages

SkillsGo makes a Package, rather than a Git Repository or a remotely discovered
Skill, the immutable distribution, publication, artifact, lock, Vendor, and
update unit. Git and Agent Skills well-known discovery are versioned upstream
Source Adapters owned by the Hub. The Hub normalizes every accepted upstream
snapshot into one immutable Package Publication before the CLI can install it.

This decision supersedes ADR-0010 and ADR-0011 before public launch. It changes
the Repository terminology used by ADR-0013 to Package terminology without
changing ADR-0013's user-reviewed adoption, multi-version, or recovery
requirements. There is no compatibility reader, route, alias, database
migration, or dual Repository/Package machine schema because no public
SkillsGo release exists.

## Why this decision exists

The current design collapses five different concepts into Repository:

1. an upstream Git location;
2. a public identity;
3. a revision and version authority;
4. an immutable artifact boundary;
5. a local declaration, lock, Vendor, and Projection boundary.

That shape is deep for Git but impossible to extend honestly. A well-known
publisher has no required Git Repository, commit, tree, ref, Tag history, or
Repository-wide archive. Preserving the current model would require fabricated
Git evidence and would make an entire well-known index one false atomic
dependency even though each entry has an independent artifact and digest.

The parts worth preserving are not Git-specific:

- one complete immutable artifact per declared dependency coordinate;
- one authenticated Sum over a deterministic normalized tree;
- complete membership published atomically with that artifact;
- shared files retained for multi-Skill Packages;
- exact versions restored without resolving movable upstream state;
- local Scope Vendors and deterministic Agent Projections;
- explicit user selection, Local Modification protection, and recoverable
  mutations.

The new model preserves those properties and moves Git knowledge behind one
Source Adapter.

## Goals

- Accept Git and well-known sources without false Git metadata.
- Keep one source-independent installation pipeline after Hub ingestion.
- Preserve every current App, CLI, Hub, Cloud, offline, audit, and safety
  behavior unless this decision explicitly replaces it.
- Support multiple immutable Publications of one Package in one scope.
- Preserve multi-Skill Packages and shared runtime files.
- Preserve exact-path selection when one Package contains same-name members.
- Make source-specific capabilities explicit rather than guessed from fields.
- Allow later Source Adapters without changing Manifest, Lock, Artifact, or
  Agent Projection semantics.

## Non-goals

- Supporting the legacy schema-less `/.well-known/skills/index.json` format.
- Making the App or CLI fetch a publisher origin directly.
- Defining Skill-to-Skill dependencies.
- Defining a global publisher-signature or transparency-log standard.
- Mirroring arbitrary package managers.
- Making `skills.sh` identifiers or metrics authoritative.
- Migrating any pre-release Repository data or YAML.
- Adding source-specific fields to the common Package interface.

## Ubiquitous language

### Source

A public upstream location from which the Hub can obtain Package inputs and
source evidence. A Source is not installable and is never a Manifest or Lock
coordinate.

### Source Kind

The versioned adapter family that interprets a Source. The first values are
`git` and `well-known`. GitHub is Git hosting and optional metadata enrichment,
not the universal Source Kind.

### Source Locator

The canonical typed input used to reach a Source, such as a Git HTTPS URL or an
HTTPS publisher origin. It is provenance and resolution input, not stable
Package identity.

### Source Catalog

A Source document that discovers zero or more Package candidates. A well-known
index is a Source Catalog. It is not one Package and cannot be installed,
locked, updated, or removed as if all entries shared one lifecycle.

### Package

The stable SkillsGo distribution identity whose Publications share logical
continuity. A Package contains one or more Skill members and is the unit named
by Manifest, Lock, Artifact, Vendor, update, and history.

### Package Publication

One immutable Package Version, normalized Artifact, Sum, complete membership,
and typed Source Provenance made visible atomically. An exact Publication never
re-resolves its upstream Source.

### Package Version

The immutable version string within one Package. It is either an immutable
semantic version or a source-independent revision version. Version ordering and
release-channel selection are separate capabilities.

### Package Artifact

The complete normalized safe regular-file tree for one Package Publication.
It may contain multiple Skills and files shared by them. It is distributed as
one deterministic ZIP and authenticated by one SkillsGo `h1:` Sum.

### Package Member

One Skill directory contained in one Package Publication. Its exact identity
inside a Package is its normalized Skill Path. Its `SKILL.md` declares a
canonical Skill Name, which is searchable and human-selectable but is not
required to be unique within a Package.

### Source Provenance

Typed immutable evidence describing how the Hub obtained a Package Publication.
It is audit information, not installation identity.

### Source Capability

A source-specific operation the Hub can truthfully provide, such as Git Tag
history or a stable release channel. Unsupported capabilities return typed
`unsupported` results; they never degrade to empty success or fabricated data.

## Identity model

### Package ID

Package IDs are canonical path-safe strings with a Source Kind prefix:

```text
git/github.com/acme/agent-skills
well-known/open.feishu.cn/lark-approval
```

The grammar is:

```text
<source-kind>/<canonical-source-namespace>/<package-path>
```

Rules:

- every segment is non-empty and excludes `.`, `..`, controls, backslashes,
  percent escapes, query syntax, fragments, and `@`;
- Source Kind is lowercase ASCII;
- DNS hosts are lowercase ASCII without credentials or a port;
- Git path canonicalization belongs to the Git Source Adapter;
- a well-known Package path is the canonical entry `name`;
- Source Adapters must produce exactly one canonical ID for equivalent input;
- Package ID is not parsed to recover a network URL;
- Package identity changes when a Package moves to a different Source Kind or
  publisher namespace; migration is explicit adoption, never a silent update.

A Git Repository normally produces one multi-Skill Package, so its Package ID
contains the Git host and repository path. A well-known index produces one
single-Skill Package per entry, so its Package ID contains the origin host and
entry name.

Source-kind payloads are canonicalized by shared Protocol constructors, not
independently by App, CLI, or Hub callers:

- DNS names are IDNA A-labels, lowercase, and have no trailing dot;
- public Package IDs forbid credentials, IP literals, and non-default ports;
- Git IDs remove an optional terminal `.git`; GitHub owner and repository
  segments are lowercase, while other Git path casing follows that host's
  declared canonical identity rule;
- well-known IDs use the default HTTPS origin and one canonical Agent Skills
  entry name;
- Package Proxy paths use Go module path escaping for the complete Package ID,
  so uppercase source path segments and `/` cannot create route ambiguity.

The Hub persists a Source Binding when discovery first establishes a Package:

```text
Package ID
  -> Source ID
  -> Source Kind
  -> canonical Source Locator
  -> adapter-local Package Key
```

Resolution loads this binding. It never reconstructs a network address by
parsing Package ID.

### Member identity

The exact public member coordinate is structured:

```text
Package ID + Skill Path
```

The immutable materialization coordinate additionally carries Package Version:

```text
Package ID + Package Version + Skill Path
```

Skill Name remains canonical `SKILL.md` metadata and a human CLI convenience
selector. A name selector succeeds only when it matches exactly one Skill Path
in one exact Publication. Zero matches return `missing`; multiple matches
return typed `ambiguous` with the candidate paths and make no mutation. Add,
update, removal, and adoption use the same rule. Product surfaces that present
a concrete result persist and submit its exact Skill Path.

The canonical root Skill Path is `.`. It is the only allowed dot-form and is
preserved unchanged by Hub JSON, database rows, Cloud events, App models, CLI
machine documents, Manifest, inventory, and removal. Empty string, `SKILL.md`,
`./x`, trailing slash, and any other alias are rejected. In the Artifact ZIP,
`.` is a member coordinate only; it does not create a literal path segment.

No concatenated public Skill ID is introduced. HTTP, JSON, database, Cloud, and
machine contracts carry `packageId`, `skillPath`, and, where useful for display
or validation, `skillName` as separate fields.

### Package Version

Package Versions use this closed grammar:

```text
v1.2.3
v1.2.3-beta.1
v1.2.4-0.20260724120000-0123456789ab
r1-<64 lowercase hexadecimal normalized-source digest>
```

The Protocol parser accepts canonical semantic versions, canonical
Go-compatible pseudo-version syntax, and `r1`. Git canonical semantic Tags keep
their semantic version. The Git Adapter authenticates pseudo-version ancestry,
timestamp, base Tag, and commit suffix; the common parser validates only its
canonical form. Every other source snapshot without a canonical semantic
release uses `r1`.

The `r1` digest has one executable algorithm:

1. begin SHA-256 with the ASCII frame `skillsgo-package-revision-v1\n`;
2. include every safe regular source file and no directory entries;
3. normalize each relative path to valid UTF-8 NFC with `/` separators, preserve
   case, and require portable-path uniqueness;
4. sort by normalized UTF-8 path bytes;
5. for each file, append its path byte length as unsigned big-endian 64-bit,
   path bytes, one executable-mode byte (`0` or `1`), content byte length as
   unsigned big-endian 64-bit, and exact content bytes;
6. include empty files; reject links, devices, invalid paths, and unsupported
   modes before hashing;
7. encode the final 32-byte digest as 64 lowercase hexadecimal characters.

For Git, the input is the complete accepted Git-tracked regular-file tree. For
well-known, it is the complete verified entry artifact after safe extraction.
This digest is calculated before the SkillsGo Artifact coordinate envelope,
avoiding a Version/Sum cycle.

After validation the common protocol treats an exact Package Version as opaque.
It never infers a commit, publication time, or ordering from `r1`.

### Sum and upstream digest

Two digests have different jobs:

- `sourceDigest` verifies the upstream artifact bytes declared by a Source;
- Package `Sum` authenticates the normalized SkillsGo Artifact under its
  Package ID and Package Version.

They are never substituted for one another. A well-known publisher's SHA-256
digest does not replace the SkillsGo `h1:` Sum.

## Source Adapter seam

The Hub owns one deep source-ingestion module. Its external interface accepts a
typed Source request and returns normalized Package candidates or a normalized
exact Package snapshot:

```go
type SourceIngestor interface {
    Discover(ctx context.Context, request DiscoverSourceRequest) (SourceCatalogSnapshot, error)
    Resolve(ctx context.Context, request ResolvePackageRequest) (PackageSourceSnapshot, error)
}
```

Callers learn only the common Source request, capability result, normalized
files, members, revision digest, and typed provenance. Network transport,
authentication, redirects, Git commands, schema parsing, archive formats,
upstream caching, and provider-specific validation stay inside the module.

`git` and `well-known` are real Adapters at this seam. More internal seams may
exist for network fetching and tests, but they are not public Hub interfaces.
Adapters return normalized input files; they do not build final Package ZIPs
or write Catalog state. One common publication module validates members,
builds the Package Artifact, calculates Sum, audits content, stores bytes, and
commits Catalog visibility.

`Discover` returns Package candidates plus the canonical Source Binding that
must be persisted before later resolution. `Resolve` receives that persisted
binding and only a source-supported movable selector. A typed capability result
distinguishes `supported`, `unsupported`, `missing`, and `failed`; an empty
Source Catalog is a successful supported result and is never used to represent
an unsupported operation.

Exact Package resolution first checks Catalog and immutable storage. A retained
exact Publication is returned without invoking a Source Adapter. A missing
well-known exact `r1` is `not found`; the Hub never asks the current index to
reconstruct historical content. Git may resolve an unpublished exact source
revision only through its explicit Git capability.

## Git Source Adapter

The Git Adapter preserves current truthful behavior:

- canonical public Git HTTP(S) source resolution;
- public-network and redirect protections;
- branch, Tag, full or abbreviated commit selectors;
- `head` and stable-first `release` channels;
- Go-compatible pseudo-version authentication;
- Tag movement conflicts;
- complete Git-tracked regular-file snapshots;
- commit and tree evidence;
- Repository cache coalescing and bounded upstream work;
- authenticated historical semantic-Tag backfill.

Git-only provenance is:

```json
{
  "kind": "git",
  "sourceUrl": "https://github.com/acme/agent-skills",
  "commit": "0123456789abcdef...",
  "ref": "refs/tags/v1.2.3",
  "tree": "abcdef..."
}
```

GitHub stars, avatar, license, description, ETag, and release presentation are
mutable Source Metadata. They are not Package Publication fields and are
nullable for every non-GitHub Source.

## Well-known Source Adapter

The first implementation supports only the Draft v0.2.0 schema:

```text
GET https://<origin>/.well-known/agent-skills/index.json
```

The adapter requires the exact known `$schema` URI:

```text
https://schemas.agentskills.io/discovery/0.2.0/schema.json
```

Unknown or absent schemas are rejected. There is no v0.1 fallback.

Each accepted `skill-md` or `archive` entry becomes an independent single-Skill
Package. Updating one entry must not version, update, download, or invalidate
another entry from the same Source Catalog.

The adapter must:

- require HTTPS;
- resolve relative artifact URLs against the index URL;
- verify the declared raw-byte SHA-256 before parsing;
- support `skill-md`, ZIP, and tar-gzip;
- require `SKILL.md` at the Artifact root;
- validate the manifest with the shared Protocol rule;
- require index `name` and manifest Skill Name to match;
- reject missing, duplicate, non-portable, absolute, traversal, device, link,
  and case-colliding paths;
- use entry `type` and safely parsed content as authority; Content-Type and file
  extension are advisory, and generic or extensionless CDN URLs remain valid;
- reject an archive only when its magic bytes and safe parser cannot recognize
  a supported format, or `skill-md` is not valid text and a valid manifest;
- bound redirects, DNS resolution, response bytes, file count, individual file
  bytes, total unpacked bytes, compression ratio, and elapsed time;
- use a custom resolver and dialer for every redirect hop and connection:
  resolve the origin, reject any non-public address, connect only to a validated
  address, and retain the original host for TLS SNI and certificate validation;
- disable environment proxies by default; an operator-configured trusted proxy
  is a separate explicit trust boundary;
- reject loopback, link-local, private, multicast, unspecified, and metadata
  service destinations;
- never execute scripts during ingestion;
- preserve the index URL, schema, entry name, resolved artifact URL, and
  publisher digest as provenance.

Well-known provenance is:

```json
{
  "kind": "well-known",
  "origin": "https://open.feishu.cn",
  "indexUrl": "https://open.feishu.cn/.well-known/agent-skills/index.json",
  "schema": "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
  "entryName": "lark-approval",
  "artifactUrl": "https://open.feishu.cn/releases/lark-approval.tar.gz",
  "sourceDigest": "sha256:..."
}
```

The well-known adapter provides `head`, meaning the current verified index
entry. Exact retained Publications are served by Catalog and storage, not the
adapter. It does not provide `release`, semantic Tag history, or history
backfill unless a future accepted schema defines equivalent immutable evidence.

## Package publication

Every Source Adapter feeds the same publication transaction:

1. canonicalize Package ID and exact Package Version;
2. normalize and validate every Artifact entry;
3. discover and validate the complete Package membership;
4. preserve same-name members at distinct Skill Paths;
5. calculate a content digest for every Package Member;
6. build one deterministic Package ZIP containing the complete safe tree;
7. calculate the coordinate-bound SkillsGo `h1:` Sum;
8. produce immutable Package Info and typed Source Provenance;
9. put Artifact and Info immutably;
10. atomically commit the Publication, membership, and current projection in
    one database transaction;
11. schedule or serve on-demand risk audit and presentation enrichment against
    the exact Package Sum.

An existing `Package ID + Package Version` with different Info, Sum,
membership, or canonical first-publication Source evidence is a conflict and is
never overwritten. Reobserving equivalent content appends a Source Observation
and may refresh mutable Source state; it does not change immutable Info.

Object storage and the database do not form one distributed transaction. The
state machine writes immutable objects first, then commits relational
visibility. A database failure leaves a safe unreferenced object that retry can
reuse; publication never compensates by deleting an immutable object that a
concurrent publisher may have adopted.

Historical Publications remain exactly retrievable but do not resurrect
members absent from the current Publication into search, rankings, or current
detail.

## Package Artifact contract

The Package Artifact retains the current coordinate-binding property:

```text
<packageId>@<packageVersion>/<source-relative path>
```

Package ID and Package Version therefore participate in `h1:`. The Protocol
artifact module is renamed from Repository to Package terminology without
weakening:

- deterministic names and content;
- ZIP/directory Sum parity;
- safe-path validation;
- duplicate and portable-collision rejection;
- bounded one-pass traversal;
- full-tree validation before member projection.

The complete Package tree is the Vendor input. A per-Skill archive is not
introduced. Git Packages can continue to preserve files shared by multiple
Skills. A well-known Package is normally single-Skill because each index entry
already declares one independent artifact.

## Public Hub and Protocol contracts

The pre-release draft schema is replaced once. There are no Repository aliases
or dual fields.

### Immutable Package Info

```json
{
  "schemaVersion": 2,
  "kind": "Package",
  "packageId": "well-known/open.feishu.cn/lark-approval",
  "version": "r1-...",
  "sourceUpdatedAt": null,
  "sum": "h1:...",
  "archiveSize": 12345,
  "provenance": {
    "kind": "well-known",
    "origin": "https://open.feishu.cn",
    "indexUrl": "https://open.feishu.cn/.well-known/agent-skills/index.json",
    "schema": "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
    "entryName": "lark-approval",
    "artifactUrl": "https://open.feishu.cn/releases/lark-approval.tar.gz",
    "sourceDigest": "sha256:..."
  },
  "skills": [
    {
      "packageId": "well-known/open.feishu.cn/lark-approval",
      "version": "r1-...",
      "skillPath": ".",
      "contentDigest": "sha256:...",
      "name": "lark-approval",
      "description": "..."
    }
  ]
}
```

`sourceUpdatedAt` is Git commit time or another publisher-authenticated source
revision time. It is null for well-known v0.2, whose schema declares no
publisher time; HTTP `Last-Modified`, index fetch time, and Artifact fetch time
must not fill it. Source Observation records store `observedAt` separately and
may project `lastObservedAt` onto mutable cards. Common Package or Skill Info
contains no required ref, commit, tree, stars, Git Repository URL, or
source-host path.

Typed provenance decoding is strict by `kind`. Missing required fields,
unknown kinds, unknown schema versions, identity mismatches, duplicate members,
and Artifact/Info/Sum mismatches reject the Publication.

### Source discovery

A Source Catalog response may contain multiple Package cards. It never returns
one fake Package that groups independent well-known entries. Non-interactive
CLI and App flows must select an exact Package and member before installation.
The first App release provides no cross-Package “install all” action.

### Package Proxy

The existing Go-proxy-shaped exact distribution surface is retained with
Package semantics:

```text
/<escaped-package-id>/@v/list
/<escaped-package-id>/@v/<version>.info
/<escaped-package-id>/@v/<version>.zip
```

Exact reads never contact an upstream Source. Product APIs remain under
`/api/v1`; their request and response schema changes atomically to Package
terminology.

### Updates

Update responses are capability-aware per Package:

```json
{
  "packageId": "...",
  "skillPath": "...",
  "currentVersion": "...",
  "candidateVersion": "...",
  "channel": "head",
  "status": "available"
}
```

Valid statuses include `available`, `current`, `unsupported`, `missing`, and
`failed`. A well-known Package can update from one retained Publication to the
Publication currently referenced by verified source `head`; this is a
current-head comparison, not version ordering. If a publisher points back to a
retained older Publication, it is still a different head candidate and the UI
must not call it “newer” or “latest commit”. It is not queried for a fabricated
Git `release`. One unsupported Package never fails an otherwise valid batch.

## skills.sh API field disposition

The skills.sh API is a presentation and catalog precedent, not the SkillsGo
immutable contract.

| skills.sh field | SkillsGo disposition |
| --- | --- |
| `id` | Do not copy. Use structured `packageId + skillPath`; product routes may encode them. |
| `slug` | Use canonical Skill Name as the route/display slug where unambiguous. |
| `name` | Treat as human-readable display metadata; do not replace canonical Skill Name. |
| `source` | Use as an optional source label or filter, never Package identity. |
| `sourceType` | Adopt the concept as extensible `SourceKind`, beginning with `git` and `well-known`. |
| `installUrl` | Preserve as Source Locator/provenance or an external affordance, never a Lock coordinate. |
| `url` | Product presentation link only, never source or artifact identity. |
| `isDuplicate` | Mutable Catalog assessment outside immutable Package Info. |
| `installs` | Cloud-owned metric outside Hub immutable Package metadata. |

The public SkillsGo card separates these concerns:

```json
{
  "packageId": "well-known/open.feishu.cn/lark-approval",
  "skillPath": ".",
  "skillName": "lark-approval",
  "displayName": null,
  "description": "...",
  "source": {
    "kind": "well-known",
    "label": "open.feishu.cn",
    "installUrl": "https://open.feishu.cn"
  },
  "publication": {
    "version": "r1-...",
    "sourceUpdatedAt": null
  },
  "trustLevel": "publisher_verified",
  "riskAssessment": "low",
  "isDuplicate": false
}
```

Cloud composes ranking metrics onto this Hub-owned card. Hub does not persist
Cloud install counts or ranking order.

`displayName` is nullable author or Hub presentation metadata and falls back to
Skill Name in clients. SkillsGo never title-cases canonical Skill Name and
pretends the result was author supplied.

## Hub persistence

Because the service has not launched, the initial Atlas migration is rewritten
instead of adding compatibility migrations.

The relational model becomes:

- `sources`: typed canonical locator, Source Kind, capability state, refresh
  metadata, and mutable provider metadata;
- `source_catalogs`: optional discovered catalog identity and refresh evidence;
- `source_bindings`: Package-to-Source identity, canonical locator, and
  adapter-local Package Key required for resolution;
- `packages`: Package ID, owning Source, optional Source Catalog, presentation
  metadata, trust state, and current Publication;
- `package_publications`: Package Version, Sum, archive size, immutable Info,
  typed provenance, source revision digest, source-updated time, observed time;
- `publication_members`: Publication, Skill Path, Skill Name, content digest,
  and immutable manifest metadata;
- `skills`: current searchable Package member projection keyed by Package and
  Skill Path;
- `localized_descriptions`: structured Package/member resource identity and
  locale;
- `source_observations`: append-only fetch time, observed locator/digest, HTTP
  cache evidence, and equivalent-content result outside immutable Info;
- Git history backfill tables named explicitly for the Git capability.

Important constraints:

- `packages.package_id` is unique;
- `(package_id, version)` is unique;
- `(publication_id, skill_path)` is unique;
- same-name members at different paths are allowed;
- current Publication must belong to the same Package;
- immutable publication conflicts never update existing rows;
- Publication idempotency compares canonical typed fields rather than JSON
  textual map order; immutable Info has one canonical serialization;
- immutable Info is the Source of Truth and relational provenance columns are
  validated projections of it, not an independent competing record;
- Source metadata refresh cannot change immutable Publication rows;
- deleting a Source is restricted while Packages or Publications reference it;
  immutable Publications and Artifacts are retained;
- current Publication ownership is enforced with a composite relational
  constraint or an equivalent transactionally validated trigger;
- mutable search, localization, trust, risk, duplicate, and popularity
  projections remain outside immutable Info.

SQLC output is regenerated from reviewed queries. Generated files are not
manually edited.

## CLI declaration and lock

Manifest and Lock use a two-level shape so one scope can declare multiple
Publications of one Package without parsing composite map keys.

`skillsgo.yaml`:

```yaml
packages:
  git/github.com/acme/agent-skills:
    publications:
      v1.2.3:
        members:
          skills/review:
            agents:
              - codex
              - zed
          skills/ship:
            agents:
              - codex
      v1.1.0:
        members:
          legacy/review:
            agents:
              - codex
```

`skillsgo-lock.yaml`:

```yaml
packages:
  git/github.com/acme/agent-skills:
    publications:
      v1.2.3:
        sum: h1:...
      v1.1.0:
        sum: h1:...
```

Manifest stores editable intent: exact immutable Package Version, exact Skill
Paths, and explicit Agents for each member. It never derives a Cartesian
product between independent Skill and Agent lists. Lock stores only the
corresponding Sum. Source Locator, Source Catalog, install URL, Git evidence,
publisher digest, and presentation metadata never enter local declaration
state.

Both files remain strict, deterministic, paired, crash-recoverable, and
atomically published. Unknown fields, duplicate keys, incomplete coordinates,
invalid Package IDs, invalid Versions, invalid paths, empty selections, and
Manifest/Lock coordinate mismatches are rejected.

All internal local operations use:

```go
type PackageCoordinate struct {
    PackageID string
    Version   string
}
```

Typed coordinates replace parallel Repository ID and Version strings in
Vendor, Info cache, mutation, inventory, update, and removal modules.
Immutable Info cache keys include Package ID, Version, schema version, and kind.
Cached exact bytes are identity checked; changed bytes for one cache coordinate
are a conflict.

## CLI behavior

### Add

Human `add` may accept a Source Locator or exact Package reference. A Source
Catalog containing multiple Packages produces interactive selection only in a
real TTY Human mode. JSON output, App, CI, redirected stdin, and every
non-interactive mode return stable structured ambiguity and perform zero local
writes. Machine and App calls always submit exact Package ID, Package Version
or selector, and Skill Path, even when a Catalog currently has one Package.

Adding to an existing exact Package coordinate merges explicit member-Agent
bindings idempotently. For each submitted Skill Path it adds only the submitted
Agents; it never exposes an existing member to a new Agent or a new member to
existing Agents unless that exact binding was requested. Adding another
Publication of the same Package creates a second coordinate only if Active
Skill Binding remains valid.

### Install

`install` remains an idempotent ensure operation over exact Manifest and Lock
coordinates. It:

- never resolves Source Locator or a movable selector;
- installs one Package Publication transactionally;
- preserves independent failure and compensation across Package coordinates;
- reconstructs missing Projections offline only when verified Vendor and
  immutable Info cache are present;
- contacts the Hub for the exact locked Publication when Vendor is absent;
- never updates versions or deletes unrelated state.

### Update

Update names both the old exact Package coordinate and the desired selector:

```text
skillsgo update <package-id> --from <exact-version> --to <selector>
```

Preflight binds Manifest, Lock, old Vendor, every old Projection, and candidate
Publication Info to one state token. Execution replaces only that coordinate,
preserves selected Skill Paths and Agents, and rejects missing members, target
collisions, Local Modifications, or stale state without touching another
Publication of the same Package.

### Remove

Machine removal names exact Package ID, Version, Skill Path, scope, and target
intent. Human name-only convenience is allowed only when it resolves to one
unambiguous active member. Removing the last selection deletes only that
Package coordinate's Projection and Vendor; another Publication remains
untouched.

### Adoption

ADR-0013 is implemented on Package coordinates:

- a supported external source record is only a candidate restriction;
- the user selects Package, Skill Path, and immutable Package Version;
- local bytes are not treated as identity proof;
- execution uses ordinary Package add;
- successful replacement enters per-Skill 30-day recovery;
- recovery never overwrites a later path occupant.

The old byte-equality takeover implementation and tests are deleted.

## Scope Vendor and Agent Projection

Scope Vendor becomes the authoritative ordinary-file copy of one verified
Package Artifact in one scope. Package Projection becomes the deterministic
ordinary-file view for one Scope, Agent, and Package Publication.

The existing behavior remains:

- one Vendor per exact Package coordinate per scope;
- one complete multi-Skill Package download;
- full shared runtime layout preserved;
- `SKILL.md` retained only for Package Members selected for that Agent;
- no symlink or public copy mode;
- Vendor is immutable and authoritative;
- Local Modification is never overwritten or absorbed;
- user and Workspace scopes remain independent;
- grouped physical targets retain their current atomic compensation boundary.

Active Skill Binding is validated across the complete proposed scope state.
One physical Agent target path can expose only one selected Skill. Two
Publications of one Package may coexist only when their selected members do not
collide at any managed target. SkillsGo never invents a suffix to force
coexistence.

## Inventory and offline behavior

Inventory remains local-first and does not contact Hub or Cloud. It aggregates
managed targets under `Package ID + Skill Path`, retains exact target
Publications, and reports Version Divergence without treating it as corruption.

The following remain distinct:

- managed Package member;
- External Installation;
- Local Skill;
- Agent Visibility;
- managed Installation Target.

Source Kind never determines local ownership. A well-known Package installed
through Hub is managed, not External.

Hub failure never clears valid Library inventory, Added Projects, Installed
Agents, selected Library route, or safe local-only operations.

## App behavior

The App remains Skill-first. Package is shown only where atomic installation,
shared versioning, provenance, or grouping matters. Source Catalog is a
discovery context, not an installation group.

App domain models become:

- `SkillCoordinate(packageId, skillPath)`;
- `PackageCard`;
- `PackagePublicationCard`;
- `SourceCard`;
- strict tagged `GitProvenance` and `WellKnownProvenance`;
- managed `InstalledSkill` with optional source presentation separate from
  ownership.

The App removes Git heuristics from URLs, source labels, versions, and detail
rendering. The CLI returns typed source/catalog/package results. Git-only stars,
commit, tree, ref, and license render conditionally. Their absence never makes
well-known detail invalid.

A Package page may install multiple members atomically. A Source Catalog page
must not offer one fake atomic “install all” across independent Packages. If a
future bulk action spans Packages, it reports independent Package results and
partial success.

All current interaction guarantees remain:

- next-frame feedback;
- explicit initial, content, refreshing, empty, and error states;
- usable stale content during refresh;
- independent optional data failure;
- target-specific partial success and failed-only retry;
- keyboard, semantics, reduced motion, and Light/Dark behavior.

## Cloud behavior

Cloud ranking and install-event coordinates change atomically to:

```text
Package ID + Skill Path
```

Install events may additionally carry Skill Name for presentation validation,
but aggregation identity does not depend on a possibly duplicated name.

Cloud continues to own metrics and order. It hydrates authoritative Package
Skill cards through one uncached ordered Hub batch request and does not persist
Hub metadata. Hub never depends on Cloud.

## Existing behavior that must not regress

### Distribution and integrity

- Atomic Publication of complete Artifact plus complete membership.
- Deterministic coordinate-bound `h1:` and consumer-side verification.
- Exact Publication reads never re-resolve a Source.
- Immutable put-if-absent storage and conflict rejection.
- Historical exact retrieval without current-catalog resurrection.
- Bounded Artifact construction, traversal, download, and extraction.
- One complete multi-Skill Artifact preserving shared files.

### Local state

- Strict paired Manifest/Lock validation and crash recovery.
- Transactional Vendor/Projection/workspace/cache mutation and rollback.
- User and Workspace scope isolation.
- Local Modification refusal on add, install, update, and removal.
- Offline Projection repair only from verified Vendor plus immutable Info.
- Exact locked online restore when Vendor is missing.
- Installed-Agent discovery independent of installed Skill count.
- Read-only Agent Visibility derived from discovery roots.
- Valid Version Divergence and exact target reporting.

### Product journeys

- Search, all-time, trending, and hot discovery.
- Pagination, locale projection, refresh retention, empty and error recovery.
- Exact Git URL discovery and new well-known origin discovery.
- Skill detail, instructions, files, executable evidence, risk, trust, Sum,
  Artifact size, and provenance.
- Explicit scope and Agent selection.
- Package-atomic multi-member installation.
- Target-specific partial results and retry.
- Exact update review and Workspace declaration preview.
- Managed member removal and exact-path External removal.
- User-reviewed External adoption and recovery.
- Local-first Library during Hub or Cloud failures.

### Hub and Cloud projections

- Exact-name and source-restricted Find.
- Stable search ordering and localization fallback.
- Same-name members at distinct paths.
- Ordered one-query batch card hydration.
- Mutable Source Metadata that cannot alter immutable Publications.
- Risk assessment bound to exact Package Sum.
- Best-effort post-commit install reporting that cannot reverse local success.

## Implementation sequence

Implementation is deliberately incompatible and removes obsolete code as each
new seam lands.

### Phase 0: freeze behavioral evidence

- Add cross-context characterization tests for every non-regression behavior
  above.
- Add fixtures for a Git multi-Skill Package with shared root files and
  same-name distinct paths.
- Add strict well-known v0.2 `skill-md` and archive fixtures.
- Record current machine failure, partial-result, offline, and recovery
  behavior before changing types.

### Phase 1: shared Package Protocol

- Add `packageid`, Package Version, Package Coordinate, provenance union, and
  Package Info.
- Rename artifact algorithms to Package semantics while preserving golden Sums.
- Replace public Skill coordinates with Package ID plus Skill Path.
- Replace Cloud Repository fields with Package fields.
- Set machine and wire schema version 2.
- Remove Repository DTOs, parsers, selectors, and aliases in the same phase.

### Phase 2: Hub common publication and persistence

- Replace the pre-launch Catalog schema and regenerate SQLC.
- Extract the common source-ingestion and publication seams.
- Move current Git resolution behind the Git Adapter without behavior change.
- Package-enable Artifact storage, Proxy, audit, Catalog, search, detail,
  localization, task, metadata, batch, and update contracts.
- Rename Git history backfill explicitly and return unsupported for Sources
  without that capability.

### Phase 3: well-known v0.2 ingestion

- Implement strict Source Catalog and Artifact fetching.
- Apply redirect, SSRF, DNS, size, archive, and digest controls.
- Normalize each entry into an independent Package snapshot.
- Publish through the same transaction used by Git.
- Add end-to-end discovery, exact resolution, Info, ZIP, audit, search, and
  update tests.

### Phase 4: CLI local state and machine contracts

- Replace Manifest and Lock with the two-level Package/Publications shape.
- Introduce typed Package Coordinates throughout cache, Vendor, mutation,
  inventory, update, remove, and verification modules.
- Implement same-Package multi-Publication state and full-scope Active Skill
  Binding validation.
- Replace Hub client and machine DTOs once; delete Repository decoding.
- Preserve offline restore and exact locked download behavior.
- Replace old takeover with ADR-0013 adoption and recovery.

### Phase 5: App and Cloud

- Replace App Repository models, decoders, keys, labels, and URL heuristics.
- Add Source Catalog and typed provenance presentation.
- Keep Package atomic actions separate from multi-Package bulk results.
- Migrate Cloud event and ranking coordinates with Hub batch hydration.
- Update every widget, gateway contract, and desktop E2E journey.

### Phase 6: deletion and terminology audit

- Delete old Repository routes, DTOs, parser aliases, database names, machine
  schemas, fixtures, and takeover behavior.
- Search maintained source and documentation for obsolete Repository-as-Package
  claims.
- Update GEB maps and every touched F4 contract.
- Supersede or amend context ADRs that repeat the old identity.
- Run the complete root, Protocol, Hub, CLI, App, Web, and E2E validation.

## Verification matrix

### Protocol

- hostile and equivalent Package IDs;
- semantic and `r1` versions;
- strict provenance by Source Kind;
- Package Artifact golden Sum and coordinate binding;
- duplicate, traversal, collision, link, count, and size limits;
- strict schema-2 JSON;
- Package plus Skill Path Cloud coordinates.

### Git

- GitHub aliases and generic public Git hosts;
- branch, semantic Tag, stable release, commit, and pseudo-version resolution;
- moving Tag rejection;
- no-Tag and ancestor-Tag pseudo-version authentication;
- concurrent cache coalescing;
- complete shared-file multi-Skill Artifact;
- historical backfill and partial failure.

### Well-known

- exact schema and unknown/missing schema rejection;
- `skill-md`, ZIP, and tar-gzip;
- relative, path-absolute, and absolute URLs;
- publisher digest mismatch;
- redirect and DNS rebinding to forbidden networks;
- index, artifact, file, count, compression, and unpacked-size limits;
- traversal, links, duplicates, devices, and portable collisions;
- index/manifest name mismatch;
- one entry update that does not affect another Package;
- same digest idempotency and changed content producing a new Publication.

### Hub publication

- Git and well-known snapshots use the same publication transaction;
- concurrent idempotent publish;
- immutable coordinate conflict;
- storage failure and orphan retention;
- atomic current visibility;
- historical exact availability;
- current search omission for removed members;
- same-name distinct paths;
- localized search, trust, risk, audit, and source-metadata failure isolation;
- ordered batch hydration and per-item update capability.

### CLI

- root, nested, same-name, and shared-file Package members;
- exact Skill Path selection and name convenience;
- same Package, same Publication idempotent merge;
- same Package, two Publications in one scope;
- Active Skill Binding collision before any write;
- exact update and removal that leave sibling Publications untouched;
- selected member missing from candidate update;
- Vendor and Projection Local Modifications across every mutation;
- strict paired Package YAML and Lock;
- online exact restore and offline Projection reconstruction boundaries;
- local-first inventory, visibility, health, and Version Divergence;
- machine JSON/NDJSON, stable failures, availability exit codes, and partial
  Package-group results;
- post-commit Cloud reporting failure isolation;
- reviewed adoption, recovery expiry, revert, and occupied-path refusal.

### App and E2E

- Git and well-known discovery cards and detail;
- one Source Catalog with multiple Packages;
- no cross-Package fake atomic install-all;
- conditional Git provenance and complete non-Git detail;
- Package multi-member installation;
- non-Git update and unsupported release channel;
- Package grouping without domain-label truncation;
- same-name members and Packages remain distinct;
- Version Divergence and exact targets;
- Hub failure preserving Library state and location;
- External adoption with separate Package and Source constraints;
- managed, External, and Local removal;
- partial failure, failed-only retry, accessibility, reduced motion, and
  refresh retention.

## Rollout gate

The refactor is complete only when:

1. no maintained public or machine contract requires Git provenance;
2. Git and well-known Publications pass the same Artifact/Info/CLI install
   journey;
3. every non-regression behavior has an executable test at its highest
   existing seam;
4. one scope can represent multiple Publications of one Package safely;
5. exact restore never contacts an upstream Source;
6. no App or CLI code fetches well-known publisher URLs;
7. Cloud uses Package plus Skill Path coordinates;
8. obsolete Repository-as-Package code and documentation are deleted;
9. `make test`, workspace-native validation, and both E2E suites pass.

Until all gates pass, Package schema work is not released independently.
