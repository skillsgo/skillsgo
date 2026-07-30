/*
 * [INPUT]: Depends on Settings route state, native SkillsGo components, HugeIcons, and the shared CDN-backed Mermaid WebView bridge.
 * [OUTPUT]: Provides a 32-type official Mermaid.js gallery backed by the shared WebView-to-PNG renderer.
 * [POS]: Serves as the Advanced Settings child page for visually auditing the production Mermaid rendering path.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

extension _MermaidGallery on _SettingsScreenState {
  Widget _mermaidGallery() => _MermaidGalleryView(
    onBack: () => updateState(() => showingMermaidGallery = false),
  );
}

class _MermaidGalleryView extends StatelessWidget {
  const _MermaidGalleryView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SkillsButton.ghost(
            key: const Key('close-mermaid-gallery'),
            onPressed: onBack,
            leading: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(context.l10n.onboardingBack),
          ),
          const SizedBox(width: 12),
          Text(
            'Mermaid.js WebView · ${mermaidGallerySamples.length}',
            key: const Key('mermaid-gallery-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        '本地 Mermaid.js 11.16.0 · 全局共享一个 WebView',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 14),
      Expanded(child: const _MermaidJsWebViewGallery()),
    ],
  );
}

class _MermaidJsWebViewGallery extends StatelessWidget {
  const _MermaidJsWebViewGallery();

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('mermaid-js-webview-gallery'),
    itemCount: mermaidGallerySamples.length,
    separatorBuilder: (_, _) => const SizedBox(height: 16),
    itemBuilder: (context, index) {
      final sample = mermaidGallerySamples[index];
      final scheme = Theme.of(context).colorScheme;
      return SkillsCard(
        title: Text('${index + 1}. ${sample.title} · Mermaid.js'),
        child: Column(
          children: [
            for (
              var sourceIndex = 0;
              sourceIndex < sample.sources.length;
              sourceIndex++
            ) ...[
              if (sourceIndex > 0) const SizedBox(height: 12),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 14),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: MermaidWebViewDiagram(
                  key: ValueKey('mermaid-js-diagram-$index-$sourceIndex'),
                  source: sample.sources[sourceIndex],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class MermaidGallerySample {
  MermaidGallerySample(this.title, String source) : sources = [source];

  const MermaidGallerySample.family(this.title, this.sources);

  final String title;
  final List<String> sources;
}

final mermaidGallerySamples = <MermaidGallerySample>[
  MermaidGallerySample(
    'Flowchart',
    'flowchart LR\n  A[Start] --> B{Ready?}\n  B -->|Yes| C[Ship]\n  B -->|No| A',
  ),
  MermaidGallerySample(
    'Sequence',
    'sequenceDiagram\n  participant User\n  participant App\n  User->>App: Open gallery\n  App-->>User: Render diagrams',
  ),
  MermaidGallerySample(
    'ZenUML',
    'zenuml\n  new User\n  new App(source)\n  User -> App.render()',
  ),
  MermaidGallerySample(
    'Class',
    'classDiagram\n  class Diagram {\n    +String source\n    +render()\n  }\n  Diagram <|-- Flowchart',
  ),
  MermaidGallerySample(
    'State',
    'stateDiagram-v2\n  [*] --> Parsing\n  Parsing --> Painting\n  Painting --> [*]',
  ),
  MermaidGallerySample(
    'ER',
    'erDiagram\n  PROJECT ||--o{ DIAGRAM : contains\n  DIAGRAM {\n    string type PK\n    string source\n  }',
  ),
  MermaidGallerySample(
    'Gantt',
    'gantt\n  title Mermaid.js\n  dateFormat YYYY-MM-DD\n  section Engine\n    Parse syntax :done, parse, 2026-07-01, 3d\n    Compute layout :active, layout, after parse, 4d\n    Paint canvas :after layout, 3d',
  ),
  MermaidGallerySample(
    'Pie',
    'pie showData\n  title Diagram families\n  "Graphs" : 12\n  "Charts" : 11\n  "Specialized" : 9',
  ),
  MermaidGallerySample(
    'Requirement',
    'requirementDiagram\n  requirement webview_renderer {\n    id: 1\n    text: Mermaid.js rendering\n    risk: low\n    verifymethod: test\n  }',
  ),
  MermaidGallerySample(
    'Journey',
    'journey\n  title Mermaid preview\n  section Settings\n    Open Advanced: 5: User\n    View diagrams: 5: User',
  ),
  MermaidGallerySample(
    'Timeline',
    'timeline\n  title Mermaid.js\n  2024 : Parser\n  2025 : Layout\n  2026 : All types',
  ),
  MermaidGallerySample(
    'Mindmap',
    'mindmap\n  root((Mermaid))\n    Graphs\n      Flowchart\n      Sequence\n    Charts\n      Pie\n      Radar',
  ),
  MermaidGallerySample(
    'Kanban',
    'kanban\n  todo[Todo]\n    parse[Parse syntax]\n  doing[Doing]\n    layout[Compute layout]\n  done[Done]\n    paint[Paint canvas]',
  ),
  MermaidGallerySample(
    'Sankey',
    'sankey\nSource,Parser,8\nSource,Error,1\nParser,Canvas,7\nParser,Fallback,1',
  ),
  MermaidGallerySample(
    'XY Chart',
    'xychart\n  title "Compatibility"\n  x-axis [Flow, Sequence, Charts, Maps]\n  y-axis "Cases" 0 --> 100\n  bar [100, 100, 100, 100]\n  line [70, 82, 91, 100]',
  ),
  MermaidGallerySample(
    'Radar',
    'radar-beta\n  title "Renderer coverage"\n  axis parser["Parser"], layout["Layout"], paint["Paint"], theme["Theme"]\n  curve webview["WebView"]{5, 4, 5, 4}\n  max 5',
  ),
  MermaidGallerySample(
    'Git Graph',
    'gitGraph\n  commit id: "parser"\n  branch render\n  checkout render\n  commit id: "canvas"\n  checkout main\n  merge render',
  ),
  MermaidGallerySample(
    'Tree View',
    'treeView-beta\n  "app"\n    "lib"\n      "ui"\n        "mermaid"\n    "test"\n      "fixtures"',
  ),
  MermaidGallerySample(
    'C4',
    'C4Context\n  title SkillsGo Mermaid\n  Person(user, "User")\n  System(app, "Flutter App", "Mermaid.js renderer")\n  Rel(user, app, "Views diagrams")',
  ),
  MermaidGallerySample(
    'Swimlanes',
    'swimlane-beta LR\n  subgraph Parser\n    source[Source] --> ast[AST]\n  end\n  subgraph Renderer\n    layout[Layout] --> canvas[Canvas]\n  end\n  ast --> layout',
  ),
  MermaidGallerySample('Info', 'info showInfo'),
  MermaidGallerySample(
    'Quadrant Chart',
    'quadrantChart\n  title WebView compatibility\n  x-axis Partial --> Complete\n  y-axis Experimental --> Stable\n  Mermaid.js renderer: [0.92, 0.88]',
  ),
  MermaidGallerySample(
    'Packet',
    'packet\n  title Diagram Packet\n  0-7: "Type"\n  8-15: "Flags"\n  16-31: "Payload length"',
  ),
  MermaidGallerySample(
    'Block',
    'block\n  columns 3\n  parser[Parser] space layout[Layout]\n  space:2 painter[Painter]\n  parser --> layout\n  layout --> painter',
  ),
  MermaidGallerySample(
    'Event Modeling',
    'eventmodeling\n  tf 01 ui MermaidGallery\n  tf 02 cmd RenderDiagram\n  tf 03 evt DiagramRendered',
  ),
  MermaidGallerySample(
    'Ishikawa',
    'ishikawa-beta\n  Mermaid.js\n    Parser\n      Grammar\n      Frontmatter\n    Layout\n      Geometry\n    Painter\n      Canvas',
  ),
  MermaidGallerySample(
    'Treemap',
    'treemap-beta\n  "Graphs"\n    "Flowchart": 12\n    "Sequence": 8\n  "Charts"\n    "Pie": 5\n    "Radar": 4',
  ),
  MermaidGallerySample.family('Railroad · EBNF · ABNF · PEG', [
    'railroad-beta\nexpression = sequence(nonterminal("term"), zeroOrMore(terminal("+"))) ;',
    'railroad-ebnf-beta\nrule = [ "a" ] , { "b" } , ? special ? ;',
    'railroad-abnf-beta\nrule = 1*3%x41 / [ other-rule ] ;',
    'railroad-peg-beta\nrule <- !"x" ("a" / other)+ . ;',
  ]),
  MermaidGallerySample(
    'Venn',
    'venn-beta\n  set WebView["WebView"]\n  set Mermaid["Mermaid.js"]\n  union WebView,Mermaid["SkillsGo diagrams"]',
  ),
  MermaidGallerySample(
    'Wardley',
    'wardley-beta\n  title WebView Renderer\n  anchor User [0.95, 0.15]\n  component Gallery [0.75, 0.45]\n  component Canvas [0.45, 0.75]\n  User -> Gallery\n  Gallery -> Canvas',
  ),
  MermaidGallerySample(
    'Cynefin',
    'cynefin-beta\n  title Rendering decisions\n  complex\n  complicated\n  clear\n  chaotic',
  ),
  MermaidGallerySample(
    'Architecture',
    'architecture-beta\n  service source(disk)[Source]\n  service parser(server)[Parser]\n  service canvas(cloud)[Canvas]\n  source:R --> L:parser\n  parser:R --> L:canvas',
  ),
];
