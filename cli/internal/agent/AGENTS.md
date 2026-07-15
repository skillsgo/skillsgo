# CLI Agent Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `catalog.go`: defines the complete supported Agent catalog and resolves platform-specific installation paths.
- `catalog_test.go`: specifies catalog parity, special detection, universal visibility, and stable machine-report fields.
- `detect.go`: evaluates read-only installation signals and produces canonical Agent status records.

## Architectural Boundary

This module owns Agent definitions, supported scopes, path resolution, and read-only installation detection. It must not serialize CLI envelopes, mutate installation targets, read localized human output, or depend on App presentation concepts.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
