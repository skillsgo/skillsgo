# SkillsGo Protocol

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the dependency-light Go protocol workspace shared by the CLI and Hub.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/protocol`
- Product responsibility: define executable, versioned contracts that must be interpreted identically by Hub producers and CLI consumers.
- Commands: run `go test ./...` and `gofmt` from `protocol/`; the root `make test-protocol` target enforces at least 95% statement coverage.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `artifact/` | Immutable artifact limits, safe paths, normalized Content Digests, and ZIP inspection. |
| `api/` | Public CLI-to-Hub JSON DTOs, schema constants, statuses, and risk levels. |
| `locale/` | Canonical presentation-locale normalization. |
| `skillid/` | Canonical public Hub Skill ID parsing and formatting. |
| `skillmanifest/` | Shared `SKILL.md` frontmatter parsing and validation. |
| `version/` | Canonical stable-first semantic-version selection. |

## Architectural Boundary

This workspace owns only public cross-process contracts and deterministic algorithms required to interpret them. It must not contain HTTP transport, Hub source resolution, CLI installation behavior, persistence, user-facing messages, or generic utilities.

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
