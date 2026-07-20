# SkillsGo

SkillsGo is an open ecosystem for discovering and managing Agent Skills. The monorepo contains a Flutter desktop App, a Go CLI, a Go Hub, and a public documentation site.

## Repository Layout

```text
skillsgo/
├── app/       Flutter desktop client
├── cli/       SkillsGo command-line client and local execution engine
├── hub/       Public Skill Hub service
└── docs-site/ Fumadocs public documentation site
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

Run the documentation site locally:

```bash
cd docs-site
pnpm install
pnpm dev
```

The product contexts and documentation surface use independent toolchains while evolving in one Git repository. Read [`CONTEXT-MAP.md`](CONTEXT-MAP.md) before changing domain behavior.
