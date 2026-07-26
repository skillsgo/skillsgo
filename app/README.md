# SkillsGo

SkillsGo is a desktop manager for Agent Skills. It discovers public Skills through a SkillsGo Hub and uses the bundled SkillsGo CLI to manage user-level and project-level installations.

## Personal MVP

- Search, all-time ranking, 24-hour trending, and Hot discovery views
- Skill version, source, `SKILL.md`, file, and risk inspection
- A multi-location, multi-Agent installation matrix
- Aggregated management of user-level, project-level, managed, and external installations
- Repository-level update checks plus exact External Installation removal
- Read-only discovery and exact-path removal for external installations
- Official or self-hosted Hub configuration

The Personal MVP requires no account and excludes teams, billing, approval, and cloud synchronization.

## Local Development

The current macOS development target requires Flutter 3.44 or newer. Development builds may use an explicitly configured `skillsgo` executable; macOS builds compile and bundle a matching Universal CLI from the same source tree.

```sh
flutter pub get
flutter test
flutter analyze
flutter run -d macos
```

Build a local release application:

```sh
flutter build macos --release
open build/macos/Build/Products/Release/SkillsGo.app
```

Debug builds expose Marionette integration for Codex-driven desktop UI verification. SkillsGo needs access to projects explicitly selected by the user and to local Agent directories, so desktop permissions and signing must cover those paths.

## Product Documentation

- [User Journeys and Information Architecture](docs/user-routes.md)
- [Personal MVP](docs/mvp.md)
- [Domain Language](CONTEXT.md)
- [ADR: Bundle the SkillsGo CLI in the App](../docs/adr/0001-bundle-skillsgo-cli.md)

SkillsGo is not affiliated with OpenAI, Codex, Vercel Labs, or `skills.sh`.
