---
status: accepted
---

# Publish conventional Skill directory subtrees

## Context

SkillsGo previously discovered every repository-owned `SKILL.md` recursively and published the complete safe Git-tracked Source Repository tree. Large application monorepos can contain a small conventional `skills/` catalog beside thousands of unrelated source files. Complete-tree publication rejects those repositories at the Package Artifact limits and retains files that no installed Skill can use portably.

The Agent Skills resource model roots one Skill at the directory containing its `SKILL.md`. Scripts, references, assets, and other bundled resources belong beneath that directory. A Skill that requires a repository-relative file outside its own directory is not a portable Skill and is not a distribution behavior SkillsGo preserves.

The skills.sh CLI already defines a widely deployed, convention-first discovery order that avoids treating every incidental `SKILL.md` in a monorepo as a published catalog member.

## Decision

Hub adopts the skills.sh directory-discovery policy for Source Repository publication:

1. A valid `SKILL.md` at the search root is the sole default member.
2. Otherwise Hub merges valid Skills from direct root children, `skills/`, the curated, experimental, and system subcontainers, and the maintained Agent-specific project Skill containers.
3. Conventional containers accept `container/<skill>/SKILL.md` and `container/<category>/<skill>/SKILL.md`. A Skill at the shallower directory shadows nested candidates beneath that directory.
4. If a discovery tier contains candidates but none has a valid manifest, Hub continues to the next tier.
5. Only when no conventional tier yields a valid Skill does Hub fall back to a recursive search bounded to five directory levels and skip dependency, VCS, build-output, and bytecode-cache directories.

SkillsGo retains its existing Package membership identity: distinct Skill Paths may declare the same canonical Skill Name and remain distinct members. Directory precedence determines the candidate set; it does not silently collapse accepted members by name.

One Package Version and one Package Sum continue to cover the complete accepted membership, but its installable Artifact tree is now the minimal union of every accepted member's complete Skill directory subtree. Repository-relative paths remain unchanged. Duplicate and nested roots are normalized before projection; a parent Skill directory includes its descendant tree only once. A valid root `SKILL.md` has the Source Repository root as its Skill directory and therefore intentionally includes the complete safe tracked tree.

Hub does not add an include/exclude publication manifest. Source authors make every Skill directory self-contained. Files outside accepted Skill directory subtrees do not enter the Artifact, Package Sum, Git Artifact Repository, CLI cache, or Scope Package Tree.

This decision supersedes the complete-Source-Repository-tree and cross-member shared-file assumptions in ADR-0010, ADR-0016, and ADR-0017. It preserves their Package-level version, Sum, Git repository, lock, cache, materialization, and selected-member projection decisions.

## Consequences

- Application monorepos with a conventional root `skills/` catalog can publish without shipping unrelated application source.
- Copied or generated Skill mirrors in deeper non-conventional package source directories do not compete with the conventional catalog during default discovery.
- One Git Artifact Repository still deduplicates identical Blobs across members and Versions even though each Skill carries its own complete resources.
- Package and Scope trees contain only published Skill subtrees rather than complete Source Repository snapshots.
- Repository-level files cannot be used as implicit shared Skill runtime resources. Authors must place required resources inside each Skill directory.
- Root Skills remain potentially large because the repository root is their declared Skill directory; ordinary Artifact file and byte limits reject unsafe or oversized roots precisely.

[PROTOCOL]: Update this document when discovery precedence or Artifact subtree boundaries change, then review AGENTS.md
