# SkillsGo Context Map

SkillsGo is a monorepo containing a desktop App, a local CLI, a public Hub, and a public documentation site. Each product context owns a separate model while sharing the Skill identity and artifact protocol; the documentation site publishes those models without owning them.

This file is the semantic context index. Structural routing is defined by the root and nested `AGENTS.md` files under the GEB Monorepo Fractal Documentation Protocol.

## Contexts

- [App](app/CONTEXT.md) — presents discovery, library, project, Agent, and installation-plan workflows to desktop users.
- [CLI](cli/CONTEXT.md) — owns local Skill execution, storage, Agent adaptation, installation targets, and project reproducibility.
- [Hub](hub/CONTEXT.md) — resolves public Skill sources into immutable artifacts and serves search, ranking, metadata, download, and install-event APIs.
- [Documentation site](docs-site/README.md) — publishes user-facing product and developer documentation from MDX as a separately deployed static surface.

## Relationships

- **App → CLI**: invokes the bundled CLI through stable JSON or NDJSON contracts for every business read and mutation, including Hub-backed discovery and detail journeys.
- **CLI → Hub**: resolves versions, downloads verified artifacts, forwards presentation locale for discovery/detail reads, and optionally reports anonymous install events.
- **CLI → Agent targets**: projects Store artifacts into user-level and Workspace-level Agent directories.
- **Documentation site → App / CLI / Hub**: explains their public contracts and workflows but does not import runtime code or redefine domain language.

Cross-context decisions belong in `docs/adr/`. Context-specific decisions belong in the owning context's `docs/adr/` directory.
