# Scope Package Tree Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `transaction.go`: verifies and prepares one complete Package Artifact as a symlink-safe Scope Package Store plus stable canonical-name Agent Skill links, migrates legacy coordinate projections, baseline-checks replacements/removals, accepts narrowly explicit reviewed-conflict replacement authorization, and exposes target-aware post-commit disposal for callers that own durable recovery before finalizing or rolling back paths.
- `projection_link_unix.go`: creates and verifies relative symbolic-link Projections on macOS and Linux.
- `projection_link_windows.go`: creates and verifies unprivileged absolute directory-junction Projections on Windows.
- `package.go`: verifies an authoritative coordinate Package Store including safe internal symlinks against its locked Package Sum, reconstructs the canonical Package ZIP, and verifies direct Agent Skill links against immutable members.
- `transaction_test.go`: specifies full filtered-Package Store retention, direct canonical-name Skill links, plugin-manifest ancestry preservation, idempotency, legacy migration, baseline-guarded replacement, Local Modification refusal, finalization, and rollback.

## Architectural Boundary

This module owns filesystem-safe complete Scope Package Tree extraction, locked Tree verification, and deterministic platform-native Agent member-link construction/replacement/removal. Trees are derived from Manifest, Lock, and exact Git content but existing differences remain protected Local Modifications. The module must not contact Hub, parse Workspace YAML, infer Agent choices, link outside the current Scope Tree, or update dependency declarations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
