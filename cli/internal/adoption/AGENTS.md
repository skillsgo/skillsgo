# External Adoption Domain Map
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `adoption.go`: inspects one exact External Installation, binds content/state review, resolves optional Registry matches, and executes content-preserving Registry association or offline Local import.
- `adoption_test.go`: specifies content identity, cancellation-safe preflight, immutable match confirmation, offline Local import, and no replacement.

## Architectural Boundary

This package owns the transition from External Installation to managed Registry or Local provenance. It never publishes Local content and delegates immutable bytes, receipts, project metadata, and Registry transport to their owning modules.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
