# Cross-Product End-to-End Tests
> F1 Domain Map | Parent: `/AGENTS.md`

This domain owns black-box release journeys across SkillsGo product boundaries.

## Workspaces

- `cli/`: Linux container journeys spanning the released CLI, Hub, public HTTP/JSON contracts, and isolated filesystem state.
- `app/`: macOS desktop journeys spanning the real Flutter App, released CLI process, disposable Hub, and isolated Agent/project state.

## Commands

Run from the repository root:

```bash
make test-e2e-cli
make test-e2e-app
make test-e2e
```

## Boundary

App journeys must drive the rendered desktop product and use real CLI and Hub boundaries. Widget tests with a fake `SkillsGateway` are App component tests and must not be presented as E2E coverage.

[PROTOCOL]: Update this map when E2E workspaces, commands, or cross-product boundaries change.
