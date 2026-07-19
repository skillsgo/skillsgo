# System ADRs
> Decision Map | Parent: `/AGENTS.md`

## Members

- `0001-bundle-skillsgo-cli.md`: establishes the bundled CLI as the shared local execution engine for the App and terminal users.
- `0002-name-public-distribution-context-hub.md`: establishes SkillsGo Hub as the shared product and domain name for public Skill discovery and distribution.
- `0003-use-public-skill-ids.md`: establishes one canonical public Skill ID, removes the separate Skill Identity concept, and distinguishes public IDs from internal database row IDs.
- `0004-separate-module-and-api-surfaces.md`: separates Go-like artifact distribution under `/mod`, product APIs under `/api/v1`, and portable local intent in `skillsgo.mod`.
- `0005-route-app-through-cli-and-stabilize-machine-failures.md`: makes the CLI the App's only business-integration boundary and establishes the minimal public machine-failure contract for App and automation callers.
- `0006-trust-skills-sh-locks-for-batch-takeover.md`: defines trusted source identity for skills.sh lock entries, captured content/filesystem-state baselines, and exact Hub Content Match for remaining External Installations.

## Architectural Boundary

This directory owns decisions that cross two or more SkillsGo contexts. App-only, CLI-only, and Hub-only decisions belong in the owning context's `docs/adr/` directory.

When adding, removing, renaming, superseding, or moving a system ADR, update this member list in the same change.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
