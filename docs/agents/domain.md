# Domain Documentation

This repository uses a multi-context domain documentation layout.

Structural navigation is governed by the GEB Monorepo Fractal Documentation Protocol. Start with the root `AGENTS.md`, then read every nearer `AGENTS.md` on the path to the file you will change. The normative SkillsGo adaptation is documented in `docs/reference/geb-monorepo-protocol.md`.

## Before Exploring

1. Read the root and nearest GEB `AGENTS.md` maps.
2. Read the root `CONTEXT-MAP.md`.
3. Read every context glossary relevant to the task.
4. Read system-wide ADRs under `docs/adr/` and context-specific ADRs under `<context>/docs/adr/`.

If one of these files does not exist, proceed silently. Create or update glossaries and ADRs only through the domain-modeling workflow when terminology or a durable decision is resolved.

## Contexts

- `app/CONTEXT.md`: product experience, library views, projects, external installations, and installation plans.
- `cli/CONTEXT.md`: local execution, Agent adapters, the content-addressed Store, installation targets, and Workspace Sums.
- `hub/CONTEXT.md`: public Skill identity, immutable artifacts, indexing, ranking, and install events.
- `docs/adr/`: decisions that cross two or more contexts.
- `<context>/docs/adr/`: decisions owned by one context.

## Vocabulary

Use the canonical terms defined in the relevant glossary in issue titles, specifications, plans, tests, and implementation notes. Do not drift to synonyms that the glossary explicitly marks as terms to avoid.

GEB maps own structural position, workspace routing, and maintenance obligations. Context documentation owns vocabulary, behavior, and domain boundaries. Keep both aligned when a change affects both structure and meaning.

## ADR Conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly rather than silently overriding the decision.
