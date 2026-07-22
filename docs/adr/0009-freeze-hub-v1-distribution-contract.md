---
status: superseded by ADR-0010
---

# Freeze the Hub v1 distribution contract

This decision was superseded before public launch by ADR-0010, which moves immutable artifacts, sums, downloads, and local vendoring from individual Skills to Repository Versions. The historical text below records the rejected Skill-artifact design.

## Context

Hub v1 will create durable public coordinates, immutable artifacts, cached protocol responses, Workspace Manifests, and Workspace Sums. Changing the meaning of those values after publication would create duplicate identities, invalidate authenticated bytes, require coordinated client migration, or make an already disclosed private artifact impossible to retract.

SkillsGo deliberately adapts Go Modules rather than claiming compatibility. A Repository Publication is the version-selection unit, while an individual Skill is the installable and content-addressed unit. Repository publication, artifact residency, and mutable product projections therefore have different invariants and must not be collapsed into one cache entry.

## Decision

### Identity

- A Repository ID is `<canonical-host>/<repository-path>`. The host is lower-case. GitHub owner and repository segments are lower-case because GitHub treats them case-insensitively; repository paths on other hosts preserve source casing.
- A root Skill has the Repository ID. A nested Skill uses `<Repository ID>/-/<source-relative-skill-directory>` and preserves the Skill directory's source casing.
- IDs contain canonical slash-separated path segments, no URL scheme, query, fragment, percent encoding, backslash, control character, `.` or `..` segment, `.git` suffix, or `SKILL.md` filename. A source move creates a new ID.

### Version selectors

- Every member of one Repository Publication shares the same canonical immutable semantic or Go-compatible pseudo-version and commit.
- `head` resolves a freshly observed default-branch HEAD. If that commit owns a canonical semantic Tag, the Tag is returned; otherwise a pseudo-version is returned.
- `release` resolves the highest stable canonical semantic Tag, falling back to the highest canonical prerelease Tag.
- An omitted selector for ordinary add means `head`. `latest` is not a persisted intent and is removed from the public selector vocabulary.
- Exact public selectors are limited to canonical semantic versions and canonical pseudo-versions. Raw commits and arbitrary branch names are rejected; `head` is the only public default-branch selector. A published version can never be reassigned to another commit.
- Resolution, list, tagged-commit canonicalization, pseudo-version ancestry, update checking, and Backfill use one refreshed Repository Tag Catalog.

### Repository Publication

- Publication resolves one Repository commit, discovers the complete accepted member set, creates every accepted member artifact, and makes the ordered Repository Release Record visible atomically.
- `SKILL.md` at the repository root and below non-hidden directories is a candidate. Any path containing a dot-prefixed directory is excluded. Invalid candidate manifests are excluded deterministically; a Repository with no accepted member is rejected.
- Nested Skills are independent members. An ancestor Skill artifact includes its complete directory tree, including nested Skill directories. This intentional byte overlap keeps each Skill directory self-contained.
- Interactive add and administrative history Backfill invoke the same create-only Publisher. The CLI downloads only the requested members after the complete Repository Publication commits.

### Artifact and Sum

- One Skill ZIP contains only regular files tracked beneath that Skill directory plus the Repository-root file named exactly `LICENSE` when the Skill is nested and does not already contain its own root `LICENSE`.
- ZIP entries use the exact `<Skill ID>@<version>/` prefix. The h1 Sum removes that prefix and hashes sorted Skill-relative file paths and contents with Go `dirhash.Hash1` framing.
- ZIP serialization, compression, timestamps, and file mode do not affect h1. Only regular and executable permission classes are preserved; symlinks, devices, and other irregular entries are rejected. Executable mode remains artifact-envelope metadata rather than h1 content.
- A ZIP is limited to 64 MiB compressed, 64 MiB uncompressed, and 5,000 files. Paths must be valid UTF-8 portable file paths and may not collide under Unicode case folding or Windows-equivalent normalization. A regular root `SKILL.md` is mandatory.

### Immutable records and storage

- Immutable Skill Info contains source identity, immutable version, commit and tree identity, normalized source frontmatter, h1 Sum, archive byte length, and executable-file metadata. Risk, enrichment, popularity, ranking, access, and other refreshable projections are excluded.
- The Repository Release Record contains Repository ID, immutable version, source ref, commit, commit time, and Skill Info records ordered by canonical Skill ID. The exact persisted bytes are served by Repository Info and may later become a transparency-log leaf.
- Artifact publication uses put-if-absent semantics. Identical bytes are idempotent; different bytes at the same coordinate are an immutable conflict. Repository visibility commits only after every member Info and ZIP has been verified and stored.
- Immutable Info and the Repository Release Record are permanent publication truth. ZIP residency is independent. Hub v1 retains every ZIP; hot eviction remains disabled until an authoritative byte-identical cold copy and verified source-independent restoration exist.

### HTTP protocol and local Manifest

- The public artifact protocol remains under `/mod/{escaped-coordinate}`. It supports `GET` for `@v/list`, `@head`, `@release`, and exact `.info`/`.zip`; exact ZIP also supports `HEAD`. Other methods return 405 with an `Allow` header.
- Coordinates and versions use `golang.org/x/mod/module` escaping. Error bodies are UTF-8 `text/plain`. Exact resources are immutable and cacheable; movable selector responses are not stored by shared caches.
- Repository exact `.info` serves the persisted Repository Release Record. When the Repository root is also a Skill, its member Info is embedded in that record and the same coordinate's exact `.zip` serves the root Skill artifact; otherwise Repository `.zip` returns 404. Nested Skill exact `.info` and `.zip` serve the immutable member record and artifact.
- `skillsgo.mod` uses the closed native grammar `require ID version [agents] [mode]`. The version must already be immutable. Mode is optional, defaults to `symlink`, and canonical writing omits `symlink` while emitting `copy` explicitly.

### Privacy and production gates

- Hub v1 is public-only. Startup rejects source credentials or configuration capable of reading private repositories unless an end-to-end Repository visibility and authorization model is enabled in a future protocol version.
- Offline policy denies every source resolution, discovery, publication, refresh, and queued source operation. Stored exact Info and ZIP remain readable.
- CLI private-Hub credentials are origin-scoped and sent only over HTTPS, except explicit loopback development origins.

## Consequences

Hash, ZIP, database, cache, and Git implementations may be replaced only when conformance tests prove that these public identities and bytes remain unchanged. Risk assessment and enrichment become downstream projections instead of publication inputs. Hub v1 launches without private Repository publication, ZIP eviction, SumDB, automatic tracking, or multi-origin fallback. Those features require their separate prerequisites and must not weaken this contract.
