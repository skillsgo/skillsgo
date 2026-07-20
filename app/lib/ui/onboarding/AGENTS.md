# Mandatory Onboarding
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `onboarding_core.dart`: owns resumable step state, persistence ordering, Agent loading, and project selection.
- `welcome_step.dart`: renders product introduction and detected Agent inventory.
- `projects_step.dart`: renders batch project addition, skip, completion, and error recovery.
- `project_item.dart`: renders one selected project with non-destructive removal affordance.

## Architectural Boundary

This module owns the completion-gated first-launch presentation. It persists progress through `SkillsGateway`, never deletes project data, and must complete or explicitly skip before exposing primary destinations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
