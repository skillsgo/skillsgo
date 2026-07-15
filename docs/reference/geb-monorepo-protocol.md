# GEB Monorepo Fractal Documentation Protocol

> Scope: all maintained source code, semantic configuration, specifications, and Agent-owned structural maps in the SkillsGo monorepo.

The map IS the terrain. The terrain IS the map.

Code is the executable representation of the system. Documentation is its semantic representation. A structural change in either representation must become visible in the other.

## Core Boundary Rule

A single-package repository can often use project, module, and file documentation. A monorepo needs an additional distinction between product domains and independently built workspaces.

SkillsGo boundaries are semantic rather than depth-based:

- `app/`, `cli/`, and `registry/` define product and runtime domains.
- `pubspec.yaml` and `go.mod` define buildable and testable workspaces.
- stable multi-file source directories define modules.
- source headers define individual file contracts.

The protocol therefore uses five levels.

## Five Levels

| Level | Name | Anchor | Responsibility | Update trigger |
| --- | --- | --- | --- | --- |
| F0 | Repo Constitution | root `AGENTS.md` | Global routing, architecture, tools, language, and workflow | Top-level domain, delivery, or global workflow changes |
| F1 | Domain Map | Domain `AGENTS.md` files | Domain boundary, workspace index, and cross-context rules | Workspace or domain responsibility changes |
| F2 | Workspace Map | Every maintained `pubspec.yaml` or `go.mod` root | Runtime, public entry, commands, dependencies, and top-level structure | Entry, dependency, runtime, script, export, or delivery changes |
| F3 | Module Map | Stable multi-file module directory | Member inventory, dependency direction, and local invariants | File membership, responsibility, or local interface changes |
| F4 | File Contract | Semantic file header | INPUT, OUTPUT, and POS | Dependency, surface, role, or consumer changes |

F2 is always selected from the nearest build manifest, never from an assumed directory depth.

## SkillsGo Workspace Anchors

- `app/pubspec.yaml`: Flutter desktop App workspace.
- `cli/go.mod`: standalone and bundled CLI workspace.
- `registry/go.mod`: Registry service workspace.
- `registry/scripts/liveness_probe/go.mod`: nested CI liveness utility workspace.

`registry/docs/themes/hugo-theme-relearn/go.mod` is part of a vendored upstream documentation theme, not a maintained SkillsGo workspace. It is exempt from F2 and F4 maintenance unless ownership is intentionally brought into the repository.

A future nested `go.mod` or `pubspec.yaml` creates another F2 boundary even when it sits inside an existing F1 domain.

## F0: Repo Constitution

The root map stores only repository-wide facts:

- mandatory routing to child maps;
- domain overview and cross-context dependency direction;
- global toolchain and testing entry points;
- documentation language;
- release-design pointer;
- GEB summary and normative-reference pointer.

F0 never maintains ordinary source-file inventories. Those belong to F3.

## F1: Domain Map

The current F1 domains are:

- App: desktop experience and orchestration;
- CLI: local execution and Agent integration;
- Registry: public identity, artifact distribution, and discovery;
- Reference documentation: reusable protocol sources.

An F1 map lists its workspaces, explains cross-context dependency rules, and points to deeper maps. It does not duplicate every source-file responsibility.

Because each product domain currently has one primary workspace, its domain map and primary workspace map may share one `AGENTS.md`. This is deliberate co-location, not a collapse of the conceptual levels.

## F2: Workspace Map

Every maintained manifest root must have a clear F2 map or be explicitly covered by a co-located F1/F2 map. An F2 describes:

- module or package identity;
- runtime and executable entry points;
- public or machine-facing interfaces;
- build, format, analyze, and test commands;
- allowed and forbidden dependency directions;
- top-level directory responsibilities;
- F4 exemptions specific to that workspace.

Adding a nested module without an F2 creates a documentation blind spot.

## F3: Module Map

Create an F3 only when a directory has stable local architecture:

- several files collaborate around one responsibility;
- the module has meaningful invariants or dependency direction;
- several consumers rely on a stable public surface;
- membership changes would otherwise be expensive to understand.

