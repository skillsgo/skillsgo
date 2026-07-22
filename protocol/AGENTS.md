# SkillsGo Protocol

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the dependency-light Go protocol workspace shared by SkillsGo producers, consumers, and Cloud conformance tests.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/protocol`
- Product responsibility: define executable, versioned contracts that must be interpreted identically by Hub producers and CLI consumers.
- Commands: run `go test ./...` and `gofmt` from `protocol/`; the root `make test-protocol` target enforces at least 95% statement coverage.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `artifact/` | Repository Artifact construction, immutable limits, safe paths, one-pass normalized ZIP traversal, and Go-compatible Sums shared by producers and consumers. |
| `api/` | Public CLI-to-Hub JSON DTOs, including Repository-level Sum/archive identity and Skill member path metadata, schema constants, statuses, and risk levels. |
| `cloud/` | Public Cloud JSON DTOs, endpoint paths, ranking vocabulary, and install-event semantics. |
| `cloudtest/` | Test-only Cloud HTTP mock and executable conformance verifier; never imported by production packages. |
| `locale/` | Canonical presentation-locale normalization. |
| `skillid/` | Canonical public Hub Skill ID parsing and formatting. |
| `skillmanifest/` | Shared `SKILL.md` frontmatter parsing and validation. |
| `version/` | Canonical stable-first semantic-version selection. |

## Architectural Boundary

This workspace owns only public cross-process contracts and deterministic algorithms required to interpret them. Production packages must not contain HTTP transport, Hub source resolution, CLI installation behavior, persistence, user-facing messages, or generic utilities. HTTP helpers are permitted only in explicitly test-only conformance packages such as `cloudtest/`.

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
