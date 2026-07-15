# SkillsPlay App

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `pubspec.yaml`

This map governs the Flutter desktop application workspace. Read it with the root constitution and `CONTEXT.md` before changing application code.

## Workspace Identity

- Package: `skillsplay`
- Runtime: Flutter desktop; macOS is the currently maintained target.
- Entry points: `lib/main.dart` and `lib/app.dart`
- Integration seam: `SkillsGateway`
- Product responsibility: present discovery and library workflows, collect user intent, and delegate registry reads or local mutations to the correct boundary.

## Commands

Run from `app/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
flutter build macos --release
```

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `lib/domain/` | Product concepts and application-facing models. |
| `lib/infrastructure/` | Registry and CLI adapters, process execution, and persistence integration. |
| `lib/ui/` | Screens, navigation, components, design tokens, and interaction state. |
| `lib/l10n/` | Localization sources and generated localization interfaces. |
| `test/` | Unit, widget, and adapter contract tests. |
| `macos/` | macOS runner, desktop packaging integration, and the build-time bundled CLI bridge. |
| `docs/` | App-specific specifications, plans, and decisions. |

## Boundaries

- The App may read public Registry APIs and invoke the SkillsGo CLI through typed adapters.
- The CLI owns local installation, update, removal, target detection, manifests, locks, and the shared store.
- The Registry owns public skill metadata, search, rankings, immutable artifacts, and event ingestion.
- Do not parse human-oriented CLI output. Prefer stable machine-readable output and typed models.
- Do not construct shell command strings from user input; pass arguments as a structured list.
- Keep UI state and visual decisions out of CLI and Registry packages.

## UI Component Policy

- Prefer `shadcn_ui` primitives for common controls, overlays, forms, feedback, and accessibility behavior.
- Apply the Burrow-inspired visual language through SkillsPlay Design Tokens and thin brand components that compose or theme those primitives.
- Build custom widgets only for product-specific interactions, such as the stateful destination rail or installation matrix, or when `shadcn_ui` has no suitable primitive.
- Use raw Material controls as low-level Flutter infrastructure only when a `shadcn_ui` equivalent would reduce capability, platform behavior, or accessibility; keep that exception behind a reusable brand component when it recurs.

## Documentation Routing

- Read `CONTEXT.md` for App vocabulary, boundaries, public contracts, and current risks.
- Read `docs/adr/AGENTS.md` before changing an App decision record.
- Read the relevant specification or plan under `docs/` before implementing an approved product flow.

## GEB Maintenance

- Add an F3 Module Map when a stable App directory becomes a meaningful subsystem with multiple semantic members.
- Add or update the F4 header in semantic Dart files, tests, and hand-maintained semantic configuration when those files are touched.
- Generated localization files, ARB localization catalogs, generated plugin registrants, lockfiles, fixtures, binary assets, and platform-generated build files are exempt from F4 headers. ARB changes must still regenerate and validate the typed localization interface.
- Apply migration on touch; do not mechanically rewrite untouched source files only to add headers.

```text
[INPUT]: External dependencies and assumptions consumed by this file.
[OUTPUT]: Public behavior, symbols, or side effects provided by this file.
[POS]: The file's architectural role inside its nearest F3 module.
[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
