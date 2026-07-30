---
status: accepted
---

# Distribute Repository Versions and project selected Skills

ADR-0019 supersedes this decision's complete Source Repository tree and Package-relative cross-member resource assumptions. A Package Version now contains a filtered Package tree made from the minimal union of conventionally discovered self-contained Skill directory subtrees and applicable plugin manifests while remaining the version, Sum, lock, and Store unit.

SkillsGo distributes one immutable artifact per Repository Version instead of one artifact per Skill. A Repository is the publication, version, ZIP, Go-compatible `h1:`, download, lock, and Package Store unit; a Skill remains a discoverable Repository member and the unit of user selection and Agent visibility. This supersedes the `/mod` namespace and local declaration decisions in ADR-0004 and the Skill ZIP, Skill Sum, shared Store, symlink/copy mode, `skillsgo.mod`, and `skillsgo.sum` decisions in ADR-0009 before public launch.

## Decision

A Repository Publication resolves one source revision, discovers its complete ordered Skill membership, archives the minimal safe Git-tracked union of those Skill directory subtrees plus applicable ancestor plugin manifests under `<repositoryId>@<version>/`, including only symlinks that resolve inside the Package Artifact, and computes `h1:` with the same full-name `dirhash.Hash1` semantics as Go Module `HashZip`. The ZIP prefix participates in the Sum, so identical bytes published under another Repository ID or immutable version have a different authenticated coordinate. ZIP and Sum use exactly the same file set. Skills have a canonical Repository-unique name and an immutable-version-relative source path, but no concatenated public Skill ID, independent ZIP, archive size, or artifact Sum. SumDB can therefore authenticate Repository Versions in the same way that Go authenticates Package Versions; Skills correspond to packages within that versioned tree.

`add` accepts the Go Package Version Query forms: exact semantic version, semantic-version prefix or comparison, `latest`, branch, Tag, or commit. SkillsGo defines no separate `head` alias. A query is resolved once to its immutable commit and canonical semantic or Go-compatible pseudo-version. Only that immutable version is persisted, published, downloaded, and served by the Package Distribution API; `install` never resolves the original query again. Public resources are `GET /api/v1/{packagePath}/versions`, `GET /api/v1/{packagePath}/versions/{version}`, and `GET /api/v1/{packagePath}/versions/{version}.zip`. Skill search and detail APIs identify a member with separate Package Path and canonical Skill Name fields; Skill Path is source-location metadata within the immutable release.

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

Project Scope stores the verified Package under `<workspace>/.skillsgo/packages`; Global Scope stores it under `~/.skillsgo/packages`, while Global Scope `skills.yaml` and `skills-lock.yaml` live under `~/.agents`. SkillsGo does not read, modify, or prescribe `.gitignore`, does not stage files, and does not model whether a Workspace commits Package Store or generated Agent files. Teams may commit both for clone-and-use behavior or ignore both and run `skillsgo install`. Version-one `install` is an idempotent ensure operation over `skills.yaml` and `skills-lock.yaml`: it fills missing verified Package Stores and Projections, but does not update versions, reconcile remote selectors, delete extras, or provide a general `sync` operation.

For each Scope and physical Agent Managed Skill Root, the Agent Adapter creates one stable direct entry per selected member at `<managed-root>/<canonical-skill-name>`. Each entry is a relative symlink to the member directory inside that Scope's verified immutable Package Store. Package coordinates therefore remain private Store paths rather than appearing as Agent Skill names, while every selected Skill retains its complete self-contained directory subtree. The transaction rejects canonical-name collisions unless the caller explicitly authorized replacement, atomically retargets entries during version changes, and removes legacy `<packagePath>@<version>` Agent projections after verifying their deterministic baseline. Package Store is authoritative and immutable. A link or Store that differs from its expected state is a Local Modification: `install` reports a conflict and never overwrites or absorbs it, leaving recovery to the user. Package-internal symlinks that are absolute, broken, cyclic, or escape the Package remain invalid; Agent entries may link only into the current Scope Package Store.

## Consequences

Multi-Skill repositories such as gstack are downloaded and stored once per Scope and version and no longer duplicate an artifact for every member or Agent. Each accepted Skill contributes only its self-contained directory subtree, while Git objects deduplicate identical content across members and Versions. Agent-visible links use relative targets so moving a complete Workspace preserves Project Scope topology. Platforms that cannot create filesystem symlinks must fail the mutation clearly instead of publishing an undiscoverable or partial Skill layout. Package Artifacts may be larger than a selected Skill, so protocol size limits remain mandatory. Existing per-Skill artifact code, data, routes, manifests, sums, Store behavior, receipts, and tests are migration inputs only and must be removed rather than supported through compatibility branches.

Generic content matching is not part of the architecture. Existing skills.sh installations are adopted only through their explicit lock source identity followed by exact selected-member file verification. A future same-name search may present human-reviewed candidates, but it must not infer identity or ownership from content and requires a separate decision before implementation.
