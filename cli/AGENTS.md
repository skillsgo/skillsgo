# SkillsGo CLI

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the Go command-line workspace. Read it with the root constitution and `CONTEXT.md` before changing CLI code.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/cli`
- Shared dependency: `github.com/skillsgo/skillsgo/protocol` through the repository `go.work` during development.
- Entry point: `cmd/skillsgo/main.go`
- Command seam: `command.Execute`
- Product responsibility: own local Repository Vendor and Agent Projection mutations, canonical Workspace declarations and locks, immutable Info cache, and installation-state inspection.

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
| `cmd/skillsgo/` | Process entry point and executable wiring. |
| `bin/skillsgo` | Ignored local development binary produced by `make build`. |
| `internal/agent/` | Supported Agent definitions, detection, and installation locations. |
| `internal/command/` | CLI command graph, argument handling, and orchestration. |
| `internal/i18n/` | Locale detection and user-facing CLI messages. |
| `internal/install/` | Add, update, remove, copy-digest, explicit replacement, and materialization behavior. |
| `internal/inventory/` | Read-only Repository-managed and External Library reconciliation across YAML/Lock state, Scope Vendors, Repository Projections, known Agent Discovery Roots, Local Modifications, and derived Agent visibility. |
| `internal/managementplan/` | Exact-target managed Remove/Repair and External Remove preflight, reviewed-state binding, and target-specific execution. |
| `internal/project/` | Strict Repository dependencies in `skillsgo.yaml`, integrity-only `skillsgo.lock`, their paired transaction, and migration-era local receipt readers. |
| `internal/infocache/` | Exact immutable Repository and Skill Info bytes used for checksum-verified offline restore. |
| `internal/hub/` | Client for add-time product-API Repository resolution followed by exact root Proxy Info/ZIP, typed membership, bounded download, and Repository h1 verification. |
| `internal/source/` | Skill ID parsing and source reference normalization. |
| `internal/scopevendor/` | Complete ordinary-file Repository Vendor extraction and deterministic per-Agent Repository Projection transactions. |
| `internal/store/` | User-level shared Hub/Local/captured immutable artifact cache, private Local import/export, and verified takeover baselines. |
| `internal/strictjson/` | Shared strict decoding for repeated machine-input JSON object lists at CLI Plan boundaries. |
| `internal/terminalui/` | Human terminal documents, automatic Interactive/Plain selection, responsive styling, and live operation progress. |
| `internal/trash/` | Cross-platform recoverable disposal of user-owned installation content through the desktop Trash or Recycle Bin. |

## Boundaries

- The CLI is the only product boundary that mutates local skill installations.
- Hub interaction must use the public SkillsGo protocol rather than server internals.
- The CLI may expose stable machine-readable output and availability exit codes for the App; human output and localized stderr are not integration contracts.
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
