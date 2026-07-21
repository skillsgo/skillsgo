# SkillsGo

SkillsGo is an open ecosystem for discovering and managing Agent Skills. The monorepo contains a Flutter desktop App, a Go CLI, a Go Hub, and a public Web surface.

## Repository Layout

```text
skillsgo/
├── app/       Flutter desktop client
├── cli/       SkillsGo command-line client and local execution engine
├── hub/       Public Skill Hub service
└── web/       Public product, Hub, and documentation Web surface
```

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

## License

SkillsGo is licensed under the [Apache License 2.0](LICENSE).

The Hub contains code derived from [Athens](https://github.com/gomods/athens),
which remains subject to the Athens MIT License and attribution notices. See
[`NOTICE`](NOTICE) and
[`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](THIRD_PARTY_LICENSES/ATHENS-LICENSE).
