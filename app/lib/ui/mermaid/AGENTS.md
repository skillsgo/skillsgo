# Native Mermaid Engine
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Upstream Baseline

- The vendored implementation starts from `flutter_mermaid` 0.1.0, licensed under MIT and recorded in `/app/THIRD_PARTY_NOTICES.md`.
- Compatibility targets Mermaid 11.16.0 at commit `7c0cafcf42e76bfaf79d0cbbd12edb986612f014`.
- The reference checkout lives outside this repository at `/Users/freeman/Documents/Codes/mermaid` and must remain read-only from SkillsGo implementation work.
- Upstream Mermaid examples and tests are compatibility evidence, not runtime dependencies; do not ship JavaScript or a WebView implementation from this module.

## Members

- `flutter_mermaid.dart`: exports the supported native parser, model, layout, painter, configuration, and widget surface.
- `src/parser/`: parses admitted Mermaid syntax into typed native diagram models; SkillsGo-authored extensions cover strict Flowchart, Sequence, Class, State, ER, Requirement, Journey, Mindmap, Sankey, GitGraph, and Tree View semantics, graph families, charts, ZenUML, Block, C4, Architecture, Event Modeling, Ishikawa, the four Railroad grammar dialects, Wardley maps, and Cynefin frameworks.
- `src/models/`: defines diagrams, nodes, edges, typed Flowchart, Sequence, and Swimlane configuration, chart-specific data including complete Sequence, ZenUML, Class, State, ER, Requirement, Journey, Mindmap, Sankey, GitGraph, and Tree View semantics, Packet, Quadrant, Treemap, Venn, Block, C4/Architecture, Event Modeling, Ishikawa, the unified Railroad AST, Wardley coordinates, and Cynefin domains, plus visual styles.
- `src/layout/`: computes native Flutter geometry for graph and chart models, including selectable Dagre D3, Dagre Wrapper, and ELK-style Flowchart paths, configured Sequence participant/message geometry, dedicated rank- and crossing-aware Swimlane lanes, Block/C4 placement, Architecture constraints, Event Modeling timelines, Ishikawa sizing, recursive Railroad rules, Wardley map dimensions, and Cynefin regions.
- `src/painter/`: paints admitted diagrams directly through Flutter Canvas APIs, including every legacy/expanded Flowchart shape, registered icons/images, rich labels, endpoint and curve family, configured Sequence participants/messages/notes/fragments, rank-aware Swimlane bands with orthogonal line hops, exclusion-aware Gantt axes, fully configured/styled XY, Quadrant, Treemap, Journey, Mindmap, Requirement, ER, State, Class, nested-grid Block, compound-group Architecture, and all five C4 variants, optimized multi-set Venn geometry, Wardley and Cynefin charts, the official Info version label, a d3-sankey-compatible relaxed weighted layout, Git branch rail, file tree, timeline, ZenUML fragment, fishbone, and Railroad track renderers.
- `src/widgets/`: composes parsing, responsive layout, error handling, node hit testing, native Sequence participant link menus/callbacks, interaction, and painting into Flutter widgets.
- `src/config/`: extracts lossless YAML frontmatter configuration, defines responsive layout thresholds, and owns native icon/image registries.
- `src/config/icon_registry.dart`: provides the pure-Dart equivalent of Mermaid icon-pack registration for built-in, IconData, and caller-painted vector glyphs without network or browser dependencies.
- `src/config/image_registry.dart`: maps Mermaid image sources to host-decoded Flutter images for direct Canvas rendering without browser or SVG dependencies.
- `LICENSE`: preserves the upstream MIT license text.

## Architectural Boundary

This module owns pure-Dart Mermaid parsing and Flutter-native layout and painting. It must not execute JavaScript, embed browser content, fetch remote rendering resources, or claim compatibility for syntax that is not covered by a passing compatibility case.

Vendored upstream files are exempt from the repository F4 header requirement until SkillsGo modifies their semantics. Every semantically modified vendored Dart file must receive an accurate F4 contract in the same change. New compatibility behavior requires a focused parser or widget test derived into a minimal case from the pinned Mermaid baseline.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
