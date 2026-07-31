<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="SkillsGo — discover, verify, and manage Agent Skills">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>English</strong> · Languages</summary>
  <br>
  <p>
    <strong>English</strong> ·
    <a href="./docs/readme/README.zh-CN.md">简体中文</a> ·
    <a href="./docs/readme/README.zh-TW.md">繁體中文（台灣）</a> ·
    <a href="./docs/readme/README.zh-HK.md">繁體中文（香港）</a> ·
    <a href="./docs/readme/README.ja.md">日本語</a> ·
    <a href="./docs/readme/README.ko.md">한국어</a> ·
    <a href="./docs/readme/README.fr.md">Français</a> ·
    <a href="./docs/readme/README.de.md">Deutsch</a> ·
    <a href="./docs/readme/README.it.md">Italiano</a> ·
    <a href="./docs/readme/README.es.md">Español</a> ·
    <a href="./docs/readme/README.pt-BR.md">Português (Brasil)</a> ·
    <a href="./docs/readme/README.ru.md">Русский</a> ·
    <a href="./docs/readme/README.ar.md">العربية</a> ·
    <a href="./docs/readme/README.hi.md">हिन्दी</a> ·
    <a href="./docs/readme/README.id.md">Bahasa Indonesia</a> ·
    <a href="./docs/readme/README.tr.md">Türkçe</a> ·
    <a href="./docs/readme/README.nl.md">Nederlands</a> ·
    <a href="./docs/readme/README.pl.md">Polski</a> ·
    <a href="./docs/readme/README.th.md">ไทย</a> ·
    <a href="./docs/readme/README.vi.md">Tiếng Việt</a> ·
    <a href="./docs/readme/README.ms.md">Bahasa Melayu</a> ·
    <a href="./docs/readme/README.sv.md">Svenska</a> ·
    <a href="./docs/readme/README.uk.md">Українська</a>
  </p>
</details>

<!-- README-I18N:END -->

SkillsGo is an open ecosystem for discovering and managing Agent Skills. The desktop App gives people a visual way to discover and manage Skills, while the CLI brings the same Hub catalog into CI/CD and repeatable environment workflows.

> [!IMPORTANT]
> SkillsGo is under active pre-release development. Public protocols, persisted formats, and installation behavior may change before the first stable release.

## See SkillsGo in action

<p align="center">
  <img src="./assets/readme/discover-ranking.png" width="100%" alt="SkillsGo desktop App showing Agent Skills from the live public Hub ranking">
</p>

The desktop App connects discovery, source evidence, installation targets, and local inventory in one human-friendly journey. Personal use requires no account.

### Discover from the Hub

Search by Skill or source repository, explore the live ranking, and install one Skill or an entire collection.

<p align="center">
  <img src="./assets/readme/discover-find.png" width="100%" alt="SkillsGo Discover search showing a source repository and its available Agent Skills">
</p>

### Inspect before you install

Review the source repository, immutable release, supported Agents, translated summary, and rendered `SKILL.md` before making a local change.

<p align="center">
  <img src="./assets/readme/discover-skill-detail.png" width="100%" alt="SkillsGo Skill detail showing source evidence, version, supported Agents, and rendered instructions">
</p>

### Choose exactly where Skills go

Install globally or into selected projects, then choose the Agent targets that should receive the same Skill release.

<p align="center">
  <img src="./assets/readme/discover-install-skill.png" width="100%" alt="SkillsGo installation target picker with selected projects and multiple Agent targets">
</p>

### Manage one local library

Browse installed Skills by Global or project scope, search the inventory, and filter by Agent.

<p align="center">
  <img src="./assets/readme/library-global-skills.png" width="100%" alt="SkillsGo Library showing globally installed Skills and their Agent targets">
</p>

### Update with the consequences visible

See the version transition and any Skills that will be removed before applying a repository update.

<p align="center">
  <img src="./assets/readme/library-update-skills.png" width="100%" alt="SkillsGo Library update preview showing a version transition and Skills that will be removed">
</p>

<details>
  <summary><strong>See a project-scoped Library</strong></summary>
  <br>
  <p align="center">
    <img src="./assets/readme/library-project.png" width="100%" alt="SkillsGo Library showing Skills installed for a selected project">
  </p>
</details>

## Why SkillsGo

- **Real source evidence** — inspect repository identity, version, `SKILL.md`, files, and risk before installation.
- **Explicit Agent targets** — install to selected Agents at Global or project scope instead of copying files by hand.
- **Verifiable distribution** — treat a source Repository release as an immutable distribution unit.
- **Local-first management** — inspect and safely manage local inventory even when the Hub is unavailable.
- **Two purpose-built interfaces** — use the App for interactive personal workflows and the CLI for CI/CD, automation, and consistent Skill environments.

## How it works

<p align="center">
  <img src="./assets/readme/workflow.svg" width="100%" alt="SkillsGo workflow: discover, inspect, choose targets, install, and manage">
</p>

The public Hub is the shared source for Skill identity, immutable releases, metadata, search, and discovery. The App connects people to the Hub through a visual workflow; the CLI connects automation and CI/CD to the same Hub so Skill selections can remain consistent across environments.

## Explore the monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Read [`CONTEXT-MAP.md`](CONTEXT-MAP.md) for product boundaries and domain language.

## Run it locally

The unified development topology currently targets macOS and requires Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose), and [Air](https://github.com/air-verse/air).

```bash
make dev
```

This starts PostgreSQL, the local Hub, a freshly built CLI, and the Flutter desktop App under one supervised session. To validate all configured workspaces:

```bash
make test
```

Focused entry points are available for each workspace:

| Workspace | Development or validation |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

See [CONTRIBUTING.md](CONTRIBUTING.md) before changing product behavior.

## Project status

SkillsGo is preparing its first releases. The Hub release pipeline is defined first; signed and notarized App releases and standalone CLI distribution follow their own readiness gates. See the [release design](docs/release-design.md) for supported release units, artifact integrity, and supply-chain requirements.

## Community

- Use [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) for questions, troubleshooting, and early ideas.
- Use the focused [issue forms](https://github.com/skillsgo/skillsgo/issues/new/choose) for reproducible bugs, concrete feature requests, and documentation problems.
- Follow [SECURITY.md](SECURITY.md) to report vulnerabilities privately.
- Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md) and the [governance model](GOVERNANCE.md).

## License

SkillsGo is licensed under the [Apache License 2.0](LICENSE).

The Hub contains code derived from [Athens](https://github.com/gomods/athens), which remains subject to the Athens MIT License and attribution notices. See [`NOTICE`](NOTICE) and [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](THIRD_PARTY_LICENSES/ATHENS-LICENSE).
