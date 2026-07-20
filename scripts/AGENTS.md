# Development Scripts/
> F3 | Parent: `../AGENTS.md` | Workspace: `skillsgo`

## Members

- `dev.sh`: validates the macOS development toolchain, removes stale repository-owned development processes, and starts Process Compose.
- `cleanup-dev.sh`: discovers and terminates stale SkillsGo development process trees without affecting unrelated processes.
- `watch-flutter.sh`: watches maintained App sources and assets and requests Flutter Hot Reload through its PID file.

## Architectural Boundary

This module owns the repository-level local development lifecycle around Process Compose. It may identify processes only when their command and repository ownership can both be established, and it must not terminate unrelated port owners or development sessions from other checkouts.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
