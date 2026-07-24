# Contributing to SkillsGo

Thank you for helping improve SkillsGo. Contributions may affect the desktop App, CLI, Hub, shared Protocol, public Web surface, or cross-product journeys, so begin with the smallest product boundary that can demonstrate the desired behavior.

## Before You Start

- Search existing [issues](https://github.com/skillsgo/skillsgo/issues) and [discussions](https://github.com/skillsgo/skillsgo/discussions).
- Use an issue for a reproducible defect or a concrete product proposal. Use Discussions for questions and early ideas.
- Do not disclose vulnerabilities publicly. Follow [SECURITY.md](SECURITY.md).
- Comment before starting a substantial change. An issue labeled `ready-for-agent` or `ready-for-human` is specified and available for the corresponding kind of implementation unless someone is already assigned.
- Small documentation corrections and narrowly scoped fixes may be submitted directly.

Maintainers may ask for an issue or Architecture Decision Record before accepting changes that alter public protocols, persisted formats, identity, security boundaries, compatibility, or cross-context ownership.

## Repository Orientation

Read [AGENTS.md](AGENTS.md) and [CONTEXT-MAP.md](CONTEXT-MAP.md) before changing domain behavior. Then read the nearest `AGENTS.md` for every path you touch. These maps define workspace commands, architectural ownership, required File Contracts, and the documentation loop.

Repository documentation, issue content, and pull requests are written in English. User-facing App copy must use the App's localization system.

## Development

The supported root validation entry point is:

```bash
make test
```

During focused work, use the owning workspace's checks:

| Workspace | Validation |
| --- | --- |
| App | `cd app && flutter analyze && flutter test` |
| CLI | `cd cli && gofmt -w <changed-go-files> && go test ./...` |
| Hub | `cd hub && gofmt -w <changed-go-files> && go test ./...` |
| Protocol | `cd protocol && gofmt -w <changed-go-files> && go test ./...` |
| Web | `cd web && pnpm typecheck && pnpm build` |
| CLI + Hub E2E | `make test-e2e-cli` |
| Desktop E2E | `make test-e2e-app` |

Use `make dev` for the unified macOS development topology.

Tests should exercise the highest stable behavior seam: `SkillsGateway` for App journeys, the CLI root execution entry for CLI behavior, and the HTTP Router for Hub behavior. Add cross-product E2E coverage when a contract spans product boundaries.

## Pull Requests

Keep each pull request focused on one coherent outcome. Include:

- the user or operator problem;
- the chosen behavior and important tradeoffs;
- linked issues using `Fixes #123` when the PR should close them;
- validation commands and results;
- screenshots or recordings for visible UI changes;
- compatibility, migration, security, and documentation impact.

Update the File Contract of every touched semantic source file and review the applicable F3, F2, F1, and F0 maps. Update only documentation whose facts changed.

Draft pull requests are welcome for early technical feedback. A non-draft pull request should be reviewable, pass applicable checks, and contain no unrelated formatting or generated-file churn.

## Review and Conduct

Reviewers evaluate observable behavior, domain ownership, tests, security, compatibility, and maintainability. Feedback should be specific and respectful. Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
