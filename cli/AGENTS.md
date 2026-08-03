# SkillsGo CLI

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the Go command-line workspace. Read it with the root constitution and `CONTEXT.md` before changing CLI code.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/cli`
- Shared dependency: `github.com/skillsgo/skillsgo/protocol` through the repository `go.work` during development.
- Entry point: `cmd/skillsgo/main.go`
- Command seams: `command.Execute` for ordinary process calls and `command.ExecuteWithInput` for CLI Server requests with explicit stdin
- Product responsibility: own derived Scope Package Tree and Agent Projection mutations, canonical Workspace declarations and locks, disposable read-through Package metadata/Git caches, and installation-state inspection.

## Commands

Run from `cli/`:

```bash
go fmt ./...
go test ./...
make build
```

Use a narrower `gofmt` target when unrelated working-tree changes are present.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `cmd/skillsgo/` | Product process entry point and executable wiring. |
| `cmd/skillsgo-release-manifest/` | Release-only unsigned Manifest/checksum assembly entry point. |
| `osv-scanner.toml` | Evidence-backed exceptions for unfixable advisories whose vulnerable package is absent from the CLI build graph. |
| `internal/buildinfo/` | Immutable linker-injected CLI product, App bundle, distribution, commit, and build-time identity. |
| `bin/skillsgo` | Ignored local development binary produced by `make build`. |
| `internal/agent/` | Supported Agent definitions, detection, installation locations, and bounded local Agent project evidence. |
| `internal/command/` | CLI command graph, argument handling, and orchestration. |
| `internal/i18n/` | Locale detection and user-facing CLI messages. |
| `internal/install/` | Minimal installation-scope vocabulary and External filesystem state tokens. |
| `internal/inventory/` | Package-managed and External Library reconciliation across YAML/Lock state, read-through exact metadata, Scope Package Trees, member Projections, optional content verification, and derived Agent visibility. |
| `internal/skillusage/` | Read-only supported-Agent session evidence indexing and disposable rolling usage aggregates for local Library presentation. |
| `internal/managementplan/` | Exact-path External Remove planning, in-command state binding, and target-specific execution. |
| `internal/project/` | Strict Package dependencies in `skills.yaml`, integrity-only `skills-lock.yaml`, and their paired crash-recoverable transaction. |
| `internal/config/` | Strict, atomic user-level `~/.skillsgo/config.yaml` ownership, including one-time Agent-session-bootstrapped and explicitly managed Workspace projects shared by CLI cross-Scope operations and the App. |
| `internal/selfupdate/` | Signed CDN Manifest verification and installation-source-aware CLI update checks. |
| `internal/releasemanifest/` | Exact five-target CLI archive validation plus deterministic CDN Manifest and checksum assembly. |
| `internal/packagemutation/` | Ordered local Package mutation commits spanning prepared Scope Tree/Projection transactions, immutable cache writes, Workspace state publication, rollback, and cleanup. |
| `internal/infocache/` | User-level disposable exact immutable Package Info bytes used for checksum-verified offline restore across all scopes. |
| `internal/packageprovider/` | Unified read-through acquisition of exact locked Package metadata and Git content, including automatic cache reconstruction and lock-integrity checks. |
| `internal/hub/` | Client for add-time Package Version Queries followed by exact Package Version metadata and dumb-HTTP Git Artifact repositories, typed membership, local Pack caching, and Package h1 verification. |
| `internal/source/` | Package ID parsing, source reference normalization, and explicitly isolated third-party skills.sh identity validation. |
| `internal/packagestore/` | Complete Scope Package Tree extraction and deterministic platform-native member-link Projection transactions with Local Modification protection. |
| `internal/strictjson/` | Shared strict decoding for repeated machine-input JSON object lists at CLI Plan boundaries. |
| `internal/terminalui/` | Human terminal documents, automatic Interactive/Plain selection, responsive styling, and live operation progress. |
| `internal/trash/` | Cross-platform recoverable disposal of user-owned installation content through the desktop Trash or Recycle Bin. |
| `npm/` | Unscoped `skillsgo` npm launcher and release-only platform package assembler for `npx skillsgo`. |
| `homebrew/` | Homebrew distribution boundary and generated Formula publication contract. |

## Boundaries

- The CLI is the only product boundary that mutates local skill installations.
- Hub interaction must use the public SkillsGo protocol rather than server internals.
- The CLI exposes stable machine-readable output and availability exit codes through both one-shot commands and the App's bounded-read/exclusive-write CLI Server; human output and localized stderr are not integration contracts.
- Do not place Flutter UI state, layout, navigation, or visual policy in this workspace.
- Preserve artifact integrity and deterministic restoration without introducing a dependency lock graph.

## Documentation Routing

- Read `CONTEXT.md` for CLI vocabulary, contracts, and current risks.
- Record cross-workspace decisions under `/docs/adr/`; keep CLI-local implementation notes close to this workspace.

## GEB Maintenance

- Add an F3 Module Map when a stable CLI directory has a coherent API and multiple semantic members.
- Add or update the F4 header in semantic Go files and tests when those files are touched.
- `go.sum`, generated files, fixtures, binary assets, and vendored code are exempt from F4 headers.
- Apply migration on touch; do not perform a repository-wide header-only rewrite.

```text
// [INPUT]: External dependencies and assumptions consumed by this file.
// [OUTPUT]: Public behavior, symbols, or side effects provided by this file.
// [POS]: The file's architectural role inside its nearest F3 module.
// [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
