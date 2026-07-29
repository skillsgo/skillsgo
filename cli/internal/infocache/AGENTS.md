# Immutable Info Cache/
> F3 | Parent: `cli/AGENTS.md` | Workspace: `cli`

## Members

- `cache.go`: stores, retrieves, and replaces exact immutable protocol Info bytes in the user-level disposable cache using identity-checked, crash-safe entries.
- `cache_test.go`: specifies the user cache root, immutable replay, corruption rejection, and concurrent population behavior.

## Architectural Boundary

This module owns user-level disposable immutable Info bytes shared by every installation scope. Corrupt entries may be replaced only with exact validated Hub bytes through the Package Provider. It must not resolve movable versions, decide Workspace membership, or treat checksum records as cached content.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
