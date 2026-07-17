# Immutable Info Cache/
> F3 | Parent: `cli/AGENTS.md` | Workspace: `cli`

## Members

- `cache.go`: stores and retrieves exact immutable protocol Info bytes using identity-checked, crash-safe entries.
- `cache_test.go`: specifies immutable replay, corruption rejection, and concurrent population behavior.

## Architectural Boundary

This module owns local immutable Info bytes. It must not resolve movable versions, decide Workspace membership, or treat checksum records as cached content.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
