# Development Scripts/
> F3 | Parent: `../AGENTS.md` | Workspace: `skillsgo`

## Members

- `dev.sh`: validates the macOS development toolchain, removes stale repository-owned development processes, and starts either the complete Process Compose topology or a named dependency-closed subset such as Hub plus PostgreSQL.
- `cleanup-dev.sh`: discovers and terminates stale SkillsGo development process trees without affecting unrelated processes.
- `watch-flutter.sh`: watches maintained App sources and assets and requests Flutter Hot Reload through its PID file.
- `package-app-candidate.sh`: converts one native Flutter Release bundle into a versioned, architecture-isolated Velopack candidate or production channel, signs when publisher identities are available and otherwise publishes the unsigned channel, can append a later version to the same rehearsal feed, and verifies its release manifest, full package, portable package, and platform installer where applicable.
- `collect-app-release-downloads.sh`: converts four verified production channels into exactly four user-facing GitHub Release installers, preserving signed package names and labeling unsigned Windows and macOS packages explicitly, then emits SHA-256 checksums.
- `test-collect-app-release-downloads.sh`: exercises the release-download collector with unsigned, signed, checksum, and missing-artifact fixtures on Linux CI.
- `smoke-app-candidate.sh`: extracts and starts packaged macOS/Linux candidates and verifies the packaged bundled CLI reports the App version; Windows installation smoke remains native PowerShell in CI.
- `prepare-app-update-rehearsal.sh`: preserves the packaged version from `app/pubspec.yaml`, rebuilds the same source as the next patch version, and appends the later full package to one local Velopack feed.
- `serve-update-feed.dart`: exposes one exact Velopack release directory through a traversal-safe loopback-only HTTP origin for update E2E.
- `smoke-app-update-rehearsal.sh`: drives a packaged macOS/Linux client through real local-feed check, download, replacement, restart, and next-patch bundled-CLI verification.
- `build-cli-release.sh`: cross-compiles one supported standalone CLI target from GOWORK-independent dependencies and injects immutable release identity before archiving it.
- `test-build-cli-release.sh`: black-box tests the Linux/amd64 standalone archive, LICENSE, and complete release handshake.

## Architectural Boundary

This module owns repository-level development lifecycle automation, unsigned App candidate packaging/rehearsal, deterministic production-download collection, and the standalone CLI build contract. Development cleanup may identify processes only when their command and repository ownership can both be established, and it must not terminate unrelated port owners or development sessions from other checkouts. Candidate scripts may assemble, locally serve, update, and validate ephemeral CI artifacts; the loopback source is not a production endpoint. Release collectors and CLI build scripts may select, identify, and archive verified outputs, but production signing, publication, and update hosting remain workflow responsibilities.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
