---
status: superseded by ADR-0014 before public launch
---

# Distribute Repository Versions and project selected Skills

SkillsGo distributes one immutable artifact per Repository Version instead of one artifact per Skill. A Repository is the publication, version, ZIP, Go-compatible `h1:`, download, lock, and Vendor unit; a Skill remains a discoverable Repository member and the unit of user selection and Agent visibility. This supersedes the `/mod` namespace and local declaration decisions in ADR-0004 and the Skill ZIP, Skill Sum, shared Store, symlink/copy mode, `skillsgo.mod`, and `skillsgo.sum` decisions in ADR-0009 before public launch.

## Decision

A Repository Publication resolves one source revision, discovers its complete ordered Skill membership, archives the complete safe Git-tracked regular-file tree under `<repositoryId>@<version>/`, and computes `h1:` with the same full-name `dirhash.Hash1` semantics as Go Module `HashZip`. The ZIP prefix participates in the Sum, so identical bytes published under another Repository ID or immutable version have a different authenticated coordinate. ZIP and Sum use exactly the same file set. Skills have a canonical Repository-unique name and an immutable-version-relative source path, but no concatenated public Skill ID, independent ZIP, archive size, or artifact Sum. SumDB can therefore authenticate Repository Versions in the same way that Go authenticates Module Versions; Skills correspond to packages within that versioned tree.

`add` may accept a canonical semantic Tag, an arbitrary branch such as `main` or `feature/x`, or a full or abbreviated commit hash. A movable revision is resolved once to its immutable commit and canonical semantic or Go-compatible pseudo-version. Only that immutable version is persisted, published, downloaded, and served by the Repository Proxy; `install` never resolves the original revision again. The ambiguous `latest` remains unsupported. The Artifact Origin is the Repository Proxy Base, so public Repository-coordinate resources are `GET /<escaped-repository-id>/@v/list`, `GET /<escaped-repository-id>/@v/<version>.info`, and `GET /<escaped-repository-id>/@v/<version>.zip`; exact ZIP also supports `HEAD`. Product APIs remain under `/api/v1`, take routing precedence over proxy coordinates, and resolve movable add-time revisions separately from the immutable proxy. Skill search and detail APIs identify a member with separate Repository ID and canonical Skill Name fields; Skill Path is source-location metadata within the immutable release.

Editable dependency intent lives in `skillsgo.yaml`:

```yaml
dependencies:
  github.com/garrytan/gstack:
    version: v1.2.0
    skills:
      - gstack
      - review
      - ship
    agents:
      - codex
      - zed
```

The top-level `dependencies` mapping is keyed by canonical Repository ID, so one scope can declare a Repository only once. `version`, `skills`, and `agents` are required; both lists are explicit and non-empty, `skills` contains canonical Repository-unique Skill Names, and every selected Skill is projected to every selected Agent. A root member is selected by its declared name rather than `"."`. CLI wildcards may be accepted as input convenience but are expanded to names before persistence. YAML decoding rejects unknown fields, duplicate keys, and duplicate normalized members. There is no schema version or installation mode.

Machine-generated integrity state lives in `skillsgo-lock.yaml` and contains only the locked Repository Version and Repository Sum for each dependency:

```yaml
dependencies:
  github.com/garrytan/gstack:
    version: v1.2.0
    sum: h1:example
```

Project Scope vendors the verified Repository under `<workspace>/.skillsgo/vendor`; User Scope vendors it under `~/.skillsgo/vendor`. SkillsGo does not read, modify, or prescribe `.gitignore`, does not stage files, and does not model whether a Workspace commits Vendor or generated Agent files. Teams may commit both for clone-and-use behavior or ignore both and run `skillsgo install`. Version-one `install` is an idempotent ensure operation over `skillsgo.yaml` and `skillsgo-lock.yaml`: it fills missing verified Vendor and projections, but does not update versions, reconcile remote selectors, delete extras, or provide a general `sync` operation.

For each Scope, Agent, and Repository Version, the Agent Adapter generates at most one ordinary-file Repository Projection. The projection preserves the complete Repository layout so Repository-level runtime files remain available, but retains `SKILL.md` only for members selected for that Agent; unselected members cannot become visible merely because they share a Repository. Adding or removing a selected member atomically regenerates that Repository Projection. Vendor is authoritative and immutable. A projection that differs from its deterministic expected state is a Local Modification: `install` reports a conflict and never overwrites or absorbs it, leaving recovery to the user. Version one provides neither symlinks nor a public copy/vendor mode, and fork semantics are deferred.

## Consequences

Multi-Skill repositories such as gstack are downloaded and vendored once per version, preserve shared runtime layout, and no longer duplicate a ZIP for every member. Local Agent projections may duplicate a Repository once per selected Agent, which is accepted to obtain identical Windows, macOS, and Linux semantics and to avoid cross-machine symlink targets. Repository ZIPs may be larger than a selected Skill, so protocol size limits remain mandatory. Existing per-Skill artifact code, data, routes, manifests, sums, Store behavior, receipts, and tests are migration inputs only and must be removed rather than supported through compatibility branches.

Generic content matching is not part of the architecture. Existing skills.sh installations are adopted only through their explicit lock source identity followed by exact selected-member file verification. A future same-name search may present human-reviewed candidates, but it must not infer identity or ownership from content and requires a separate decision before implementation.
