# CLI Self Update/
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `checker.go`: fetches bounded Manifest bytes from the fixed SkillsGo CDN, verifies Ed25519 signatures before parsing, validates artifact identity and digest metadata, and compares versions.
- `checker_test.go`: specifies valid checks plus signature, redirect, origin, platform, schema, and downgrade rejection.

## Architectural Boundary

This module owns trusted CLI release discovery. It may read signed metadata but does not replace executables; mutation policy remains installation-source aware and requires a separately reviewed updater.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
