# SkillsGo Context Map

SkillsGo is a monorepo containing a local CLI, a public Hub, shared Protocol contracts, and a public Web surface. Each product context owns a separate model while sharing Skill identity and artifact contracts.

This file is the semantic context index. Structural routing is defined by the root and nested `AGENTS.md` files under the GEB Monorepo Fractal Documentation Protocol.

## Contexts

- [CLI](cli/CONTEXT.md) — owns local Skill execution, storage, Agent adaptation, installation targets, and project reproducibility.
- [Hub](hub/CONTEXT.md) — resolves public Skill sources into immutable artifacts and serves search, ranking, metadata, download, and install-event APIs.
- [Web](web/README.md) — publishes the product landing page, the public Hub experience under `/hub`, and user-facing documentation under `/docs`.

## Relationships

- **Embedding applications → CLI / Hub**: consume stable public contracts without importing implementation internals.
- **CLI → Hub**: resolves versions, downloads verified artifacts, forwards presentation locale for discovery/detail reads, and optionally reports anonymous install events.
- **CLI → Agent targets**: vendors verified Package Versions within user or Workspace scope and generates deterministic per-Agent Package Projections that expose only selected Skills.
- **Web → Hub**: presents indexable public discovery pages and consumes Hub APIs without owning public Skill identity, search, ranking, or artifacts.
- **Web → CLI / Hub**: explains their public contracts and workflows but does not import runtime code or redefine domain language.

Cross-context decisions belong in `docs/adr/`. Context-specific decisions belong in the owning context's `docs/adr/` directory.
