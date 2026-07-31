# Hub Community Protocol Module

> F3 | Parent: `/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/protocol`

## Members

- `cloud.go`: public endpoint paths and query names, batch Package install-event DTOs, ranking DTOs, enums, and deterministic wire-level validation.
- `cloud_test.go`: specifies JSON field names, enum vocabulary, validation boundaries, and metadata-free ranking responses.
- `testdata/`: stable valid JSON examples consumed by producers, clients, documentation, and compatibility tests.

## Architectural Boundary

This legacy-named module owns the public Hub community wire contract. Its filesystem and Go package name are compatibility identifiers, not disclosure of a consumer or deployment architecture. It must not contain HTTP clients or servers, persistence schemas, ranking algorithms, deployment details, authentication secrets, or private business rules.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
