# SkillsGo Context Map

SkillsGo is a monorepo containing a desktop App, a local CLI, and a public Hub. Each context owns a separate model while sharing the Skill identity and artifact protocol.

This file is the semantic context index. Structural routing is defined by the root and nested `AGENTS.md` files under the GEB Monorepo Fractal Documentation Protocol.

## Contexts

- [App](app/CONTEXT.md) — presents discovery, library, project, Agent, and installation-plan workflows to desktop users.
- [CLI](cli/CONTEXT.md) — owns local Skill execution, storage, Agent adaptation, installation targets, and project reproducibility.
- [Hub](hub/CONTEXT.md) — resolves public Skill sources into immutable artifacts and serves search, ranking, metadata, download, and install-event APIs.

## Relationships

- **App → Hub**: reads search, ranking, detail, risk, and immutable artifact metadata.
- **App → CLI**: invokes the bundled CLI through stable JSON contracts for local discovery and mutations.
- **CLI → Hub**: resolves versions, downloads verified artifacts, and optionally reports anonymous install events.
- **CLI → Agent targets**: projects Store artifacts into user-level and Workspace-level Agent directories.

Cross-context decisions belong in `docs/adr/`. Context-specific decisions belong in the owning context's `docs/adr/` directory.
