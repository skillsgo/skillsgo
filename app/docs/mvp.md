# SkillsGo Personal MVP

SkillsGo Personal MVP is a desktop manager for Agent Skills. It discovers public Skills through an open SkillsGo Hub and uses the App-bundled SkillsGo CLI to manage user-level and project-level installations.

See [User Journeys and Information Architecture](user-routes.md) for the complete experience and [`CONTEXT.md`](../CONTEXT.md) for domain language.

## Product Scope

### Onboarding

- Require a two-step Mandatory Onboarding on clean installations before exposing the main destinations.
- Introduce SkillsGo as the user's Agent Skills Store and list Installed Agents without per-Agent progress or Skill counts.
- Let the user add projects manually or continue without project setup.
- Resume interrupted Onboarding without losing projects that were already added.

### Discover

- Search public Skills.
- Browse all-time, latest-24-hour Trending, and Hot rankings.
- Inspect version, source, `SKILL.md`, files, risks, and installation guidance.
- Create a direct Installation Request with explicit location-and-Agent targets from either a result card or Skill detail.

### Library

- Aggregate Skills across User Scope, Added Projects, and Installed Agents.
- Provide All Skills, Global, and Added Project routes in the Library left rail, with a combinable Agent multi-select in the toolbar.
- Show every Installed Agent, including Agents with zero Skills.
- Include both SkillsGo-managed targets and External Installations discovered on disk.
- Aggregate all targets for one logical Skill while allowing different targets to retain different versions.
- Check for Repository updates, update selected dependencies, remove healthy External Installations, or retry failures.
- Batch-take over supported-lock-backed External Installations through verified Repository installation, and remove one healthy exact External target after confirmation.

### Projects

- Add a project through explicit directory selection.
- Do not require the directory to be a Git repository or to contain existing SkillsGo files.
- Read `skillsgo.yaml`, `skillsgo.lock`, and project Agent Skill directories through the bundled CLI.
- Removing a project from the rail only stops tracking it; it never deletes project content.

### Installation

- Bundle and invoke a matching SkillsGo CLI with the production App.
- Select explicit user or Added Project locations and Installed Agents in one Installation Request.
- Let the CLI prepare concrete actions internally without introducing a second user-facing review ceremony.
- Commit each target independently, retain successful results after partial failure, and retry failed targets.
- Return stable Repository transaction and exact-path removal JSON for installation, update, and removal.

### Settings

- General: language, appearance, folder theme, wallpaper, and reminders.
- Agents: detection state, paths, and re-detection.
- Advanced: Hub Origin connectivity, CLI override and recovery, storage status, Critical-risk policy, and restartable Onboarding.

## Explicitly Out of Scope

- Authentication, teams, seats, billing, approval, organization policy, and cloud synchronization.
- Private Skill hosting and enterprise audit.
- Android and iOS.
- Scanning the whole disk for projects.
- Automatically publishing Local Skills to a Hub.
- Silently making Skill versions uniform across projects.
- Updating or repairing an External Installation. Exact-path removal and supported-lock-backed Batch Takeover remain available.
- Pretending that mutations across multiple filesystem locations are one global transaction.

## Integration Boundaries

- The App invokes stable JSON or NDJSON commands on the bundled SkillsGo CLI for Hub-backed and local operations. In Cloud mode it reads Cloud-owned rankings directly from the origin declared by `skillsgo hub info`, then hydrates Skill metadata through the CLI-mediated Hub boundary.
- The bundled CLI is the App's only business-integration boundary; the App never calls a Hub directly.
- The App never parses human-oriented CLI output and never constructs commands through a shell string.
- A standalone CLI remains available to terminal users; the production App does not require a prior CLI install or configured `PATH`.
- Users may configure a self-hosted Hub and all downloaded content remains digest-verified.
- The Hub does not depend on the `skills.sh` website, APIs, or metadata.

## Experience Constraints

- Keep Discover, Library, and Settings as the three top-level destinations.
- Use a Burrow-inspired floating rounded left rail with visible project labels and keep visible Agent labels in the Library filter.
- Gate clean installations on the short Mandatory Onboarding; do not show it to existing users after upgrade.
- Preserve each top-level destination's subpage, scroll position, and running operations across navigation.
- Show concise progress and results by default, with expandable diagnostics.
- Follow system language, reduced-motion, and reduced-transparency preferences.
- Keep the Library and local detail usable while offline.

## Acceptance Criteria

1. A clean desktop installation completes the two-step Mandatory Onboarding with the bundled CLI and no external executable.
2. Welcome displays the complete Installed Agent set without per-Agent progress, Skill counts, or a background Skill scan.
3. A user can add projects manually or continue without project setup.
4. Added projects persist immediately and survive restart during Onboarding.
5. Discover supports Search, Ranking, Trending, and Hot views with complete Skill detail.
6. A user can install one Skill to explicit locations and Installed Agents through one direct request.
7. Multi-target operations return per-target results and allow failed targets to be retried.
8. The Library aggregates by logical Skill and displays targets, scopes, and Version Divergence.
9. The App detects External Installations, can batch-take over supported-lock-backed copies, and can remove one exact External target after confirmation.
10. A user can check, update, and remove selected targets without changing unselected targets.
11. Hub outages, inaccessible projects, unhealthy targets, and CLI failures all have recoverable states.
12. Automated tests cover Onboarding, core CLI machine contracts, aggregation behavior, Installation Requests, and primary Flutter journeys.
