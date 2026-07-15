# Skill Source Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `source.go`: parses supported GitHub references and validates canonical, path-safe Skill Coordinates and version segments.
- `source_test.go`: specifies coordinate normalization plus hostile coordinate/version segment rejection through the public parser and validators.

## Architectural Boundary

This module owns source-reference syntax and canonical coordinate validation. It must not fetch Registry artifacts, resolve local installation paths, or infer user targets.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
