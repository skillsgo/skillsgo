# SkillsGo Repository Constitution

## Mandatory Routing

Before changing any file under `app/**`, read `app/AGENTS.md`.

Before changing any file under `cli/**`, read `cli/AGENTS.md`.

Before changing any file under `hub/**`, read `hub/AGENTS.md`. When the path is inside a nested Go module, also read that module's nearest `AGENTS.md`.

Before changing any file under `protocol/**`, read `protocol/AGENTS.md`.

Before changing reusable standards under `docs/reference/**`, read `docs/reference/AGENTS.md`.

Before changing cross-context decisions under `docs/adr/**`, read `docs/adr/AGENTS.md`.

The nearest `AGENTS.md` adds local constraints but never cancels a parent rule unless it explicitly documents a narrower exception.

## Documentation Language

All repository documentation must be written in English. This includes README files, GEB maps, File Contracts, domain glossaries, context maps, ADRs, specifications, implementation plans, release notes, and issue tracker content.

Do not add non-English documentation. When modifying an existing document, leave the complete edited document in English. User-facing application copy is not repository documentation and must continue to use the App's i18n system.

## Repository Architecture

```text
skillsgo/
├── protocol/  Shared executable Go contracts for CLI and Hub
├── app/       Flutter desktop App and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Go Hub, artifact protocol, identity, and search
├── web/       Public product, Hub, and documentation Web surface
├── e2e/       Split CLI/Hub container and App desktop end-to-end workspaces
└── docs/      Cross-context decisions, agent configuration, and standards
```

- The App invokes the bundled CLI for every Hub and local operation. In Cloud mode it may call the independently deployed SkillsGo Cloud origin declared by `skillsgo hub info` for Cloud-owned ranking reads; it never calls Hub HTTP directly.
- The CLI owns local filesystem mutations, Agent Adapters, Scope Vendors, Repository Projections, Installation Targets, Workspace Manifests, and Workspace Locks.
- The Hub owns public Skill identity, immutable artifacts, metadata, search, and minimal deployment discovery. The separate `skillsgo-cloud` service owns install-event aggregation and rankings in an independent database.
- The Protocol workspace owns dependency-light executable contracts that the CLI and Hub must interpret identically; it owns no transport or product orchestration.
- `CONTEXT-MAP.md` and the context glossaries define domain language. GEB maps define structural ownership. Neither substitutes for the other.

## Toolchain

- Root validation entry: `make test`.
- Unified macOS development entry: `make dev`; startup removes stale development processes owned by the current checkout, Process Compose supervises the topology, Air owns Hub rebuild/restart, the CLI is built before App startup, and `flutter run` owns App Hot Reload and terminal controls.
- App: Flutter; use `flutter analyze` and `flutter test` from `app/`.
- CLI: Go; use `gofmt` and `go test ./...` from `cli/`.
- Hub: Go; use `gofmt` and `go test ./...` from `hub/`.
- Protocol: Go; use `gofmt` and `go test ./...` from `protocol/`.
- Web: Node.js 22+, pnpm, TanStack Start, Vite, Fumadocs, and MDX; use `pnpm typecheck` and `pnpm build` from `web/`.
- E2E: use `make test-e2e-cli` for containerized CLI+Hub journeys, `make test-e2e-app` for macOS desktop App+CLI+Hub journeys, or `make test-e2e` for both.
- Prefer the highest existing behavior seam: `SkillsGateway` for App journeys, the CLI root execution entry for CLI behavior, and the HTTP Router for Hub behavior.
- Do not parse human-oriented CLI output in the App. Do not invoke local commands through shell-string interpolation.

Release architecture, tags, signing, and artifact matrices are defined in `docs/release-design.md`.

## Agent Skills

### Issue Tracker

This repository uses GitHub Issues in `skillsgo/skillsgo`. See `docs/agents/issue-tracker.md`.

### Triage Labels

This repository uses the default five-role triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain Docs

This repository uses a multi-context domain documentation layout for the App, CLI, and Hub. See `docs/agents/domain.md`.

## GEB Monorepo Fractal Documentation Protocol

The map IS the terrain. The terrain IS the map.

Code is the executable representation; documentation is the semantic representation. They must remain structurally aligned. The normative protocol is `docs/reference/geb-monorepo-protocol.md`; this root file contains only its executable summary.

### Five Fractal Levels

| Level | Name | SkillsGo anchor | Responsibility |
| --- | --- | --- | --- |
| F0 | Repo Constitution | `/AGENTS.md` | Repository-wide routing, architecture, toolchain, language, and protocol |
| F1 | Domain Map | `app/AGENTS.md`, `cli/AGENTS.md`, `hub/AGENTS.md`, `web/AGENTS.md`, standards maps | Domain boundaries, workspace index, and cross-context rules |
| F2 | Workspace Map | Every maintained `pubspec.yaml`, `go.mod`, or standalone `package.json` workspace | Runtime, entry points, commands, dependencies, exports, and top-level layout |
| F3 | Module Map | Stable multi-file source-module directories | Member inventory, local dependency direction, and invariants |
| F4 | File Contract | Header of semantic source or configuration files | INPUT, OUTPUT, and POS contract |

