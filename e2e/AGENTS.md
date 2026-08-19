# End-to-End Tests

> F1 | Parent: `AGENTS.md`

## Members

- `cli/`: black-box journeys spanning the released CLI contract, disposable Hub, isolated Agent/project state, and real persistence boundaries.

## Validation

Run `make test-e2e` from the repository root. Tests must exercise public process or HTTP boundaries and must not replace those boundaries with in-process fakes.

[PROTOCOL]: Update this map when the workspace structure or validation boundary changes, then review AGENTS.md
