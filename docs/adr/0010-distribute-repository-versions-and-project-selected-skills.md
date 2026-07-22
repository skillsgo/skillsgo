---
status: accepted
---

# Distribute Repository Versions and project selected Skills

SkillsGo distributes one immutable artifact per Repository Version instead of one artifact per Skill. A Repository is the publication, version, ZIP, Go-compatible `h1:`, download, lock, and Vendor unit; a Skill remains a discoverable Repository member and the unit of user selection and Agent visibility. This supersedes the `/mod` namespace and local declaration decisions in ADR-0004 and the Skill ZIP, Skill Sum, shared Store, symlink/copy mode, `skillsgo.mod`, and `skillsgo.sum` decisions in ADR-0009 before public launch.

## Decision

A Repository Publication resolves one source revision, discovers its complete ordered Skill membership, archives the complete safe Git-tracked regular-file tree under `<repositoryId>@<version>/`, computes `h1:` with the same `dirhash.Hash1` algorithm used by Go Modules after removing that ZIP prefix, and atomically publishes one Repository Info record and one Repository ZIP. ZIP and Sum use exactly the same file set. Skills have `repositoryId`, immutable Repository Version, and source-relative path, but no independent ZIP, archive size, or artifact Sum. SumDB can therefore authenticate Repository Versions in the same way that Go authenticates Module Versions; Skills correspond to packages within that versioned tree.

`add` may accept a canonical semantic Tag, an arbitrary branch such as `main` or `feature/x`, or a full or abbreviated commit hash. A movable revision is resolved once to its immutable commit and canonical semantic or Go-compatible pseudo-version. Only that immutable version is persisted, published, downloaded, and served by the Repository Proxy; `install` never resolves the original revision again. The ambiguous `latest` remains unsupported. The Artifact Origin is the Repository Proxy Base, so public Repository-coordinate resources are `GET /<escaped-repository-id>/@v/list`, `GET /<escaped-repository-id>/@v/<version>.info`, and `GET /<escaped-repository-id>/@v/<version>.zip`; exact ZIP also supports `HEAD`. Product APIs remain under `/api/v1`, take routing precedence over proxy coordinates, and resolve movable add-time revisions separately from the immutable proxy. Skill search and detail APIs point to a Repository Release by Repository ID, version, and member path.

Editable dependency intent lives in `skillsgo.yaml`:

```yaml
dependencies:
  github.com/garrytan/gstack:
    version: v1.2.0
    skills:
      - "."
      - review
      - ship
    agents:
      - codex
      - zed
```

The top-level `dependencies` mapping is keyed by canonical Repository ID, so one scope can declare a Repository only once. `version`, `skills`, and `agents` are required; both lists are explicit and non-empty, `"."` denotes the root Skill, and every selected Skill is projected to every selected Agent. CLI wildcards may be accepted as input convenience but are expanded before persistence. YAML decoding rejects unknown fields, duplicate keys, and duplicate normalized members. There is no schema version or installation mode.

Machine-generated integrity state lives in `skillsgo.lock` and contains only the locked Repository Version and Repository Sum for each dependency:

```yaml
dependencies:
  github.com/garrytan/gstack:
    version: v1.2.0
    sum: h1:example
```

Project Scope vendors the verified Repository under `<workspace>/.skillsgo/vendor`; User Scope vendors it under `~/.skillsgo/vendor`. SkillsGo does not read, modify, or prescribe `.gitignore`, does not stage files, and does not model whether a Workspace commits Vendor or generated Agent files. Teams may commit both for clone-and-use behavior or ignore both and run `skillsgo install`. Version-one `install` is an idempotent ensure operation over `skillsgo.yaml` and `skillsgo.lock`: it fills missing verified Vendor and projections, but does not update versions, reconcile remote selectors, delete extras, or provide a general `sync` operation.

For each Scope, Agent, and Repository Version, the Agent Adapter generates at most one ordinary-file Repository Projection. The projection preserves the complete Repository layout so Repository-level runtime files remain available, but retains `SKILL.md` only for members selected for that Agent; unselected members cannot become visible merely because they share a Repository. Adding or removing a selected member atomically regenerates that Repository Projection. Vendor is authoritative and immutable. A projection that differs from its deterministic expected state is a Local Modification: `install` reports a conflict and never overwrites or absorbs it, leaving recovery to the user. Version one provides neither symlinks nor a public copy/vendor mode, and fork semantics are deferred.

## Consequences

Multi-Skill repositories such as gstack are downloaded and vendored once per version, preserve shared runtime layout, and no longer duplicate a ZIP for every member. Local Agent projections may duplicate a Repository once per selected Agent, which is accepted to obtain identical Windows, macOS, and Linux semantics and to avoid cross-machine symlink targets. Repository ZIPs may be larger than a selected Skill, so protocol size limits remain mandatory. Existing per-Skill artifact code, data, routes, manifests, sums, Store behavior, receipts, and tests are migration inputs only and must be removed rather than supported through compatibility branches.
