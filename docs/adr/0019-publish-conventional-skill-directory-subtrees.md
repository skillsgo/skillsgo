---
status: accepted
---

# Publish filtered Package Artifacts from conventional Skill directories

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

One Package Version and one Package Sum continue to cover the complete accepted membership, but its installable Artifact tree is now a filtered Package tree: the minimal union of every accepted member's complete Skill directory subtree plus applicable plugin manifests at ancestor Package directories. Repository-relative paths remain unchanged. Duplicate and nested roots are normalized before projection; a parent Skill directory includes its descendant tree only once. A valid root `SKILL.md` has the Source Repository root as its Skill directory and therefore intentionally includes the complete safe tracked tree.

The retained plugin manifests are `.codex-plugin/plugin.json`, `.claude-plugin/plugin.json`, and `.cursor-plugin/plugin.json`. A Source manifest enters the Artifact only when the directory that owns its hidden manifest directory is the Package root or an ancestor of an accepted Skill directory. All authored manifests retain their original relative paths and complete bytes.

Hub additionally guarantees all three root manifests in every published Package Artifact. It never overwrites an authored root manifest. Missing kinds are generated with one common namespace and an explicit, sorted `skills` list containing the accepted Package-relative Skill directories. An authored root namespace becomes the common namespace; multiple authored root manifests with different non-empty names fail publication precisely. When no authored root namespace exists, Hub derives a stable lowercase namespace from all Package Path segments after the source host, joining normalized segments with hyphens. Generated manifests contain no version-dependent identity and therefore remain byte-stable whenever Package identity and membership remain unchanged.

This lets Codex and other Agents follow a Package member Projection, resolve the canonical target, walk its Package ancestors, and apply their native manifest precedence and namespace behavior. Nested authored manifests can still override the generated root fallback for their own descendant Skills.

Hub does not add an include/exclude publication manifest. Source authors make every Skill directory self-contained except for the supported plugin manifests that provide Agent runtime context rather than Skill-owned executable resources. Other files outside accepted Skill directory subtrees do not enter the Artifact, Package Sum, Git Artifact Repository, CLI cache, or Scope Package Tree.

This decision supersedes the complete-Source-Repository-tree and cross-member shared-file assumptions in ADR-0010, ADR-0016, and ADR-0017. It preserves their Package-level version, Sum, Git repository, lock, cache, materialization, and selected-member projection decisions.

## Consequences

- Application monorepos with a conventional root `skills/` catalog can publish without shipping unrelated application source.
- Copied or generated Skill mirrors in deeper non-conventional package source directories do not compete with the conventional catalog during default discovery.
- One Git Artifact Repository still deduplicates identical Blobs across members and Versions even though each Skill carries its own complete resources.
- Package and Scope trees contain published Skill subtrees plus applicable plugin manifests rather than complete Source Repository snapshots.
- Plugin namespaces survive installation because Agent Projections resolve into the filtered Package topology. Packages without authored plugin metadata gain one deterministic cross-Agent namespace; authored root namespaces remain authoritative, and the CLI does not synthesize runtime envelopes or modify `SKILL.md` names.
- A previously unnamespaced Source now presents namespaced Skills after publication. This visible identity is deliberate and is shared across Codex, Claude, and Cursor manifests.
- Repository-level files cannot be used as implicit shared Skill runtime resources. Authors must place required resources inside each Skill directory.
- Root Skills remain potentially large because the repository root is their declared Skill directory; ordinary Artifact file and byte limits reject unsafe or oversized roots precisely.

[PROTOCOL]: Update this document when discovery precedence or Artifact subtree boundaries change, then review AGENTS.md
