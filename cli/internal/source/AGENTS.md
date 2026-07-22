# Skill Source Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `source.go`: parses equivalent GitHub `owner/repo`, `github/owner/repo`, canonical host, and URL references plus private Local Skill IDs, preserves explicit selectors, defaults omitted repository versions to `latest`, delegates public Skill ID grammar to Protocol, and validates CLI-only Local IDs and selector segments.
- `source_test.go`: specifies GitHub alias equivalence, Hub/local Skill ID normalization, and hostile Skill ID/version segment rejection through the public parser and validators.

## Architectural Boundary

This module owns CLI input aliases, source-reference syntax, Local Skill IDs, and selectors. Canonical public Skill ID grammar belongs to the Protocol workspace. It must not fetch Hub artifacts, resolve local installation paths, or infer user targets.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
