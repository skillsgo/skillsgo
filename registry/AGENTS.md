# SkillsGo Registry

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the public Registry service. Read it with the root constitution and `CONTEXT.md` before changing Registry code.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/registry`
- Entry point: `cmd/registry/main.go`
- Service assembly: `cmd/registry/actions/`
- Public seam: the Registry HTTP router and documented HTTP protocol
- Product responsibility: resolve public skill coordinates, validate manifests, produce immutable artifacts, serve search and rankings, and ingest anonymous usage events.

## Commands

Run from `registry/`:

```bash
go fmt ./...
go test ./...
go run ./cmd/registry -config_file=./config.dev.toml
```

Use a narrower `gofmt` target when unrelated working-tree changes are present.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `cmd/registry/` | Service entry point, configuration, dependency assembly, and HTTP wiring. |
| `internal/` | Registry-private integration helpers that are not public packages. |
| `pkg/` | Registry domain modules, source resolution, storage, search, protocol, and telemetry behavior. |
| `pkg/config/` and `config.dev.toml` | Configuration model, environment-variable binding, and local development defaults. |
| `e2etests/` and `test/` | End-to-end and cross-package behavior verification. |
| `scripts/` | Operational and CI utilities; nested manifests define independent F2 workspaces. |
| `docs/` | Registry protocol, operations, and inherited historical material. |
| `charts/` | Kubernetes packaging inherited from the Registry deployment surface. |

## Boundaries

- The Registry owns public skill identity, source resolution, metadata, immutable artifacts, search, rankings, and usage-event ingestion.
- The Registry does not install skills into local Agent directories and does not own App navigation or local library state.
- Public endpoints must use readable skill coordinates and stable response contracts.
- Preserve immutable version semantics, commit identity, tree identity, and deterministic archive output.
- Treat Athens-derived names and documents as legacy seams. When maintained code is touched, use SkillsGo terminology without erasing useful provenance.
- `docs/themes/`, vendored dependencies, generated files, fixtures, and imported upstream assets are not maintained semantic modules.

## Nested Workspace Routing

- Before changing `scripts/liveness_probe/**`, read `scripts/liveness_probe/AGENTS.md`.

## Documentation Routing

- Read `CONTEXT.md` for Registry vocabulary, contracts, and current risks.
- Treat HTTP Router behavior tests as the executable public contract until a dedicated Registry API reference is established.
- Record cross-workspace architectural decisions under `/docs/adr/`.

## GEB Maintenance

- Add an F3 Module Map when a stable Registry directory has a coherent API and multiple semantic members.
- Add or update the F4 header in semantic Go files, tests, and hand-maintained semantic configuration when those files are touched.
- `go.sum`, generated files, fixtures, vendored code, binary assets, and imported upstream documentation are exempt from F4 headers.
- Apply migration on touch; do not perform a repository-wide header-only rewrite.

```text
// [INPUT]: External dependencies and assumptions consumed by this file.
// [OUTPUT]: Public behavior, symbols, or side effects provided by this file.
// [POS]: The file's architectural role inside its nearest F3 module.
// [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
