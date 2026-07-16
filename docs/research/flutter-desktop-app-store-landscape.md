# Flutter Desktop App Store Landscape

## Purpose

This research identifies open-source products that can inform the SkillsGo desktop application's store and local-library experience. It prioritizes projects that are:

- implemented with Flutter;
- designed for desktop platforms;
- real software catalogs or package managers rather than static UI demos;
- open source with a verifiable license; and
- useful as product, interaction, or engineering references.

The review uses project-owned repositories, documentation, source trees, licenses, and release pages as primary sources. Repository activity was checked on 2026-07-16.

## Executive conclusion

There is no polished, platform-neutral, open-source Flutter desktop App Store that is suitable for wholesale adoption across macOS, Windows, and Linux.

The strongest references are complementary rather than interchangeable:

1. **Ubuntu App Center** is the best production engineering reference for a complete store lifecycle.
2. **AppImagePool** is the closest established reference for a compact Flutter desktop store information architecture.
3. **Outlet** is a promising modern reference for a smaller Flatpak-focused desktop client, but it has limited adoption.
4. **Obtainium** is the best source-driven update workflow reference, but it is Android-only.
5. **Zapstore** is useful for publisher identity, artifact verification, and trust signals, but it is Android-only.

SkillsGo should not fork one of these projects as its product foundation. It should retain its current application architecture and selectively adopt proven interaction and domain patterns.

## Evaluation matrix

