# SkillsGo Hub

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the public Hub service. Read it with the root constitution and `CONTEXT.md` before changing Hub code.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/hub`
- Shared dependency: `github.com/skillsgo/skillsgo/protocol` through the repository `go.work` during development.
- Entry point: `cmd/skillsgo-hub/main.go`
- Service assembly: `cmd/skillsgo-hub/actions/`
- Public seam: the Fiber HTTP router and documented HTTP protocol
- Product responsibility: resolve public Skill IDs, validate manifests, produce immutable artifacts, serve search and rankings, and ingest anonymous usage events.

## Commands

Run from `hub/`:

```bash
go fmt ./...
go test ./...
make build
go run ./cmd/skillsgo-hub -config_file=./config.dev.toml
```

The repository-level `make dev` runs this workspace through Air. Air owns Hub rebuild and restart while Process Compose owns cross-workspace ordering and lifecycle.

Use a narrower `gofmt` target when unrelated working-tree changes are present.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `cmd/skillsgo-hub/` | Service entry point, configuration, dependency assembly, and HTTP wiring. |
| `bin/skillsgo-hub` | Ignored local development binary produced by `make build`; release artifacts remain under `dist/`. |
| `internal/` | Hub-private integration helpers that are not public packages. |
| `pkg/` | Hub domain modules, source resolution, storage, search, protocol, and telemetry behavior. |
| `pkg/translation/` | Optional OpenAI-compatible presentation-description translation worker. |
| `pkg/config/`, `config.dev.toml`, and `.air.toml` | Configuration model, environment-variable binding, local development defaults, and Hub hot reload. |
| `e2etests/` and `test/` | End-to-end and cross-package behavior verification. |
| `scripts/` | Operational and CI utilities; nested manifests define independent F2 workspaces. |
| `charts/` | Kubernetes packaging inherited from the Hub deployment surface. |

## Boundaries

- The Hub owns public Skill IDs, source resolution, metadata, immutable artifacts, search, rankings, and usage-event ingestion.
- The Hub does not install skills into local Agent directories and does not own App navigation or local library state.
- Public endpoints must use readable Skill IDs and stable response contracts.
- Preserve immutable version semantics, commit identity, tree identity, and deterministic archive output.
- Treat Athens-derived names and documents as legacy seams. When maintained code is touched, use SkillsGo terminology without erasing useful provenance.
- Vendored dependencies, generated files, fixtures, and imported upstream assets are not maintained semantic modules.

## Nested Workspace Routing

- Before changing `scripts/liveness_probe/**`, read `scripts/liveness_probe/AGENTS.md`.

## Documentation Routing

- Read `CONTEXT.md` for Hub vocabulary, contracts, and current risks.
- Treat HTTP Router behavior tests as the executable public contract until a dedicated Hub API reference is established.
- Record cross-workspace architectural decisions under `/docs/adr/`.

## GEB Maintenance

- Add an F3 Module Map when a stable Hub directory has a coherent API and multiple semantic members.
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
