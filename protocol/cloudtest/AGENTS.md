# Hub Community Conformance Test Module

> F3 | Parent: `/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/protocol`

## Members

- `mock.go`: test-only in-memory Hub community HTTP implementation with observable/resettable install events and configurable rankings.
- `conformance.go`: reusable black-box verifier for the public Hub community HTTP contract.
- `cloudtest_test.go`: proves the mock itself satisfies the same conformance suite used by injected implementations.

## Architectural Boundary

This legacy-named package exists only for tests. Production packages must not import it. It may implement public HTTP behavior but must not reproduce consumer persistence, ranking algorithms, deployment logic, or secrets.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
