# Package Provider Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `provider.go`: provides exact locked Package metadata and Git-tree content through one read-through cache boundary shared by commands and inventory.
- `provider_test.go`: specifies cache hits, automatic cache reconstruction, integrity rejection, and corrupt-entry replacement.

## Architectural Boundary

This module owns capability-based access to exact immutable Package dependencies. It may read and rebuild disposable metadata and Git caches through the Hub, but it must not resolve movable versions, mutate declarations or locks, materialize Agent Projections, or expose cache paths to callers.

[PROTOCOL]: Update this map when this module's members or boundary change.
