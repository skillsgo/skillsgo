# Skill Source Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `source.go`: parses equivalent GitHub `owner/repo`, `github/owner/repo`, canonical host, and URL references, preserves explicit selectors, defaults omitted Repository versions to `head`, delegates public Repository ID grammar to Protocol, and separately validates path-shaped identities imported only from third-party skills.sh locks.
- `source_test.go`: specifies GitHub alias equivalence, canonical Repository normalization, third-party identity isolation, and hostile Repository ID/version segment rejection through the public parser and validators.

## Architectural Boundary

This module owns CLI input aliases, source-reference syntax, selectors, and validation at the explicit skills.sh import boundary. Canonical public Repository ID grammar belongs to the Protocol workspace. It must not fetch Hub artifacts, resolve local installation paths, or infer user targets.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
