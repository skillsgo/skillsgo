# SkillsGo App

> F1 Domain Map + F2 Workspace Map | Parent: `/AGENTS.md` | Manifest: `pubspec.yaml`

This map governs the Flutter desktop application workspace. Read it with the root constitution and `CONTEXT.md` before changing application code.

## Workspace Identity

- Package: `skillsgo`
- Runtime: Flutter desktop; CI maintains macOS arm64, macOS x64, Windows x64, and Linux x64 build/startup coverage, while the complete product Journey suite runs independently on macOS, Windows, and Linux.
- Entry points: `lib/main.dart` and `lib/app.dart`
- Integration seam: `SkillsGateway`
- Product responsibility: gate clean installs through Mandatory Onboarding, present discovery and Library workflows, collect Package installation/update/removal and exact External removal intent, and delegate every Hub and local operation to the bundled CLI.
- Version boundary: the bundled CLI reports the App product version (for example `0.0.1`); Flutter's `+build` suffix remains platform packaging metadata and must not enter the CLI version contract.
- Installer lifecycle: `lib/main.dart` must handle Velopack's four official fast-exit arguments before logging, Flutter binding, or UI initialization; normal first-run/restart environment launches continue through the standard App path.
- Update runtime: `velopack_flutter` is the App's thin Flutter-to-Velopack 1.2.0 bridge. Ordinary starts initialize `VelopackApp` before Flutter UI; the CI-only update source accepts loopback HTTP only and must never become a production endpoint override.
- Production update source: release CI embeds one stable public HTTPS channel directory through `SKILLSGO_APP_UPDATE_URL`; versioned packages are immutable while the channel manifest is published last and remains mutable. Builds without that value keep App-update controls disabled and never guess a release host.

## Commands

Run from `app/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
flutter build macos --release
./macos/scripts/build_arch.sh arm64
./macos/scripts/build_arch.sh x86_64
flutter build windows --release
flutter build linux --release
```

Canonical release builds run from the repository root:

```bash
make build-app-macos-arm64
make build-app-macos-x86_64
make build-app-macos
./scripts/package-app-candidate.sh macos arm64
./scripts/package-app-candidate.sh macos x86_64
./scripts/package-app-candidate.sh windows x64
./scripts/package-app-candidate.sh linux x64
dart scripts/sync-velopack-feed.dart https://releases.example.com/app/osx-arm64/ osx-arm64 app/build/velopack/osx-arm64
```

- `build-app-macos-arm64` produces an arm64-only App under `app/build/macos-arm64/Build/Products/Release/SkillsGo.app`.
- `build-app-macos-x86_64` produces an x86_64-only App under `app/build/macos-x86_64/Build/Products/Release/SkillsGo.app`.
- `build-app-macos` builds both independent architecture artifacts; macOS release packaging must not merge them into a Universal binary.
- `package-app-candidate.sh` requires the corresponding native Release build and pinned Velopack CLI, then emits one unsigned architecture-specific channel under `app/build/velopack/`.
- `prepare-app-update-rehearsal.sh` and `smoke-app-update-rehearsal.sh` append an ephemeral `0.0.2` package to a `0.0.1` feed and prove check, download, apply, replacement, and restart without publishing or signing.
- An `app/vX.Y.Z` tag drives `.github/workflows/app-release.yml`; it requires the protected `app-release` environment and publishes immutable channel assets to R2 before each mutable Velopack manifest.

## Workspace Map

| Path | Responsibility |
| --- | --- |
| `lib/domain/` | Product concepts and application-facing models. |
| `lib/infrastructure/` | Bundled CLI adapter, structured process execution, platform integration, and preference persistence. |
| `lib/ui/` | Screens, navigation, components, design tokens, and interaction state. |
| `lib/l10n/` | Localization sources and generated localization interfaces. |
| `test/` | Unit, widget, and adapter contract tests. |
| `integration_test/` | Cross-platform bundled-CLI startup smoke coverage plus rendered macOS, Windows, and Linux Journeys registered into one default suite executable and orchestrated by `/e2e/app` against real CLI plus Journey-isolated Hub/schema/filesystem boundaries. |
| `macos/` | macOS runner, architecture-specific desktop packaging integration, and the build-time bundled CLI bridge. |
| `windows/` | Windows x64 runner and build-time bundled CLI integration. |
| `linux/` | Linux x64 runner and build-time bundled CLI integration. |
| `docs/` | App-specific specifications, plans, and decisions. |
| `THIRD_PARTY_NOTICES.md` | Licenses and attribution for vendored App UI code. |

## Boundaries

- After a one-shot compatibility handshake, the App invokes every Hub and local business operation through one typed long-lived CLI Server adapter and must not call public Hub APIs directly. It stores one Hub Origin.
- The CLI owns local installation, update, removal, target detection, `skills.yaml`, `skills-lock.yaml`, Scope Package Stores, and Package Projections.
- The Hub owns the complete public v1 route surface. Official and self-hosted Origins expose the same routes; community-data availability is expressed by valid responses rather than client-side deployment discovery.
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
- Theme controls must update immediately, preserve the selected seed, support localization, and remain usable with keyboard and assistive technology.
- Any new or materially changed UI component must be validated in Light and Dark modes with both low- and high-chroma seeds. Text and icon contrast must use the generated matching semantic roles rather than manual guesses.

## Asynchronous Interaction Policy

- User intent must receive visible feedback in the next rendered frame. Do not wait for Hub, CLI, filesystem, preference, or package operations before opening the requested destination, overlay, or operation surface.
- Keep the App shell, navigation, dismissal, cancellation, and unrelated actions interactive while work is pending. Disable only controls that would duplicate or invalidate the in-flight operation.
- Every remote, process, or filesystem-backed surface must implement five explicit states: `initialLoading`, `content`, `refreshing`, `empty`, and `error`. Do not encode loading as `null` when `null` can also mean empty or unavailable.
- Use geometry-preserving skeletons only for cold loads with no usable content. When usable content already exists, retain it during refresh and expose restrained refresh progress instead of replacing it with a skeleton.
- Independent data dependencies must render and fail independently. A slow optional dependency must not delay primary content or an interactive surface.
- Preserve the last valid local Library inventory during Hub failures and the last valid discovery or detail content during refresh failures when its identity remains valid.
- Long-running mutations may lock their own submit control, but must publish progress and keep safe navigation or cancellation paths available.
- New journeys that depend on asynchronous data require widget tests proving next-frame feedback, stable content during refresh, explicit empty/error recovery, and accessibility semantics.

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
