# Repository Scripts

> F3 | Parent: `AGENTS.md`

## Members

- `dev.sh`: starts the repository-owned PostgreSQL, Hub, and CLI development topology.
- `cleanup-dev.sh`: safely stops stale development processes owned by this checkout.
- `build-cli-release.sh`: builds standalone CLI release artifacts for supported targets.
- `test-build-cli-release.sh`: validates the standalone CLI release contract.
- `generate-homebrew-formula.mjs`: renders the Homebrew formula from released CLI metadata.

## Boundary

Scripts orchestrate public repository workspaces and release artifacts. Product behavior belongs in the owning workspace rather than shell orchestration.

[PROTOCOL]: Update this map when a maintained script is added, removed, or changes responsibility, then review AGENTS.md
