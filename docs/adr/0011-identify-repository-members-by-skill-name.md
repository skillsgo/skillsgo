---
status: accepted
---

# Identify Repository members by Skill name

SkillsGo identifies a selectable Skill by the pair `Repository ID + Skill Name`. It does not expose a concatenated public Skill ID and does not use the former `/-/` separator. Skill Path remains immutable metadata within one Repository Publication and locates the member's files in that exact Repository Version; it is not normal user input and does not define logical continuity across versions.

Every published `SKILL.md` must declare a canonical Skill Name. Names are normalized and validated by one Protocol rule and must be unique within the complete accepted membership of a Repository Publication. A duplicate name rejects the whole publication; the Hub never chooses one member by path or invents a suffix. The root Skill follows the same rule and is selected by its declared name rather than `"."`. Display titles and descriptions are presentation metadata and do not replace the canonical Skill Name.

`skillsgo.yaml` stores canonical Skill Names in each dependency's `skills` list. Repository Info stores each member's Name and source-relative Skill Path so the CLI can resolve a selected name to physical files after authenticating the exact Repository Version. Product search, detail, batch update, and installation contracts carry `repositoryId` and `skillName` as separate fields; responses may additionally expose `skillPath` as immutable source-location metadata. Internal database row IDs remain implementation details.

A member may move to another source directory without changing its logical selection identity if its canonical Skill Name remains unchanged. Renaming a Skill removes the old member name and introduces a new one; an update that can no longer resolve a selected name fails without rewriting the declaration or projections. Same-name Skills in different Repositories remain distinct because Repository ID is part of the identity.

This decision supersedes ADR-0003 and the path-selected member portions of ADR-0010 before public launch. No compatibility parser, alias, or migration for public `Skill ID`, `/-/`, path-based Manifest members, or root `"."` selection is retained.
