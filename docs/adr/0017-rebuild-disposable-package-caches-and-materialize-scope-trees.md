# ADR-0017: Rebuild Disposable Package Caches and Materialize Scope Trees

## Status

Accepted

## Decision

SkillsGo separates portable authority, shared acquisition cache, and Scope-local materialization:

```text
skills.yaml + skills-lock.yaml
        -> ~/.skillsgo/cache/info and ~/.skillsgo/cache/packages
        -> <scope>/.skillsgo/packages/<package>@<version>
        -> platform-native Agent Skill links
```

The authoritative local state is `skills.yaml` plus `skills-lock.yaml`. Exact Package Info, Git objects, and expanded Scope Package Trees are derived state that may be rebuilt from the Hub and its immutable Git Artifact Repository. Agent Projections remain protected generated state because users or external tools may modify their paths.

Project Scope stores complete Package Trees under `<project>/.skillsgo/packages`. Global Scope uses the same layout under its declaration root: `~/.agents/.skillsgo/packages`. The former `~/.skillsgo/packages` location is removed. `~/.skillsgo` owns shared caches and user configuration, not a Global Scope Package Tree.

This decision supersedes the authority, Global Store location, command-specific cache-read, and platform Projection portions of ADR-0010, ADR-0015, and ADR-0016. Their complete-Package materialization, immutable identity, `h1:` integrity, static Git distribution, update scope, and atomic publication decisions remain accepted.

## Context

The CLI previously read `~/.skillsgo/cache/info` and Scope Package Stores directly. A missing Info entry caused commands such as `list` to fail even when Manifest, Lock, Package Tree, Projection, and immutable Hub resources remained valid. Global materialization also lived under `~/.skillsgo/packages`, mixing Scope state with user-level cache and configuration.

Removing complete Package Trees is not correct. A nested Skill may reference Package-relative resources above its own directory:

```text
shared/scripts/validate.sh
skills/review/SKILL.md  -> ../../shared/scripts/validate.sh
```

The complete Package Tree plus a symlink to `skills/review` preserves that relationship. Copying only the member subtree would break it, while copying a complete Package for every selected Skill or Agent would multiply disk use.

## State model

Portable local authority:

- `<scope>/skills.yaml`, containing exact selected Package versions, Skill selectors, and Agents;
- `<scope>/skills-lock.yaml`, binding each Package Path and immutable Version to Package `h1:`.

Shared disposable acquisition cache:

- `~/.skillsgo/cache/info`, containing exact Package Info bytes;
- `~/.skillsgo/cache/packages`, containing bare go-git object databases synchronized from static Artifact repositories.

Scope-local derived materialization:

- `<project>/.skillsgo/packages/<package>@<version>` for Project Scope;
- `~/.agents/.skillsgo/packages/<package>@<version>` for Global Scope.

Agent-visible Projection:

- `<managed-root>/<canonical-skill-name>`, a relative symlink on macOS and Linux or an absolute directory junction on Windows to the selected member inside the Scope Package Tree.

Deleting `~/.skillsgo` removes shared acquisition caches but leaves Global declarations, Global Package Trees, Project Package Trees, and Agent Projections intact. Any command that needs missing shared cache data rebuilds it automatically. Deleting a Scope Package Tree is repaired by `install` from the exact Manifest and Lock without movable resolution.

## Capability-based Package Provider

Every consumer requests exact dependencies through one Package Provider. Commands and inventory must not require Info or Git cache entries to preexist.

The Provider exposes two capabilities:

1. Metadata accepts Package Path, immutable Version, and locked `h1:`. It validates cached Package Info or fetches the exact Version from Hub, verifies identity and Sum, and atomically replaces a missing or corrupt entry.
2. Content first resolves Metadata, then restores the tagged Git tree through the static Artifact Repository, validates the complete coordinate-bound Package `h1:`, and returns ordered Artifact entries.

Metadata-only operations such as `list` and `why` request only Metadata. Explicit `verify` and every operation that creates, replaces, removes, or restores a Package Tree or Projection request Content. Frozen Manifest and Lock state does not prohibit derived cache writes.

## Scope Package Tree and Projection semantics

The CLI always stages and validates the complete exact Package Tree before publishing it under the Scope declaration root. Package-relative files and safe internal symlinks therefore retain their repository relationships.

Each selected Skill is exposed through a stable platform-native directory link from its Agent Managed Skill Root into that Tree. macOS and Linux use a relative symlink, preserving Project Scope topology when the complete Workspace moves. Windows uses an unprivileged absolute directory junction because ordinary desktop users cannot reliably create symbolic links. Several Agents and selected members in the same Scope share the same complete Package Tree. Different Scopes retain independent trees so each Scope transaction, declaration, lock, and Projection topology remains self-contained.

The Package Tree is derived but verified. A missing Tree may be recreated from locked Git content. A differing Tree or Projection is a Local Modification and is never silently overwritten. Every mutation derives the exact previous and desired baselines, rejects differences without authorization, stages sibling temporary paths, atomically renames targets, and retains reverse rollback.

## Inventory and recovery

Inventory reads Manifest and Lock, requests exact Metadata through the Provider, verifies the Scope Package Tree against the locked `h1:`, and verifies Agent Projection links. A missing shared Info entry is transparently rebuilt. One missing cache record can no longer turn valid local state into an opaque application-level service failure.

Explicit `verify` additionally requests exact Git Content, ensuring acquisition cache reconstruction and content comparison use the same locked artifact. `install` is the general idempotent repair operation for missing Scope Package Trees and Projections.

## Consequences

Benefits:

- clearing `~/.skillsgo` no longer invalidates installed inventory;
- all commands receive consistent metadata/content acquisition through one boundary;
- Global Scope data is colocated under its declaration root instead of mixed into user cache state;
- complete Package-relative resource behavior remains intact;
- one expanded Package Tree is shared by all selected members and Agents within a Scope;
- corrupt shared cache entries are repaired from exact immutable resources;
- Local Modifications remain protected by deterministic baselines.

Costs:

- Git objects and expanded Scope Package Trees both occupy disk;
- the same Package Version used in several Scopes has one expanded copy per Scope;
- exact verification may perform network I/O after shared cache deletion;
- clearing a Project's `.skillsgo/packages` requires `skillsgo install` for that Scope.
- moving a Windows Project invalidates its absolute junctions and requires `skillsgo install` in the moved Workspace to rebuild Projections.

These costs are accepted. File-level cross-Scope materialization deduplication, copy-on-write clones, or a virtual filesystem require measured evidence and separate decisions. None may make shared cache state authoritative.

[PROTOCOL]: Update this document when cache authority, Provider capabilities, Scope Package Tree location, or Projection materialization changes, then review AGENTS.md