Template:

```markdown
# {Module Name}/
> F3 | Parent: `{parent-path}/AGENTS.md` | Workspace: `{module-name}`

## Members

- `{file}.{ext}`: responsibility, important technical detail, and key consumer.

## Architectural Boundary

This module owns ... It must not ...

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

Do not create F3 maps for tiny or unstable directories merely to satisfy a directory-depth pattern.

## F4: File Contract

F4 lets an Agent understand a file's place without first reading the complete implementation.

Dart and Go template:

```text
/*
 * [INPUT]: Depends on {module/file} for {specific capability}.
 * [OUTPUT]: Provides {exported functions/components/types/constants}.
 * [POS]: Serves as {role} in {module}, related to {siblings/consumers}.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
```

For Go, place the contract after build tags and mandatory license headers but before the `package` declaration. For Dart, place it before imports or library declarations. Semantic configuration and scripts use the same fields in their native comment syntax.

INPUT identifies concrete dependencies and the capability consumed. OUTPUT identifies the externally meaningful surface. POS explains the file's role and relationship to siblings and consumers.

Default F4 targets:

- App domain, infrastructure, UI, entry, and behavior-test files;
- CLI command, Agent, install, project, Registry-client, source, Store, and behavior-test files;
- Registry command, API, protocol, catalog, Skill, configuration, storage, and behavior-test files;
- cross-context configuration truth sources and deployment entry points.

Default exemptions:

- generated Dart localization files, generated code, build output, coverage, and snapshots;
- lockfiles, pure fixtures, images, fonts, binaries, and archives;
- vendored upstream source and inherited documentation themes;
- trivial barrels that only re-export and are not a public API truth source.

The nearest F2 or F3 may refine exemptions. If an exempt file becomes semantic, the exemption ends.

## Work Entry Loop

```text
Select target
  -> walk upward to the nearest AGENTS.md
  -> locate the nearest pubspec.yaml or go.mod
  -> read the workspace and domain maps
  -> read relevant CONTEXT.md and ADRs
  -> validate F4 or the documented exemption
  -> perform the work
```

Root mandatory-routing rules take precedence when they name the target path.

## Post-change Documentation Loop

```text
Change complete
  -> F4: do INPUT, OUTPUT, and POS still describe reality?
  -> F3: did membership, responsibility, local interfaces, or dependency direction change?
  -> F2: did entries, commands, dependencies, runtime, exports, or delivery change?
  -> F1: did workspace ownership or cross-context boundaries change?
  -> F0: did global architecture, workflow, or production facts change?
```

Only update levels whose facts changed.

## Forbidden States

- Modify semantic code without checking the nearest maps and File Contract.
- Touch a semantic source without creating or correcting its on-touch F4.
- Delete, move, rename, or repurpose an F3 member without updating the member inventory.
- Add a maintained `pubspec.yaml` or `go.mod` without mapping the F2 workspace and F1 owner.
- Change entry points, dependencies, runtime boundaries, or release scripts without updating F2.
- Point the fixed protocol line to `CLAUDE.md`, a README, or any target other than `AGENTS.md`.
- Create empty AGENTS files for directories without stable boundaries.

## Incremental Migration

The repository predates GEB, so migration is on touch rather than a mechanical repository-wide comment rewrite.

1. Establish F0, current F1/F2 maps, and the normative reference.
2. Add F3 when a stable touched module needs a local map.
3. Add or correct F4 whenever a semantic file is touched.
4. Update parent maps in the same change as structural moves.
5. Never use incremental migration as permission to leave a touched file undocumented.

## Quality Check

- Can every maintained workspace be found from `pubspec.yaml` or `go.mod`, with vendored manifests explicitly classified? If not, F2 anchoring is wrong.
- Does an F1 list ordinary implementation files? If so, it is too detailed.
- Does a stable multi-file module require whole-repository archaeology? If so, add F3.
- Does each touched F4 match real dependencies, outputs, and consumers? If not, it has decayed.
- Can every child map reach the root through parent links? If not, the fractal is broken.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
