# SkillsGo Protocol

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `go.mod`

This map governs the dependency-light Go protocol workspace shared by SkillsGo producers, consumers, and public conformance tests.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/protocol`
- Product responsibility: define executable, versioned contracts that must be interpreted identically by Hub producers and CLI consumers.
- Commands: run `go test ./...` and `gofmt` from `protocol/`; the root `make test-protocol` target enforces at least 95% statement coverage.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `artifact/` | Package Artifact entry validation, immutable limits, safe paths and internal symlinks, legacy normalized ZIP traversal, and coordinate-bound Sums shared by producers and consumers. |
| `api/` | Public CLI-to-Hub JSON DTOs, including canonical zero-based pagination, Package Version collections, single/batch Find documents, current Package Publications, Package-level Sum and Artifact Repository identity, canonical Package-member coordinates, Skill path metadata, schema constants, and statuses. |
| `cloud/` | Legacy package path for public Hub community JSON DTOs, endpoint paths, Hub-card-plus-metric ranking vocabulary, and install-event semantics. The path name is not an architecture or deployment boundary. |
| `cloudtest/` | Test-only Hub community HTTP mock and executable conformance verifier; never imported by production packages. |
| `locale/` | Canonical presentation-language normalization and the supported content-language registry. |
| `packageidentity/` | Canonical public Package identity primitives, including Path parsing, formatting, and initial Source Repository URL derivation. |
| `skillname/` | Dependency-light canonical public Skill Name grammar shared by manifests and community ranking coordinates. |
| `skillmanifest/` | Shared `SKILL.md` frontmatter parsing and validation. |
| `version/` | Canonical immutable versions, stable/prerelease/pseudo current-version priority and ordered lists, stable-first release selection, and the closed typed add-time Package Version Query grammar. |

## Architectural Boundary

This workspace owns only public cross-process contracts and deterministic algorithms required to interpret them. Production packages must not contain HTTP transport, Hub source resolution, CLI installation behavior, persistence, user-facing messages, or generic utilities. HTTP helpers are permitted only in explicitly test-only conformance packages such as `cloudtest/`.

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
