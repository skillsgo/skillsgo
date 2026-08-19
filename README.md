# SkillsGo

SkillsGo is the open distribution layer for Agent Skills. It provides a local CLI, a self-hostable Hub, shared protocol contracts, and a public Web surface for discovering, verifying, installing, and managing Skills.

The official desktop application is distributed separately and consumes the same public CLI and Hub contracts. Its implementation is not part of this repository.

## Workspaces

| Path | Responsibility |
| --- | --- |
| `protocol/` | Dependency-light executable contracts shared by CLI and Hub |
| `cli/` | Local Skill discovery, verification, installation, Agent adapters, and machine-readable APIs |
| `hub/` | Self-hostable Skill registry, immutable artifacts, metadata, search, and ranking seams |
| `web/` | Product site, Hub browsing surface, and documentation |
| `e2e/cli/` | Black-box CLI and Hub journeys |

## CLI

Build and inspect the command surface:

```bash
make build-cli
./cli/bin/skillsgo --help
```

The CLI supports human-readable commands and stable JSON/NDJSON contracts for embedding applications. See [`cli/README.md`](cli/README.md) for installation and usage.

## Self-host the Hub

The Hub exposes the public HTTP behavior and reusable Runtime seam needed by a self-hosted or embedding application:

```bash
make dev-hub
```

See [`hub/README.md`](hub/README.md) for configuration and public APIs.

## Development

The supported local toolchain is Go, Node.js 22+, pnpm, Docker, Process Compose, and Air.

```bash
make dev       # PostgreSQL, Hub, and CLI
make test      # Protocol, Hub, CLI, and Web validation
make test-e2e  # Black-box CLI and Hub journeys
```

Repository architecture and contribution rules are documented in [`AGENTS.md`](AGENTS.md), [`CONTEXT-MAP.md`](CONTEXT-MAP.md), and [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

Licensed under the terms in [`LICENSE`](LICENSE).
