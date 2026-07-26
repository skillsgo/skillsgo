# CLI Agent Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `catalog.go`: defines the complete supported Agent catalog, resolves platform-specific managed and read-only discovery roots, and exposes the user root used by shared canonical Skill storage.
- `catalog_test.go`: specifies catalog parity, managed/discovery root separation, special detection, universal visibility, and stable machine-report fields.
- `detect.go`: evaluates read-only installation signals and produces canonical Agent status records including user-level Skill loading paths.

## Architectural Boundary

This module owns Agent definitions, supported scopes, managed/discovery path resolution, discovery verification status, and read-only installation detection. Discovery roots describe visibility and never authorize installation writes; unverified managed-path fallbacks must not be presented as confirmed Agent behavior. The module must not serialize CLI envelopes, mutate installation targets, read localized human output, or depend on App presentation concepts.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
