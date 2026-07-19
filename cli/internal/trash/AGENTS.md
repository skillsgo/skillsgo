# Trash/
> F3 | Parent: `../../AGENTS.md` | Workspace: `cli`

## Members

- `trash.go`: validates recoverable disposal requests and exposes the platform-neutral move boundary.
- `trash_darwin.go`: moves content into the macOS user Trash without shell interpolation or Automation permission.
- `trash_linux.go`: implements the FreeDesktop Trash layout and metadata contract.
- `trash_windows.go`: delegates disposal to the Windows Recycle Bin.
- `trash_test.go`: verifies missing-path behavior and recoverable moves on the active platform.

## Architectural Boundary

This module owns platform-specific recoverable disposal of user-visible installation content. It must not own transaction cleanup, rollback cleanup, or product-level removal policy.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
