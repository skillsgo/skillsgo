# SkillsGo App

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `pubspec.yaml`

This map governs the Flutter desktop application workspace. Read it with the root constitution and `CONTEXT.md` before changing application code.

## Workspace Identity

- Package: `skillsgo`
- Runtime: Flutter desktop; macOS is the currently maintained target.
- Entry points: `lib/main.dart` and `lib/app.dart`
- Integration seam: `SkillsGateway`
- Product responsibility: gate clean installs through Mandatory Onboarding, present discovery and Library workflows, collect installation, exact External removal, and export intent, delegate Hub and local operations to the bundled CLI, and compose Cloud ranking IDs with Hub-owned Skill cards.

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
| `lib/infrastructure/` | Bundled CLI adapter, structured process execution, platform integration, and preference persistence. |
| `lib/ui/` | Screens, navigation, components, design tokens, and interaction state. |
| `lib/l10n/` | Localization sources and generated localization interfaces. |
| `test/` | Unit, widget, and adapter contract tests. |
| `integration_test/` | Rendered macOS journeys orchestrated by `/e2e/app` against real CLI and disposable Hub boundaries. |
| `macos/` | macOS runner, desktop packaging integration, and the build-time bundled CLI bridge. |
| `docs/` | App-specific specifications, plans, and decisions. |
| `THIRD_PARTY_NOTICES.md` | Licenses and attribution for vendored App UI code. |

## Boundaries

- The App invokes the bundled SkillsGo CLI through typed adapters and must not call public Hub APIs directly. In Cloud mode it may call only the Cloud origin declared by `skillsgo hub info` for Cloud-owned reads.
- The CLI owns local installation, update, removal, target detection, `skillsgo.yaml`, `skillsgo.lock`, Scope Vendors, and Repository Projections.
- The Hub owns public Skill metadata, search, immutable artifacts, and deployment discovery. SkillsGo Cloud owns install events and rankings in an independent database.
- Do not parse human-oriented CLI output. Prefer stable machine-readable output and typed models.
- Hub availability failures must not replace valid local Library inventory or reset the selected Library route; local reads and safe local-only mutations remain independent.
- Do not construct shell command strings from user input; pass arguments as a structured list.
- Keep UI state and visual decisions out of CLI and Hub packages.

## UI Component Policy

- Use Flutter Material 3 primitives as the default foundation for controls, overlays, forms, feedback, semantics, and platform behavior.
- Use HugeIcons `strokeRounded` icons for every authored App icon. Do not introduce Flutter Material `Icons.*`, Cupertino icons, or another icon family in App UI; preserve Material components while supplying HugeIcons widgets through their icon slots. Prefer a semantic HugeIcons glyph over a merely similar shape, and keep neighboring icon size and stroke weight consistent.
- Build the application palette through the SkillsGo Design System: Primer-inspired semantic roles over Radix neutral scales, with Material 3 acting as the component adapter and the user seed controlling interaction accents.
- Keep recurring Material composition behind the reusable native component layer; build custom widgets only for product-specific interactions such as the stateful destination rail, folder shell, or anchored installation-location selector.
- Do not introduce a second component theme system. Product-specific colors may remain explicit only when they communicate stable status or brand meaning.

## Theme Policy

- Generate Light and Dark interaction accents from the same user-selected seed with `ColorScheme.fromSeed` and `DynamicSchemeVariant.fidelity`; keep the Folder hierarchy, neutral surfaces, readable foregrounds, and status colors stable through SkillsGo semantic tokens.
- Support `ThemeMode.system`, `ThemeMode.light`, and `ThemeMode.dark`; default to the system appearance. Persist the preference through `SkillsGateway`, never by reading or writing `SharedPreferences` from UI code.
- Use semantic `ColorScheme` roles for native Material components and `SkillsColorTokens` for product-specific Folder and spatial roles. A background role must use its matching foreground role.
- Use `surface` and the tone-based `surfaceContainer*` roles for page backgrounds, large regions, cards, rails, and the Folder shell. Use `primary`, `primaryContainer`, secondary, and tertiary roles only for appropriately emphasized actions, focus, compact selections, and accents.
- The active Folder body and tab are one foreground object and use `folderBody`; inactive Folder tabs use `folderTabInactive`.
- Do not hard-code `Colors.white`, `Colors.black`, or a fixed dark page background for ordinary interface content. Explicit colors are allowed only for stable semantic status, source brand identity, raw user color previews, or other meaning that must not change with the theme.
- Keep discovery cards neutral. Express themed hover state through borders, actions, focus, or restrained accent treatment instead of repainting a large card with an accent container.
- Theme controls must update immediately, preserve the selected seed, support localization and reduced motion, and remain usable with keyboard and assistive technology.
- Any new or materially changed UI component must be validated in Light and Dark modes with both low- and high-chroma seeds. Text and icon contrast must use the generated matching semantic roles rather than manual guesses.

## Asynchronous Interaction Policy

- User intent must receive visible feedback in the next rendered frame. Do not wait for Hub, CLI, filesystem, preference, or package operations before opening the requested destination, overlay, or operation surface.
- Keep the App shell, navigation, dismissal, cancellation, and unrelated actions interactive while work is pending. Disable only controls that would duplicate or invalidate the in-flight operation.
- Every remote, process, or filesystem-backed surface must implement five explicit states: `initialLoading`, `content`, `refreshing`, `empty`, and `error`. Do not encode loading as `null` when `null` can also mean empty or unavailable.
- Use geometry-preserving skeletons only for cold loads with no usable content. When usable content already exists, retain it during refresh and expose restrained refresh progress instead of replacing it with a skeleton.
- Independent data dependencies must render and fail independently. A slow optional dependency must not delay primary content or an interactive surface.
- Preserve the last valid local Library inventory during Hub failures and the last valid discovery or detail content during refresh failures when its identity remains valid.
- Long-running mutations may lock their own submit control, but must publish progress and keep safe navigation or cancellation paths available.
- New journeys that depend on asynchronous data require widget tests proving next-frame feedback, stable content during refresh, explicit empty/error recovery, and reduced-motion plus accessibility semantics.

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
