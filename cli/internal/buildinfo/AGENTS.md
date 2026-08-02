# CLI Build Identity/
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `buildinfo.go`: owns linker-injected CLI product version, optional App bundle version, distribution, commit, and build date.
- `buildinfo_test.go`: specifies safe development defaults and normalized metadata values.

## Architectural Boundary

This module owns immutable build identity only. It must not infer an installation source from filesystem location or accept runtime environment overrides for trusted release identity.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
