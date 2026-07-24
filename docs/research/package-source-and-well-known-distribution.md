# Package Sources and Well-Known Distribution

Verified against first-party documentation and source code on 2026-07-24.

## Question

SkillsGo currently models a Git repository as the public identity, version
source, immutable publication boundary, artifact boundary, and installation
coordinate. This note examines whether fields and behavior from skills.sh and
the emerging Agent Skills well-known discovery proposal can inform a
source-independent Package model.

The conclusion is:

> SkillsGo should adopt a source-independent Package identity and immutable
> Package Publication as its internal distribution contract. Git and
> well-known discovery should be versioned Source Adapters. The skills.sh
> catalog fields are useful presentation precedents, but they are not a
> sufficient immutable package protocol.

## Primary sources

- [skills.sh API reference](https://www.skills.sh/docs/api)
- [vercel-labs/skills source](https://github.com/vercel-labs/skills)
- [`WellKnownProvider` implementation](https://github.com/vercel-labs/skills/blob/main/src/providers/wellknown.ts)
- [`parseSource` implementation](https://github.com/vercel-labs/skills/blob/main/src/source-parser.ts)
- [Cloudflare Agent Skills Discovery via Well-Known URIs draft](https://github.com/cloudflare/agent-skills-discovery-rfc)
- [Agent Skills specification PR #254](https://github.com/agentskills/agentskills/pull/254)
- [Agent Skills proposal issue #255](https://github.com/agentskills/agentskills/issues/255)

## What skills.sh models

The skills.sh API describes a catalog Skill returned by listing and search with
these fields:

| Field | First-party meaning | Appropriate SkillsGo use |
| --- | --- | --- |
| `id` | Stable catalog identifier in the form `{source}/{slug}` and a reusable detail-route path | Useful precedent for a stable public Skill coordinate, but SkillsGo should derive it from `PackageID + SkillName` and should not persist one ambiguous concatenated string as the only structured identity |
| `slug` | URL-safe Skill slug | Adopt the canonical Agent Skills name as the route slug when possible; keep it distinct from a display title |
| `name` | Human-readable Skill name | Adopt as presentation metadata only; SkillsGo's canonical member identity remains the normalized Skill Name declared by `SKILL.md` |
| `source` | GitHub `owner/repo` or well-known `domain.com` | Adopt as a presentation/source label, not as Package identity; one source catalog may publish many Packages and a Git source can include a subpath |
| `sourceType` | `"github"` or `"well-known"` | Adopt the idea as a typed `SourceKind`, but use an extensible protocol value such as `git` and `well-known`, not a closed GitHub-only domain enum |
| `installUrl` | GitHub repository URL or well-known base URL accepted by `npx skills add` | Preserve as optional source provenance or an external-client affordance; never use it as an immutable Package coordinate or lock value |
| `url` | skills.sh product-detail page | Product-owned presentation link only; not a source URL, artifact URL, or protocol identity |
| `isDuplicate` | Catalog judgment that a Skill is a fork or copy; omitted when false | Potential future mutable catalog assessment, separate from immutable Package Info and artifact bytes |
| `installs` | Deduplicated install count | Mutable Cloud metric, not Hub package metadata or immutable Info |

The same API deliberately returns a smaller detail shape:
`id`, `source`, `slug`, `installs`, a nullable SHA-256 `hash`, and a nullable
text file snapshot. The documented `hash` supports cache invalidation and
change detection. It is not described as a version, an immutable release
identity, a publisher signature, or a durable historical retrieval contract.
SkillsGo therefore should not substitute it for a Package Version or its own
normalized `h1:` Sum.

The skills.sh API also demonstrates that the catalog and install model are
separate concerns:

- `url` navigates the skills.sh product.
- `installUrl` is passed back to the external `skills` CLI.
- `source` groups or labels the publisher location.
- `id` addresses a catalog Skill.

SkillsGo should retain the separation but define stronger structured identities
and immutable publication semantics.

## What the `skills` CLI actually resolves

The `vercel-labs/skills` source parser recognizes local paths, GitHub and
GitLab URLs, shorthand, direct Git URLs, and generic HTTP(S) sources. A generic
HTTP(S) URL not claimed by a known Git provider can be matched by the
`WellKnownProvider`.

The current `WellKnownProvider`:

1. Tries `/.well-known/agent-skills/index.json`.
2. Falls back to legacy `/.well-known/skills/index.json`.
3. Accepts v0.2.0 only when `$schema` exactly matches
   `https://schemas.agentskills.io/discovery/0.2.0/schema.json`.
4. Treats an absent `$schema` as the legacy v0.1.0 `files[]` shape.
5. Rejects an unknown schema instead of guessing its structure.
6. Resolves v0.2.0 artifact URLs relative to the index URL.
7. Verifies the SHA-256 digest of the downloaded `skill-md` or `archive`
   artifact before using it.
8. Validates a root `SKILL.md` and bounds archive extraction to 1,000 files and
   50 MiB unpacked content in this implementation.

The CLI implementation is intentionally more permissive for legacy v0.1.0:
failure to download an individual supporting file is ignored after
`SKILL.md` succeeds. SkillsGo must not copy that behavior because it can
publish an incomplete or temporally mixed snapshot. A Hub ingestion must be
all-or-nothing for every declared input of one Package Publication.

The provider returns the hostname, with a leading `www.` stripped, as its
telemetry/storage source identifier. That is useful as a display label but is
insufficient as a Package ID: it loses the discovery index path and cannot
distinguish multiple Packages published by the same domain.

## Status and semantics of well-known v0.2.0

The Cloudflare document labels itself **Draft, Version 0.2.0**. The matching
Agent Skills [proposal](https://github.com/agentskills/agentskills/issues/255)
and [specification PR](https://github.com/agentskills/agentskills/pull/254)
show that official adoption is being discussed; they do not turn the draft
into a final Package or registry standard.

The draft defines a predictable publisher discovery index at:

```text
/.well-known/agent-skills/index.json
```

Each Skill entry contains:

```json
{
  "name": "code-review",
  "type": "archive",
  "description": "Review code for defects.",
  "url": "/releases/code-review.tar.gz",
  "digest": "sha256:..."
}
```

Important normative properties are:

- `name` follows the Agent Skills canonical name grammar.
- `type` is `skill-md` or `archive`.
- `url` may address a CDN or a versioned path and is resolved using ordinary
  URI reference rules.
- `digest` is SHA-256 over the bytes of that one downloaded artifact.
- A digest mismatch must reject the artifact.
- Archives place `SKILL.md` at their root, without a wrapper directory.
- Clients must handle ZIP and tar-gzip, reject path traversal, and constrain
  unsafe links and decompression bombs.
- Unknown schemas should not be processed; unknown fields are ignored.
- Scripts must not execute by default.

The draft is a current-state discovery and artifact-integrity protocol. It does
not define:

- a globally stable Package ID;
- semantic or historical versions;
- immutable retention of an old digest or URL;
- a lockfile;
- Package dependencies;
- publisher signatures or a transparency log;
- search, ranking, curation, trust, or duplicate detection;
- a normalized cross-format Package Sum.

The HTTPS domain is therefore the practical discovery trust root, while the
digest proves consistency with the index document. The digest alone does not
authenticate the publisher if an attacker controls both the index and artifact.

## Recommended SkillsGo mapping

### Core model

```text
Source
  └── discovers or resolves Package candidates

Package
  └── stable SkillsGo distribution identity

Package Publication
  ├── exact immutable Package Version
  ├── normalized Package Artifact
  ├── SkillsGo h1 Sum
  ├── complete Skill membership
  └── typed Source Provenance
```

`Package` is the unit installed, locked, mirrored, and retained. A Package may
contain one or more Skills. `Source` is how the Hub discovers bytes and
provenance; it is not the installed object.

### Git mapping

A Git repository normally maps to one multi-Skill Package. Git-specific
details belong under provenance:

```json
{
  "kind": "git",
  "origin": "https://github.com/acme/skills",
  "commit": "...",
  "ref": "refs/tags/v1.2.3",
  "tree": "..."
}
```

Git tags, branches, commits, ancestor relationships, and pseudo-version
authentication remain capabilities of the Git Source Adapter. They must not be
mandatory fields on every Package Publication.

### Well-known mapping

One well-known index is a Source Catalog, not one Package. Each v0.2.0 Skill
entry normally maps to an independent single-Skill Package because it has an
independent artifact and digest:

```text
Source Catalog: https://example.com/.well-known/agent-skills/index.json
Package:        example.com/.well-known/agent-skills/code-review
Skill Name:     code-review
```

The concrete Package ID grammar may change, but it must include enough
canonical information to distinguish the source catalog and entry without
depending on a mutable artifact URL.

Well-known provenance should retain:

```json
{
  "kind": "well-known",
  "indexUrl": "https://example.com/.well-known/agent-skills/index.json",
  "schema": "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
  "entryName": "code-review",
  "artifactUrl": "https://example.com/releases/code-review.tar.gz",
  "sourceDigest": "sha256:..."
}
```

`sourceDigest` authenticates the downloaded upstream bytes against the observed
index. The Hub must separately create and retain its normalized Package
Artifact and `h1:` Sum.

### Field disposition

Adopt into the source-independent public/catalog vocabulary:

- structured `PackageID`;
- canonical `SkillName`/route slug;
- presentation `Name`;
- typed `SourceKind`;
- presentation `Source`;
- optional source/install URL;
- optional product detail URL at presentation boundaries;
- mutable duplicate, trust, risk, and popularity assessments outside immutable
  Package Info.

Do not copy as core Package fields:

- skills.sh's concatenated `id` string;
- the hostname-only `source` as Package identity;
- `installUrl` as a lock coordinate;
- `url` as source provenance;
- `isDuplicate` or `installs` inside immutable publication metadata;
- well-known `digest` as the SkillsGo normalized Sum;
- `sourceType: github` as the universal VCS abstraction.

## Compatibility and non-regression requirements

A source-independent refactor must preserve the following existing SkillsGo
properties:

1. One complete artifact is published atomically with complete accepted Skill
   membership.
2. Exact installed versions never re-resolve a movable upstream selector.
3. Artifact bytes are immutable and verified independently by the consumer.
4. A Package can retain shared files used by multiple member Skills.
5. Name collisions at distinct paths remain deterministic and path-selectable.
6. Historical publications remain retrievable without resurrecting removed
   Skills into current discovery.
7. Search, localization, trust, risk, audit, ranking hydration, and update
   checks remain mutable projections over stable Package and Skill coordinates.
8. Cloud install events continue to aggregate by a stable Package plus Skill
   coordinate, regardless of source kind.
9. Source-specific capabilities are explicit. For example, Git history
   backfill and branch selectors are unsupported for a well-known source unless
   that source protocol later supplies equivalent evidence.

## Design implication

Supporting well-known should be an ingestion capability of the Hub:

```text
publisher origin
  -> versioned Source Adapter
  -> verified source snapshot
  -> normalized Package Publication
  -> immutable SkillsGo Artifact and h1 Sum
  -> CLI installation
```

The CLI and App should not independently implement well-known fetching. This
keeps SSRF controls, redirect validation, schema parsing, digest verification,
archive normalization, retention, audit provenance, and historical
reproducibility in one Hub-owned boundary.
