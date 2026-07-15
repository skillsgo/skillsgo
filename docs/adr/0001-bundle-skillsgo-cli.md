---
status: accepted
---

# Bundle the SkillsGo CLI in the App

Production SkillsGo releases bundle and invoke a matching SkillsGo CLI instead of requiring users to install an executable or configure `PATH`. The App and terminal client share one local execution model and stable JSON contracts. A standalone CLI remains available for terminal users, while a custom CLI path is a developer-only option.

This decision preserves the principle that the CLI is the only Skill mutation engine while superseding the App-context decisions that depended on the external `skills` CLI and `skills.sh` APIs.

## Considered Options

- **Require an external CLI**: simpler packaging, but first use depends on terminal knowledge, `PATH`, and version compatibility.
- **Reimplement local operations in Flutter**: self-contained App packaging, but creates duplicate Store, Agent, conflict, and mutation semantics.
- **Bundle the SkillsGo CLI**: adds per-platform build, signing, and version verification work, but gives users an out-of-the-box App while keeping GUI and terminal behavior aligned.

## Consequences

Every App artifact must contain the CLI for its platform and architecture, and startup must verify that the bundled executable is usable and compatible. The bundled CLI is not installed into the system `PATH` and does not replace a standalone user installation.
