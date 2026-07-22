# Strict JSON Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `decode.go`: decodes repeated machine-input JSON values with unknown-field and trailing-value rejection while delegating domain validation to callers.
- `decode_test.go`: specifies strict decoding and caller-owned validation diagnostics.

## Architectural Boundary

This module owns syntax-level decoding shared by CLI Plan boundaries. It must not own target schemas, domain validation policy, command flags, or user-facing localization.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
