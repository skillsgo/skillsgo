/*
 * [INPUT]: Depends on Settings route state, native SkillsGo components, HugeIcons, the pure-Dart Mermaid renderer, rootBundle, full_svg_flutter, webview_flutter, bundled Beautiful Mermaid SVG, and bundled Mermaid.js 11.16.0.
 * [OUTPUT]: Provides switchable 32-type native, Beautiful Mermaid/fallback, and shared-WebView official Mermaid.js galleries with live App theme mapping.
 * [POS]: Serves as the Advanced Settings child page for visually comparing pure Dart, generated SVG, and official browser-backed Mermaid rendering.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

extension _MermaidGallery on _SettingsScreenState {
  Widget _mermaidGallery() => _MermaidGalleryView(
    onBack: () => updateState(() => showingMermaidGallery = false),
  );
}

class _MermaidGalleryView extends StatefulWidget {
  const _MermaidGalleryView({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_MermaidGalleryView> createState() => _MermaidGalleryViewState();
}

class _MermaidGalleryViewState extends State<_MermaidGalleryView> {
  var _beautiful = false;
  var _webView = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SkillsButton.ghost(
            key: const Key('close-mermaid-gallery'),
            onPressed: widget.onBack,
            leading: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(context.l10n.onboardingBack),
          ),
          const SizedBox(width: 12),
          Text(
            _webView
                ? 'Mermaid.js WebView · ${mermaidGallerySamples.length}'
                : _beautiful
                ? 'Mermaid 对照 · ${mermaidGallerySamples.length}'
                : 'Mermaid · ${mermaidGallerySamples.length}',
            key: const Key('mermaid-gallery-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          SkillsButton.outline(
            key: const Key('show-native-mermaid-gallery'),
            onPressed: _beautiful || _webView
                ? () => setState(() {
                    _beautiful = false;
                    _webView = false;
                  })
                : null,
            child: const Text('Dart 原生 · 32'),
          ),
          const SizedBox(width: 10),
          SkillsButton.outline(
            key: const Key('show-beautiful-mermaid-gallery'),
            onPressed: _beautiful
                ? null
                : () => setState(() {
                    _beautiful = true;
                    _webView = false;
                  }),
            child: const Text('渲染对照 · 32'),
          ),
          const SizedBox(width: 10),
          SkillsButton.outline(
            key: const Key('show-mermaid-js-webview-gallery'),
            onPressed: _webView
                ? null
                : () => setState(() {
                    _beautiful = false;
                    _webView = true;
                  }),
            child: const Text('Mermaid.js WebView · 32'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _webView
                  ? '本地 Mermaid.js 11.16.0 · 全局共享一个 WebView'
                  : _beautiful
                  ? 'beautiful-mermaid SVG · 跟随明暗模式与 App 主题色'
                  : '纯 Dart 解析、布局与 Canvas 绘制',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Expanded(
        child: _webView
            ? const _MermaidJsWebViewGallery()
            : _beautiful
            ? const _BeautifulMermaidGalleryList()
            : ListView.separated(
                key: const Key('mermaid-gallery-list'),
                itemCount: mermaidGallerySamples.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) => _MermaidGalleryCard(
                  sample: mermaidGallerySamples[index],
                  index: index,
                ),
              ),
      ),
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

class _BeautifulMermaidGalleryList extends StatelessWidget {
  const _BeautifulMermaidGalleryList();

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('beautiful-mermaid-gallery-list'),
    itemCount: mermaidGallerySamples.length,
    separatorBuilder: (_, _) => const SizedBox(height: 16),
    itemBuilder: (context, index) {
      final nativeSample = mermaidGallerySamples[index];
      final sample = beautifulMermaidGallerySamplesByTitle[nativeSample.title];
      if (sample == null) {
        return _MermaidGalleryCard(
          sample: nativeSample,
          index: index,
          rendererLabel: 'Dart 原生回退',
        );
      }
      final scheme = Theme.of(context).colorScheme;
      return SkillsCard(
        key: ValueKey('beautiful-mermaid-gallery-card-$index'),
        title: Text('${index + 1}. ${sample.title} · beautiful-mermaid'),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 520),
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: FutureBuilder<String>(
            future: rootBundle.loadString(sample.asset),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return full_svg.FSvgPicture.string(
                _themeBeautifulMermaidSvg(snapshot.data!, scheme),
                key: ValueKey('beautiful-mermaid-diagram-$index'),
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      );
    },
  );
}

String _themeBeautifulMermaidSvg(String source, ColorScheme scheme) {
  String hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  final replacements = <String, Color>{
    '#ffffff': scheme.surface,
    '#27272a': scheme.onSurface,
    '#52525b': scheme.onSurfaceVariant,
    '#71717a': scheme.onSurfaceVariant,
    '#a1a1aa': scheme.outline,
    '#2563eb': scheme.primary,
    '#0f51a3': scheme.secondary,
    '#f4f4f5': scheme.surfaceContainerHighest,
    '#d4d4d8': scheme.outlineVariant,
    '#e4e4e7': scheme.outlineVariant,
    '#dbeafe': scheme.primaryContainer,
    '#e0e7ff': scheme.secondaryContainer,
  };
  var themed = source;
  for (final entry in replacements.entries) {
    themed = themed.replaceAll(entry.key, hex(entry.value));
  }
  return themed;
}

class BeautifulMermaidGallerySample {
  const BeautifulMermaidGallerySample(this.title, this.asset);

  final String title;
  final String asset;
}

const beautifulMermaidGallerySamples = <BeautifulMermaidGallerySample>[
  BeautifulMermaidGallerySample(
    'Flowchart',
    'assets/beautiful-mermaid/flowchart.svg',
  ),
  BeautifulMermaidGallerySample('State', 'assets/beautiful-mermaid/state.svg'),
  BeautifulMermaidGallerySample(
    'Sequence',
    'assets/beautiful-mermaid/sequence.svg',
  ),
  BeautifulMermaidGallerySample('Class', 'assets/beautiful-mermaid/class.svg'),
  BeautifulMermaidGallerySample('ER', 'assets/beautiful-mermaid/er.svg'),
  BeautifulMermaidGallerySample(
    'XY Chart',
    'assets/beautiful-mermaid/xy_chart.svg',
  ),
];

final beautifulMermaidGallerySamplesByTitle = {
  for (final sample in beautifulMermaidGallerySamples) sample.title: sample,
};

class _MermaidGalleryCard extends StatelessWidget {
  const _MermaidGalleryCard({
    required this.sample,
    required this.index,
    this.rendererLabel,
  });

  final MermaidGallerySample sample;
  final int index;
  final String? rendererLabel;

  double? get _previewHeight => switch (sample.title) {
    'Gantt' || 'Pie' || 'Kanban' || 'Sankey' || 'Packet' => 320,
    'Journey' ||
    'Timeline' ||
    'Mindmap' ||
    'XY Chart' ||
    'Treemap' ||
    'Venn' ||
    'Wardley' => 360,
    'Radar' || 'Quadrant Chart' || 'Event Modeling' || 'Ishikawa' => 400,
    'Cynefin' => 420,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = MermaidStyle(
      backgroundColor: scheme.surfaceContainerLow.toARGB32(),
      defaultNodeStyle: NodeStyle(
        fillColor: scheme.surfaceContainerHighest.toARGB32(),
        strokeColor: scheme.primary.toARGB32(),
        textColor: scheme.onSurface.toARGB32(),
        borderRadius: 6,
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: scheme.onSurfaceVariant.toARGB32(),
        labelColor: scheme.onSurface.toARGB32(),
        labelBackgroundColor: scheme.surfaceContainerLow.toARGB32(),
      ),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      themeMode: Theme.of(context).brightness == Brightness.dark
          ? MermaidThemeMode.dark
          : MermaidThemeMode.light,
    );
    return SkillsCard(
      key: ValueKey('mermaid-gallery-card-$index'),
      title: Text(
        '${index + 1}. ${sample.title}'
        '${rendererLabel == null ? '' : ' · $rendererLabel'}',
      ),
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
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: MermaidDiagram(
                key: ValueKey('mermaid-diagram-$index-$sourceIndex'),
                code: sample.sources[sourceIndex],
                height: _previewHeight,
                style: style,
                errorBuilder: (_, error) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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
    'gantt\n  title Native Mermaid\n  dateFormat YYYY-MM-DD\n  section Engine\n    Parse syntax :done, parse, 2026-07-01, 3d\n    Compute layout :active, layout, after parse, 4d\n    Paint canvas :after layout, 3d',
  ),
  MermaidGallerySample(
    'Pie',
    'pie showData\n  title Diagram families\n  "Graphs" : 12\n  "Charts" : 11\n  "Specialized" : 9',
  ),
  MermaidGallerySample(
    'Requirement',
    'requirementDiagram\n  requirement native_renderer {\n    id: 1\n    text: Pure Dart rendering\n    risk: low\n    verifymethod: test\n  }',
  ),
  MermaidGallerySample(
    'Journey',
    'journey\n  title Mermaid preview\n  section Settings\n    Open Advanced: 5: User\n    View diagrams: 5: User',
  ),
  MermaidGallerySample(
    'Timeline',
    'timeline\n  title Native Mermaid\n  2024 : Parser\n  2025 : Layout\n  2026 : All types',
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
    'radar-beta\n  title "Renderer coverage"\n  axis parser["Parser"], layout["Layout"], paint["Paint"], theme["Theme"]\n  curve native["Native"]{5, 4, 5, 4}\n  max 5',
  ),
  MermaidGallerySample(
    'Git Graph',
    'gitGraph\n  commit id: "parser"\n  branch native\n  checkout native\n  commit id: "canvas"\n  checkout main\n  merge native',
  ),
  MermaidGallerySample(
    'Tree View',
    'treeView-beta\n  "app"\n    "lib"\n      "ui"\n        "mermaid"\n    "test"\n      "fixtures"',
  ),
  MermaidGallerySample(
    'C4',
    'C4Context\n  title SkillsGo Mermaid\n  Person(user, "User")\n  System(app, "Flutter App", "Native renderer")\n  Rel(user, app, "Views diagrams")',
  ),
  MermaidGallerySample(
    'Swimlanes',
    'swimlane-beta LR\n  subgraph Parser\n    source[Source] --> ast[AST]\n  end\n  subgraph Renderer\n    layout[Layout] --> canvas[Canvas]\n  end\n  ast --> layout',
  ),
  MermaidGallerySample('Info', 'info showInfo'),
  MermaidGallerySample(
    'Quadrant Chart',
    'quadrantChart\n  title Native compatibility\n  x-axis Partial --> Complete\n  y-axis Experimental --> Stable\n  Native renderer: [0.92, 0.88]',
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
    'ishikawa-beta\n  Native Mermaid\n    Parser\n      Grammar\n      Frontmatter\n    Layout\n      Geometry\n    Painter\n      Canvas',
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
    'venn-beta\n  set Dart["Dart"]\n  set Flutter["Flutter"]\n  union Dart,Flutter["Native Mermaid"]',
  ),
  MermaidGallerySample(
    'Wardley',
    'wardley-beta\n  title Native Renderer\n  anchor User [0.95, 0.15]\n  component Gallery [0.75, 0.45]\n  component Canvas [0.45, 0.75]\n  User -> Gallery\n  Gallery -> Canvas',
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
