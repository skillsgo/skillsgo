# Development Scripts/
> F3 | Parent: `../AGENTS.md` | Workspace: `skillsgo`

## Members

- `dev.sh`: validates the macOS development toolchain, removes stale repository-owned development processes, and starts either the complete Process Compose topology or a named dependency-closed subset such as Hub plus PostgreSQL.
- `cleanup-dev.sh`: discovers and terminates stale SkillsGo development process trees without affecting unrelated processes.
- `watch-flutter.sh`: watches maintained App sources and assets and requests Flutter Hot Reload through its PID file.
- `package-app-candidate.sh`: converts one native Flutter Release bundle into a versioned, architecture-isolated unsigned Velopack candidate and verifies its release manifest, full package, portable package, and platform installer where applicable.
- `smoke-app-candidate.sh`: extracts and starts packaged macOS/Linux candidates and verifies the packaged bundled CLI reports the App version; Windows installation smoke remains native PowerShell in CI.

## Architectural Boundary

This module owns repository-level development lifecycle automation and unsigned App candidate packaging/rehearsal. Development cleanup may identify processes only when their command and repository ownership can both be established, and it must not terminate unrelated port owners or development sessions from other checkouts. Candidate scripts may assemble and validate local or CI artifacts, but production signing, notarization, publication, and update hosting remain outside this module.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
