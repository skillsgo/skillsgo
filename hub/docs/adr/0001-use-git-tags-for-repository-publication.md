# ADR 0001: Publish Repository Versions Lazily from Git Tags

- Status: Accepted
- Date: 2026-07-18

## Context

SkillsGo must distribute a large, mostly cold catalog without polling every registered repository. Source-host work must scale by Repository rather than by the number of Skills inside it, while exact artifacts remain immutable and independently downloadable.

GitHub Releases are optional presentation objects. Git semantic-version tags are the portable immutable version declaration across GitHub, GitLab, and other Git hosts. Branches and commits remain useful explicit Version Queries but must never become background subscriptions.

## Decision

The Hub implements a demand-driven, Go Module Proxy-shaped protocol:

- A bare coordinate identifies a Source Repository and its root Skill artifact, for example `gitlab.example.com/group/subgroup/repo`.
- A nested Skill uses `{repository}/-/{non-empty-path}`. The reserved `/-/` boundary avoids assumptions about Git namespace depth.
- Repository and nested-Skill resources use `@v/list`, `@latest`, `@v/{query}.info`, and per-Skill `@v/{version}.zip`.
- Repository Info embeds the complete Skill Info for every valid member observed at one commit. There is no Repository aggregate ZIP.
- Exact semantic-version Info requests bypass mutable catalog freshness and materialize the requested tag directly on a miss.
- `latest` prefers the highest stable semantic version, then the highest prerelease. When no semantic tag exists, it resolves the remote default branch once to a pseudo-version.
- Branches and commits resolve through `.info` to a canonical semantic or pseudo-version. Clients persist only that immutable result.

There is no dedicated refresh endpoint, webhook requirement, mandatory private refresher, or Hub-specific publish operation. Optional warming uses ordinary List, Latest, Info, or CLI add requests.

## Lazy Catalog and Publication

`@v/list` reads a short-lived operational tag catalog. A stale or missing catalog triggers one per-Repository singleflight source refresh; successful and negative results have bounded TTLs, and global source work is bounded. The TTL is deployment configuration, not protocol compatibility.

An immutable Repository Info miss resolves one revision to one commit, fetches the Repository once, scans `SKILL.md` candidates once, produces each valid deterministic per-Skill ZIP from that snapshot, and publishes the accepted member versions. Concurrent requests for the same Repository query share publication work. Invalid candidates create no Hub records and do not block valid siblings.

A canonical tag permanently maps to its first published commit. A later moved tag is an immutable-version conflict and never overwrites stored Info or ZIP content. A Skill absent from a later tag is absent from that Repository Info; historical per-Skill artifacts remain available.

## Persistence

The `repositories` registry stores one case-normalized source host and Repository path. Skills reference their Repository through `repository_id`; repository-relative Skill path casing is preserved.

Existing `skill_versions` rows remain the immutable source for version, commit, tree, digest, commit time, and archive size. A Repository publication is reconstructed from rows sharing `repository_id`, version, and commit. No Repository Version, Repository Batch, or persisted Repository Member aggregate table is introduced.

The telemetry tables are named `skill_install_events` and `skill_risk_assessments`.

## Consequences

- Unrequested repositories cause no scheduled source-host work.
- One Repository fetch produces all valid member artifacts while downloads continue to use per-Skill routes.
- Authors publish by pushing canonical semantic-version tags; GitHub Release creation is irrelevant.
- The Repository registry remains useful for catalog ownership and optional external warming, but it is not a scheduling queue.
- Exact immutable cache hits contact neither the source host nor a mutable version catalog.
