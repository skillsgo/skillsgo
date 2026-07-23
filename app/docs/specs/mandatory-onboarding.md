---
status: product-approved
---

# Mandatory First-launch Onboarding

## Product Outcome

A clean installation must complete a short local orientation before entering Discover, Library, or Settings. The journey introduces SkillsGo, shows the Installed Agents reported by the bundled CLI, and gives the user one explicit opportunity to add projects or continue without project setup.

The journey uses Portal Labs `PremiumProgressStepper` with a fixed total of two steps. It contains no color picker, Skill-count presentation, per-Agent loading sequence, account setup, Hub setup, installation-policy choice, or product tour.

## Applicability and Persistence

- Mandatory Onboarding applies only to clean installations.
- The active step and added-project state survive App restart.
- Projects are persisted immediately when added.
- Onboarding becomes permanently complete only when the user activates **Start Using SkillsGo** on the second step.
- Advanced Settings exposes **Restart Onboarding** as a reversible re-entry point. It returns to Welcome without deleting projects, preferences, or Skills data.

## Step 1: Welcome

The first step welcomes the user to **SkillsGo** and briefly states that it discovers, installs, and manages Skills across Agents and projects.

One bundled-CLI read returns the complete Installed Agent set. The page displays Agent identities together, without per-Agent status labels, progress text, or Skill counts. The page starts no Skill inventory, Hub check, project discovery, or other background task.

If the bundled CLI is unavailable, the page offers retry and concise diagnostics. The user cannot complete Onboarding until the local CLI boundary is healthy.

The primary action is **Next**.

## Step 2: Projects

The second step is a cumulative project builder. **Add Now** opens an operating-system picker that accepts one or more directories, never files, and may be used repeatedly. Every selected directory is added in one batch, with duplicate canonical paths retained only once. An adjacent static **Installed > Add Project** path preview teaches where the same action remains available after Onboarding without behaving as navigation inside the mandatory journey. Added Projects appear immediately in a compact five-column wrapping identity grid with their resolved icon or deterministic monogram and single-line name. Hover or keyboard focus reveals an exact remove action that removes only the App reference and never deletes project files.

The Stepper owns one stable completion action labeled **Start Using SkillsGo**, whether the user added projects or chose to continue without them.

## Completion Routing

- If Onboarding added a project, completion opens **Library / All**.
- If the user continues without adding a project, completion opens **Discover / Search**.

## Recovery and Accessibility

- An unreadable selected project reports that the directory cannot be read; it is not presented as an empty result.
- Reduced motion disables or minimizes Stepper spring motion while retaining visible step state.
- Every action remains keyboard accessible and localized through the App's i18n system.
