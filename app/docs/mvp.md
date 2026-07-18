# SkillsGo Personal MVP

SkillsGo Personal MVP is a desktop manager for Agent Skills. It discovers public Skills through an open SkillsGo Hub and uses the App-bundled SkillsGo CLI to manage user-level and project-level installations.

See [User Journeys and Information Architecture](user-routes.md) for the complete experience and [`CONTEXT.md`](../CONTEXT.md) for domain language.

## Product Scope

### Discover

- Search public Skills.
- Browse all-time, latest-24-hour Trending, and Hot rankings.
- Inspect version, source, `SKILL.md`, files, risks, and installation guidance.
- Create an Installation Plan from either a result card or Skill detail.

### Library

- Aggregate Skills across User Scope, Added Projects, and Installed Agents.
- Provide mutually exclusive All, User Scope, project, and Agent views in the left rail.
- Show every Installed Agent, including Agents with zero Skills.
- Include both SkillsGo-managed targets and External Installations discovered on disk.
- Aggregate all targets for one logical Skill while allowing different targets to retain different versions.
- Check for updates and update, remove, repair, or retry selected targets.
- Associate an External Installation with a Hub artifact or import it as a Local Skill.

### Projects

- Add a project only through an explicit directory selection.
- Do not require the directory to be a Git repository or to contain existing SkillsGo files.
- Read `skillsgo.yaml`, `skillsgo.yaml`, and project Agent Skill directories.
- Removing a project from the rail only stops tracking it; it never deletes project content.

### Installation

- Bundle and invoke a matching SkillsGo CLI with the production App.
- Use a multi-location by multi-Agent matrix to select explicit Installation Targets.
- Permit any set of cells in one Installation Plan.
- Commit each target independently, retain successful results after partial failure, and retry failed targets.
- Return stable per-target JSON for installation, update, removal, and repair.

### Settings

- General: language and motion preferences.
- Agents: detection state, paths, and re-detection.
- Hub: official or self-hosted Origin and connectivity.
- Installation policy: symlink or copy, conflicts, risk confirmation, and anonymous install telemetry.
- Storage: Store path, disk usage, and safe cleanup.
- About: App, bundled CLI, updates, licenses, and privacy.

## Explicitly Out of Scope

- Authentication, teams, seats, billing, approval, organization policy, and cloud synchronization.
- Private Skill hosting and enterprise audit.
- Android and iOS.
- Scanning the whole disk for projects.
- Automatically publishing Local Skills to a Hub.
- Silently making Skill versions uniform across projects.
- Updating or repairing an External Installation. Exact-path removal remains available without adoption.
- Pretending that mutations across multiple filesystem locations are one global transaction.

## Integration Boundaries

- The App reads Hub search, ranking, detail, and immutable artifact protocols directly.
- The App invokes stable JSON commands on the bundled SkillsGo CLI for local discovery and mutations.
- The App never parses human-oriented CLI output and never constructs commands through a shell string.
- A standalone CLI remains available to terminal users; the production App does not require a prior CLI install or configured `PATH`.
- Users may configure a self-hosted Hub and all downloaded content remains digest-verified.
- The Hub does not depend on the `skills.sh` website, APIs, or metadata.

## Experience Constraints

- Keep Discover, Library, and Settings as the three top-level destinations.
- Use a Burrow-inspired floating rounded left rail with visible project and Agent labels.
- Do not introduce a blocking first-run wizard.
- Preserve each top-level destination's subpage, scroll position, and running operations across navigation.
- Show concise progress and results by default, with expandable diagnostics.
- Follow system language, reduced-motion, and reduced-transparency preferences.
- Keep the Library and local detail usable while offline.

## Acceptance Criteria

1. A clean desktop installation can launch and use its bundled CLI without an external executable.
2. The App detects and displays every Installed Agent, including Agents with zero Skills.
3. A user can explicitly add projects and restore the project list after restart.
4. Discover supports Search, Ranking, Trending, and Hot views with complete Skill detail.
5. A user can install one Skill to multiple locations and multiple Agents through the matrix.
6. Multi-target operations return per-target results and allow failed targets to be retried.
7. The Library aggregates by logical Skill and displays targets, scopes, and Version Divergence.
8. The App detects External Installations and can associate or import them after confirmation.
9. A user can check, update, and remove selected targets without changing unselected targets.
10. Hub outages, inaccessible projects, unhealthy targets, and CLI failures all have recoverable states.
11. Automated tests cover the core CLI JSON contracts, aggregation behavior, Installation Plans, and primary Flutter journeys.
