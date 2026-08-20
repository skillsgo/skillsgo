# SkillsGo Context Map

SkillsGo is a monorepo containing a local CLI, a public Hub, and shared Protocol contracts. Each product context owns a separate model while sharing Skill identity and artifact contracts.

This file is the semantic context index. Structural routing is defined by the root and nested `AGENTS.md` files under the GEB Monorepo Fractal Documentation Protocol.

## Contexts

- [CLI](cli/CONTEXT.md) — owns local Skill execution, storage, Agent adaptation, installation targets, and project reproducibility.
- [Hub](hub/CONTEXT.md) — resolves public Skill sources into immutable artifacts and serves search, ranking, metadata, download, and install-event APIs.

## Relationships

- **Embedding applications → CLI / Hub**: consume stable public contracts without importing implementation internals.
- **CLI → Hub**: resolves versions, downloads verified artifacts, forwards presentation locale for discovery/detail reads, and optionally reports anonymous install events.
- **CLI → Agent targets**: vendors verified Package Versions within user or Workspace scope and generates deterministic per-Agent Package Projections that expose only selected Skills.

Cross-context decisions belong in `docs/adr/`. Context-specific decisions belong in the owning context's `docs/adr/` directory.