| Project | Flutter target | Store lifecycle | Activity | License | Recommendation |
| --- | --- | --- | --- | --- | --- |
| [Ubuntu App Center](https://github.com/ubuntu/app-center) | Linux desktop | Search, discovery, details, install, remove, update, ratings | Active production project | GPL-3.0 | Best engineering reference |
| [AppImagePool](https://github.com/prateekmedia/appimagepool) | Linux desktop | Browse, categories, details, versions, download, integrate, remove | Repository maintained; latest formal release is old | GPL-3.0 | Best compact desktop-store reference |
| [Outlet](https://github.com/jardon/outlet) | Linux desktop | Find and manage Flatpak applications, fuzzy search | Active but very small community | GPL-3.0 | Watch and borrow focused patterns |
| [dahliaOS App Store](https://github.com/dahliaOS/app_store) | Linux, macOS, Windows, web runners | Third-party app catalog | Stalled since 2023 | Apache-2.0 | Do not adopt; useful only as a historical sample |
| [JappeOS Software Center](https://github.com/JappeOS/jappeos_software_center) | Linux desktop | Pacman and Flatpak install, update, uninstall | Experimental | AGPL-3.0 | Do not depend on it |
| [WSL Manager](https://github.com/bostrot/wsl2-distro-manager) | Windows desktop | Catalog and lifecycle for WSL distributions | Active | GPL-3.0 / commercial dual license | Desktop-shell reference, not a general app store |
| [WSA PacMan](https://github.com/alesimula/wsa_pacman) | Windows desktop | APK inspection, install, upgrade, downgrade | Last release in 2023 | GPL-3.0 | Installer-state reference only |
| [Obtainium](https://github.com/ImranR98/Obtainium) | Android | Add sources, track installed apps, check and apply updates | Highly active | GPL-3.0 | Best update/source model reference |
| [Zapstore](https://github.com/zapstore/zapstore) | Android | Discovery, publisher identity, direct distribution, verification | Active | MIT | Best trust and provenance reference |

## Primary desktop candidates

### Ubuntu App Center

[Ubuntu App Center](https://github.com/ubuntu/app-center) is Canonical's production Ubuntu application store. The repository identifies it as an App Store made with Flutter and is predominantly Dart. Its application source is organized under `packages/app_center` and targets Linux.

Its current package architecture exposes the breadth of a real store product:

- exploration and search;
- application details;
- installed-application management;
- Snap integration;
- Deb and PackageKit integration;
- ratings;
- asynchronous install and update states;
- localization, caching, and error handling.

The current app package uses Riverpod and integrates deeply with Ubuntu-specific packages and services, including Yaru, Ubuntu Widgets, Snapd, PackageKit, DBus, GTK, and AppStream. This makes the project valuable for engineering study but expensive to extract as a cross-platform foundation.

**Use for SkillsGo:** lifecycle state machines, progress and failure states, separation of explore/search/manage domains, integration tests, and resilient package operations.

**Do not use as the SkillsGo visual baseline:** its design language is deliberately Ubuntu/Yaru-specific, and its dense platform integration would add irrelevant dependencies.

### AppImagePool

[AppImagePool](https://github.com/prateekmedia/appimagepool) is a Flutter Linux client for AppImageHub. Its documented features include simplified categories, direct GitHub downloads, system integration and removal of AppImages, version history, and multiple downloads.

It is closer to the scale of SkillsGo than Ubuntu App Center. The product combines catalog discovery with an installed/downloaded library and presents them inside a conventional desktop application structure. The project only has a Linux runner and uses a Linux-native visual stack, so it is still not a cross-platform base.

The repository received changes in 2026, but its latest formal GitHub release is from 2023. That difference means it is useful as a pattern library, not as a dependency whose release cadence SkillsGo should inherit.

**Use for SkillsGo:** compact store information architecture, category navigation, grid/list results, download queue, installed-item transitions, and version-history presentation.

**Official visual reference:** [AppImagePool screenshots and README](https://github.com/prateekmedia/appimagepool#appimagepool).

### Outlet

[Outlet](https://github.com/jardon/outlet) is a newer Flutter Linux frontend for finding and managing Flatpak applications. It documents system-theme support, a responsive collapsible sidebar, and fuzzy search. The project shipped release `1.1.1` in March 2026.

Outlet is interesting because it is smaller and more focused than Ubuntu App Center while still operating on real package state. Its current community size is very small, so it has not yet demonstrated the maintenance and edge-case maturity expected from a foundation project.

**Use for SkillsGo:** fuzzy-search behavior, responsive desktop navigation, and a narrow adapter around a package backend.

**Do not use as the foundation:** Linux/Flatpak coupling, GPL-3.0 licensing, and limited production validation.

## Mobile references with relevant domain patterns

### Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) installs and updates Android applications directly from their release sources. It supports many source adapters, including GitHub, GitLab, Forgejo, F-Droid, and direct links. Its core user journey is unusually close to SkillsGo's local-management problem:

1. add an artifact source;
2. resolve source metadata;
3. record the installed item;
4. check the source for a newer version;
5. select and install an update;
6. surface source-specific errors and limitations.

It is Android-only and therefore unsuitable for desktop layout reuse.

**Use for SkillsGo:** source adapter boundaries, update checks, installed-versus-available state, per-source settings, and partial-failure handling.

### Zapstore

[Zapstore](https://github.com/zapstore/zapstore) is an MIT-licensed Flutter Android application store. Its official README describes developer publishing, community curation, publisher identity, direct APK distribution, and verification of file hashes and signing certificates.

**Use for SkillsGo:** publisher identity, verified versus unverified states, artifact provenance, signature/hash language, and community trust signals.

**Do not use for SkillsGo's desktop shell:** the repository is explicitly a Flutter mobile app and only documents Android builds.

## Secondary and rejected candidates

### dahliaOS App Store

[dahliaOS App Store](https://github.com/dahliaOS/app_store) is notable because its repository contains Linux, macOS, Windows, and web runners and uses the permissive Apache-2.0 license. However, development has effectively stopped, the Dart constraints are old, and it has no mature release history. Its card-heavy presentation also resembles a web storefront more than the desktop utility direction SkillsGo needs.

### JappeOS Software Center

[JappeOS Software Center](https://github.com/JappeOS/jappeos_software_center) is an experimental Flutter Linux software center that integrates Pacman and Flatpak operations. It is too early and too lightly validated to use as an architectural reference. Its AGPL-3.0 license also requires careful consideration for derivative work.

### WSL Manager and WSA PacMan

[WSL Manager](https://github.com/bostrot/wsl2-distro-manager) is a successful Flutter Windows utility that can install and manage WSL distributions. It is useful for observing Windows-native desktop layout and long-running local operations, but its domain is instance management rather than application discovery.

[WSA PacMan](https://github.com/alesimula/wsa_pacman) provides a desktop GUI for inspecting, installing, upgrading, and downgrading Android packages through Windows Subsystem for Android. It lacks a searchable catalog and its upstream platform is no longer a sound long-term dependency. It should be treated as an installer-state sample only.

## Licensing implications

The strongest desktop candidates are GPL-3.0. Reading and learning from their interaction and architectural patterns is safe, but copying meaningful implementation code into SkillsGo can impose GPL obligations on the derivative work. SkillsGo's open-source application may be compatible with that direction, but the choice should be explicit and should account for any future proprietary distribution strategy.

Zapstore's MIT license is more permissive, but its reusable value is mainly domain modeling and mobile interaction rather than desktop implementation.

This report is not legal advice. Any planned source-code reuse should receive a project-specific license review before implementation.

## Recommendation for SkillsGo

Use a four-source reference strategy:

- **Desktop information architecture:** AppImagePool.
- **Production install/update engineering:** Ubuntu App Center.
- **Source and update domain model:** Obtainium.
- **Trust, provenance, and publisher presentation:** Zapstore.

Keep the existing SkillsGo codebase and design system. Reproduce the relevant behaviors through SkillsGo-owned abstractions rather than importing one project's platform or UI stack.

For the next practical investigation, run and inspect projects in this order:

1. AppImagePool, to evaluate the desktop browse/library structure.
2. Ubuntu App Center, to trace install, remove, update, progress, and error state flows.
3. Obtainium, to model source resolution and update checking independently of a desktop shell.

The desired result is not a clone. It is a native desktop SkillsGo product that combines proven store workflows with its own multi-project, multi-agent library model.
