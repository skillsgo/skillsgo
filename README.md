# SkillsGo

SkillsGo is an open ecosystem for discovering and managing Agent Skills. The monorepo contains a Flutter desktop App, a Go CLI, a Go Hub, and a public Web surface.

> [!IMPORTANT]
> SkillsGo is under active pre-release development. Public protocols, persisted formats, and installation behavior may change before the first stable release.

## Why SkillsGo

SkillsGo treats a source Repository release as an immutable, verifiable distribution unit while allowing users to select individual Skills for specific Agents. The App delegates local and Hub operations to the bundled CLI; the CLI owns dependency intent, verified local Vendor content, and conflict-safe Agent Projections; the Hub owns public identity, immutable artifacts, and discovery.

## Repository Layout

```text
skillsgo/
├── app/       Flutter desktop client
├── cli/       SkillsGo command-line client and local execution engine
├── hub/       Public Skill Hub service
├── protocol/  Shared executable contracts used by CLI and Hub
├── e2e/       Cross-product CLI/Hub and desktop journeys
└── web/       Public product, Hub, and documentation Web surface
```

## Project Status

The project is preparing its first releases. The Hub release pipeline is defined first; signed and notarized App releases and standalone CLI distribution follow their own readiness gates. See [the release design](docs/release-design.md) for supported release units, artifact integrity, and supply-chain requirements.

## Local Development

Run Hub tests:

```bash
make test-hub
```

Run App tests:

```bash
make test-app
```

Run all configured checks:

```bash
make test
```

Run the public Web surface locally:

```bash
cd web
pnpm install
pnpm dev
```

The product contexts and public Web surface use independent toolchains while evolving in one Git repository. Read [`CONTEXT-MAP.md`](CONTEXT-MAP.md) before changing domain behavior.

## Community

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing or implementing a change.
- Use [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) for questions, troubleshooting, and early ideas.
- Use the focused [issue forms](https://github.com/skillsgo/skillsgo/issues/new/choose) for reproducible bugs, concrete feature requests, and documentation problems.
- Follow [SECURITY.md](SECURITY.md) to report vulnerabilities privately.
- All participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md) and the project's [governance model](GOVERNANCE.md).

## License

SkillsGo is licensed under the [Apache License 2.0](LICENSE).

The Hub contains code derived from [Athens](https://github.com/gomods/athens),
which remains subject to the Athens MIT License and attribution notices. See
[`NOTICE`](NOTICE) and
[`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](THIRD_PARTY_LICENSES/ATHENS-LICENSE).
