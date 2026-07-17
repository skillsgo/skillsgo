# Skill Source Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `source.go`: parses supported GitHub references and private Local Skill IDs, preserves explicit selectors, defaults omitted repository versions to `latest`, then validates canonical, path-safe Skill IDs and selector segments.
- `source_test.go`: specifies Hub/local Skill ID normalization plus hostile Skill ID/version segment rejection through the public parser and validators.

## Architectural Boundary

This module owns source-reference syntax and canonical Skill ID validation. It must not fetch Hub artifacts, resolve local installation paths, or infer user targets.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
