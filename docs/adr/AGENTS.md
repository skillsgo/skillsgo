# System ADRs
> Decision Map | Parent: `/AGENTS.md`

## Members

- `0001-bundle-skillsgo-cli.md`: establishes the bundled CLI as the shared local execution engine for the App and terminal users.
- `0002-name-public-distribution-context-hub.md`: establishes SkillsGo Hub as the shared product and domain name for public Skill discovery and distribution.
- `0003-use-public-skill-ids.md`: establishes one canonical public Skill ID, removes the separate Skill Identity concept, and distinguishes public IDs from internal database row IDs.

## Architectural Boundary

This directory owns decisions that cross two or more SkillsGo contexts. App-only, CLI-only, and Hub-only decisions belong in the owning context's `docs/adr/` directory.

When adding, removing, renaming, superseding, or moving a system ADR, update this member list in the same change.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
