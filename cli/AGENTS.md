# SkillsGo CLI

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the Go command-line workspace. Read it with the root constitution and `CONTEXT.md` before changing CLI code.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/cli`
- Entry point: `cmd/skillsgo/main.go`
- Command seam: `command.Execute`
- Product responsibility: own local skill mutations, installation targets, project declarations, lock state, and shared artifact-store state.

## Commands

Run from `cli/`:

```bash
go fmt ./...
go test ./...
go build ./cmd/skillsgo
```

Use a narrower `gofmt` target when unrelated working-tree changes are present.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `cmd/skillsgo/` | Process entry point and executable wiring. |
| `internal/agent/` | Supported Agent definitions, detection, and installation locations. |
| `internal/command/` | CLI command graph, argument handling, and orchestration. |
| `internal/i18n/` | Locale detection and user-facing CLI messages. |
| `internal/install/` | Add, update, remove, collision, and materialization behavior. |
| `internal/inventory/` | Read-only managed and External Library reconciliation across receipts, explicit projects, Workspace declarations, and known Agent paths. |
| `internal/project/` | `skillsgo.yaml` and `skillsgo-lock.yaml` project state. |
| `internal/registry/` | Client for the public SkillsGo Registry protocol. |
| `internal/source/` | Skill-coordinate parsing and source identity. |
| `internal/store/` | User-level shared artifact cache and installation state. |

## Boundaries

- The CLI is the only product boundary that mutates local skill installations.
- Registry interaction must use the public SkillsGo protocol rather than server internals.
- The CLI may expose stable machine-readable output for the App; human output is not an integration contract.
- Do not place Flutter UI state, layout, navigation, or visual policy in this workspace.
- Preserve artifact integrity and deterministic lock behavior when changing installation flows.

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