F2 is determined by a build manifest, not directory depth. In this repository:

- `app/pubspec.yaml` defines the Flutter workspace.
- `cli/go.mod` defines the CLI Go module.
- `hub/go.mod` defines the Hub Go module.
- `hub/scripts/liveness_probe/go.mod` defines a nested utility Go module.
- `web/package.json` defines the public Web workspace.
- `protocol/go.mod` defines the shared Protocol Go module.

Because each top-level product or protocol domain currently contains one primary workspace, `app/AGENTS.md`, `cli/AGENTS.md`, `hub/AGENTS.md`, `web/AGENTS.md`, and `protocol/AGENTS.md` intentionally serve as both F1 and F2 maps. Split them only when a domain gains multiple independently maintained workspaces.

### F3 Module Map Template

```markdown
# {Module Name}/
> F3 | Parent: `{parent-path}/AGENTS.md` | Workspace: `{module-name}`

## Members

- `{file}.{ext}`: responsibility, important technical detail, and key consumer.

## Architectural Boundary

This module owns ... It must not ...

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

Create F3 maps only for stable, multi-file modules with meaningful local architecture. Do not seed empty maps into every directory.

### F4 File Contract

Every semantic source file touched by an agent must carry an accurate F4 header unless the nearest F2 or F3 map documents an exemption.

Dart and Go use this contract in a block comment before imports or the `package` declaration:

```text
/*
 * [INPUT]: Depends on {module/file} for {specific capability}.
 * [OUTPUT]: Provides {exported functions/components/types/constants}.
 * [POS]: Serves as {role} in {module}, related to {siblings/consumers}.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
```

Semantic YAML, TOML, shell, and workflow entry files use the same four fields with their native line-comment syntax.

INPUT states concrete dependencies. OUTPUT states the externally meaningful surface. POS states why the file exists and how it relates to siblings and consumers.

Default exemptions:

- generated output, localization generators, build artifacts, coverage, and snapshots;
- lockfiles, pure data fixtures, images, fonts, binaries, and archives;
- vendored or upstream-maintained third-party trees;
- trivial re-export barrels that are not a public API source of truth.

An exempt file that becomes a semantic source of truth loses the exemption.

### Mandatory Work Loop

Before work:

```text
Target file
  -> find and read the nearest AGENTS.md
  -> find the nearest pubspec.yaml or go.mod workspace boundary
  -> read the workspace/domain AGENTS.md
  -> read the relevant CONTEXT.md and ADRs
  -> check the target file's F4 contract or documented exemption
  -> begin the change
```

After work:

```text
F4: do INPUT / OUTPUT / POS still match reality?
  -> F3: did members, responsibilities, local interfaces, or dependency direction change?
  -> F2: did entry points, commands, dependencies, runtime, exports, or deployment change?
  -> F1: did domain workspaces or cross-context boundaries change?
  -> F0: did repository architecture, global workflow, or production facts change?
```

Update only the levels whose facts changed. Documentation is a map, not ceremonial churn.

### Migration Rule

Do not mechanically add F3 maps or F4 headers across the repository. Migrate on touch:

- when changing a semantic source file without F4, add an accurate F4 in the same change;
- when a touched stable module lacks F3 and understanding depends on several cooperating files, add its F3 map;
- when adding a new `pubspec.yaml` or `go.mod`, add or update the owning F1 and create an F2 map;
- when moving or deleting a file listed by F3, update the F3 member inventory in the same change.

### Forbidden States

- **FATAL-001 — Isolated code change**: code changed without checking the documentation loop.
- **FATAL-002 — Missing on-touch F4**: a touched semantic file lacks a File Contract and is not exempt.
- **FATAL-003 — Stale F3 inventory**: a listed file was moved, deleted, or repurposed without updating its Module Map.
- **FATAL-004 — Unmapped workspace**: a maintained `pubspec.yaml` or `go.mod` was added without an F2 map and owning F1 update.
- **SEVERE-001 — Stale contract**: F4 no longer describes imports, exports, role, or consumers.
- **SEVERE-002 — Broken parent chain**: an F2/F3 map cannot reach its parent `AGENTS.md`.
- **SEVERE-003 — Wrong protocol target**: a File Contract points anywhere other than `AGENTS.md`.

### Fixed Protocol Line

Every F3 map and F4 File Contract must contain this exact line:

```text
[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

Maintain the five levels, complete the documentation loop, and reject isolated changes.
