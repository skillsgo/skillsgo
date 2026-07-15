# SkillsGo

SkillsGo is an open ecosystem for discovering and managing Agent Skills. The monorepo contains a Flutter desktop App, a Go CLI, and a Go Registry.

## Repository Layout

```text
skillsgo/
├── app/       Flutter desktop client
├── cli/       SkillsGo command-line client and local execution engine
└── registry/  Public Skill Registry service
```

## Local Development

Run Registry tests:

```bash
make test-registry
```

Run App tests:

```bash
make test-app
```

Run all configured checks:

```bash
make test
```

The three contexts use independent toolchains while evolving in one Git repository. Read [`CONTEXT-MAP.md`](CONTEXT-MAP.md) before changing domain behavior.
