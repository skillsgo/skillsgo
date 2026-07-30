---
status: accepted
---

# Publish only Package content transitions

## Context

SkillsGo versions a Package from immutable upstream revisions. In a dedicated Skill repository, an upstream tag usually represents a meaningful Package change. In a mixed application repository such as a large monorepo, most tags can change only application code that ADR-0019 excludes from the filtered Package Artifact. Treating every such tag as an independent published Package Version creates duplicate Git tags and Catalog membership, consumes storage, and repeatedly tells users that an update exists when the installable Skills did not change.

The coordinate-bound Package `sum` cannot identify this condition because its hash includes Package Path and Version. SkillsGo still needs to remember that an exact upstream Version was inspected so retries and exact-version requests remain deterministic.

## Decision

Hub computes `content_sum` from the final normalized Package Artifact entries after Skill discovery, subtree filtering, authored root README retention, authored plugin-manifest retention, and generation of missing root plugin manifests. It uses the existing Package h1 algorithm over each normalized relative path and file bytes, but excludes Package Path and Version. Entry ordering cannot affect the result.

Every observed Version is one of two states:

- An effective Version has `equivalent_version IS NULL`, owns a coordinate-bound `sum`, Git Artifact tag, Skill membership, and Skill content references.
- An equivalent observed Version has `equivalent_version` set directly to the immediately preceding effective Version with identical `content_sum`. It has no `sum`, Git Artifact tag, or Skill membership of its own.

The database enforces this exclusive ownership shape. `equivalent_version` is a same-Package self-reference to an effective Version string; SkillsGo does not create a separate alias table or chains of aliases.

Publication for one Package runs under one advisory lock. Current publication compares the candidate with the current effective Version. Historical Backfill processes canonical revisions in ascending order and compares adjacent content states, retaining this state across bounded flushes. Equal adjacent content records only an equivalent observed Version. Changed content publishes a new effective Version.

Equivalence represents transitions, not global content deduplication. For the sequence A, B, A, all three Versions are effective: the third Version is a real update from B even though its bytes appeared earlier. For A, A, B, the second Version is equivalent to the first and the third is effective.

Public Version lists, current-version selection, update checks, search, and discovery expose only effective Versions. An exact request for an equivalent observed Version resolves to its effective Version and returns that Version's Package Info and Skill membership. Source-commit inspection continues to return the commit recorded for the exact observed Version, allowing Backfill retries to recognize completed work.

No compatibility or migration path is provided. The pre-launch Catalog and R2 data are disposable and are rebuilt from the clean schema and upstream sources.

## Consequences

- Unrelated upstream tags no longer create installable updates or duplicate Git Artifact generations.
- `content_sum` is the stable identity of filtered installable bytes; `sum` remains the integrity identity of one effective Package coordinate.
- Exact historical tags remain deterministic without duplicating artifacts or membership rows.
- Storage and publication work scale with Package content transitions rather than repository tag count.
- Adding or removing an authored README, changing an applicable plugin manifest, or changing generated manifest membership is a Package content change and publishes a Version.
- Equivalent Versions cannot independently become current because they own no artifact; they resolve to the effective Version users can install.
- Backfill order is semantically significant and must remain canonical and ascending.

[PROTOCOL]: Update this document when Package content identity, equivalence, or effective-Version visibility changes, then review AGENTS.md
