/*
 * [INPUT]: Uses the SkillsGo seeded Material themes, official Mermaid WebView bridge with native test fallback, vendored native Mermaid widgets, and centralized SkillMarkdownView.
 * [OUTPUT]: Specifies semantic Markdown styling, selectable rendering, Mermaid block rendering, and unsupported-diagram fallback.
 * [POS]: Serves as the focused contract suite for the App's unified Skill document reader.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/mermaid/flutter_mermaid.dart';
import 'package:skillsgo/ui/skill_markdown_view.dart';

void main() {
  test('Skill Markdown strips only a leading YAML front matter block', () {
    const markdown = '''---
name: to-tickets
description: Break a plan into tickets.
disable-model-invocation: true
---

# Instructions
''';

    expect(withoutYamlFrontMatter(markdown), '# Instructions\n');
    expect(
      withoutYamlFrontMatter('Intro\n---\nNot front matter'),
      'Intro\n---\nNot front matter',
    );
    expect(withoutYamlFrontMatter('---\nunclosed'), '---\nunclosed');
  });

  for (final brightness in Brightness.values) {
    testWidgets('Skill Markdown uses semantic roles in $brightness mode', (
      tester,
    ) async {
      final theme = buildSkillsTheme(
        const Color(0xFF5865F2),
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: SkillMarkdownView(
              data: '''
# Heading

Body with [link](https://example.com) and `inline code`.

> Quote

| A | B |
| - | - |
| 1 | 2 |

```dart
void main() {}
```
''',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final markdown = tester.widget<Markdown>(find.byType(Markdown));
      final scheme = theme.colorScheme;
      expect(markdown.selectable, isTrue);
      expect(markdown.styleSheet!.p!.color, scheme.onSurface);
      expect(markdown.styleSheet!.a!.color, scheme.primary);
      expect(markdown.styleSheet!.blockquote!.color, scheme.onSurfaceVariant);
      expect(
        (markdown.styleSheet!.codeblockDecoration! as BoxDecoration).color,
        scheme.surfaceContainerHighest,
      );
      expect(
        markdown.styleSheet!.tableBorder!.top.color,
        scheme.outlineVariant,
      );
    });
  }

  testWidgets('renders a Mermaid fenced flowchart as a native diagram', (
    tester,
  ) async {
    // Reduced from the Mermaid flowchart documentation's basic graph example.
    const source = '''
Before

```mermaid
flowchart LR
  A[Start] --> B{Ready?}
  B -->|Yes| C[Ship]
```

After
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: const Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SkillMarkdownView(data: source),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MermaidDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
  });

  testWidgets('preserves unsupported Mermaid source as selectable code', (
    tester,
  ) async {
    // Invalid Mermaid remains visible so users never lose authored source.
    const source = '''
```mermaid
not-a-mermaid-diagram
  unsupported source
```
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: const Scaffold(body: SkillMarkdownView(data: source)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MermaidDiagram), findsNothing);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsOneWidget);
    expect(
      find.text('not-a-mermaid-diagram\n  unsupported source'),
      findsOneWidget,
    );
  });

  testWidgets('renders packet fields with the dedicated native painter', (
    tester,
  ) async {
    const source = '''
```mermaid
packet-beta
  title TCP Packet
  0-15: "Source Port"
  16-31: "Destination Port"
  +8: "Flags"
```
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: const Scaffold(
          body: SizedBox(width: 800, child: SkillMarkdownView(data: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PacketPainter), findsNothing);
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is PacketPainter,
      ),
    );
    expect(paint.painter, isA<PacketPainter>());
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('renders normalized points with the Quadrant native painter', (
    tester,
  ) async {
    const source = '''
```mermaid
quadrantChart
  title Reach and engagement
  x-axis Low Reach --> High Reach
  y-axis Low Engagement --> High Engagement
  quadrant-1 Expand
  quadrant-2 Promote
  Campaign A: [0.3, 0.6]
```
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: const Scaffold(
          body: SizedBox(width: 800, child: SkillMarkdownView(data: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is QuadrantChartPainter,
      ),
    );
    expect(paint.painter, isA<QuadrantChartPainter>());
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('renders weighted hierarchy with the Treemap native painter', (
    tester,
  ) async {
    const source = '''
```mermaid
treemap-beta
"Products"
    "Electronics"
        "Phones": 50
        "Computers": 30
    "Clothing": 40
```
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: const Scaffold(
          body: SizedBox(width: 800, child: SkillMarkdownView(data: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TreemapPainter,
      ),
    );
    expect(paint.painter, isA<TreemapPainter>());
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('renders sets and intersections with the Venn native painter', (
    tester,
  ) async {
    const source = '''
```mermaid
venn-beta
  title Platform skills
  set A["Frontend"]:20
  set B["Backend"]:12
  union A,B["APIs"]:5.3
    text AB1["shared contracts"]
```
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: const Scaffold(
          body: SizedBox(width: 800, child: SkillMarkdownView(data: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is VennPainter,
      ),
    );
    expect(paint.painter, isA<VennPainter>());
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  // Reduced compatibility cases from the public examples in Mermaid's
  // diagram-syntax documentation. Keep these small so failures identify the
  // community renderer feature that changed.
  const supportedMermaidExamples = <String, String>{
    'flowchart': '''
flowchart TD
  A[Christmas] -->|Get money| B(Go shopping)
  B --> C{Let me think}
''',
    'sequence': '''
sequenceDiagram
  Alice->>John: Hello John, how are you?
  John-->>Alice: Great!
''',
    'pie': '''
pie title Pets adopted by volunteers
  "Dogs" : 386
  "Cats" : 85
''',
    'gantt': '''
gantt
  title A Gantt Diagram
  dateFormat YYYY-MM-DD
  section Section
  A task :a1, 2026-01-01, 30d
''',
    'timeline': '''
timeline
  title History of Social Media Platform
  2002 : LinkedIn
  2004 : Facebook
''',
    'kanban': '''
kanban
  todo[Todo]
    task1[Create docs]
''',
    'radar': '''
radar-beta
  axis m[Money], s[Scope], q[Quality]
  curve a[Project A]{3, 4, 5}
''',
    'xy chart': '''
xychart-beta
  x-axis [jan, feb, mar]
  y-axis "Revenue" 0 --> 100
  line [20, 45, 80]
''',
    'class diagram': '''
classDiagram
  Animal <|-- Duck
  class Animal {
    +int age
  }
''',
    'state diagram': '''
stateDiagram-v2
  [*] --> Still
  Still --> Moving : start
  Moving --> [*]
''',
    'er diagram': '''
erDiagram
  CUSTOMER ||--o{ ORDER : places
  CUSTOMER {
    string name
  }
''',
    'requirement diagram': '''
requirementDiagram
  requirement test_req {
    id: 1
    text: the test text
    risk: high
    verifyMethod: test
  }
  element test_entity {
    type: simulation
  }
  test_entity - satisfies -> test_req
''',
    'journey': '''
journey
  title My working day
  section Go to work
    Make tea: 5: Me
    Go upstairs: 3: Me
''',
    'mindmap': '''
mindmap
  root((mindmap))
    Origins
      Long history
    Research
''',
    'sankey': '''
sankey-beta
  Agricultural 'waste',Bio-conversion,124.729
  Bio-conversion,Liquid,0.597
''',
    'git graph': '''
gitGraph
  commit id: "ZERO"
  branch develop
  checkout develop
  commit id: "A" tag: "v1"
  checkout main
  merge develop id: "M"
''',
    'tree view': '''
treeView-beta
root/
    src/
        index.js
    README.md
''',
    'packet': '''
packet-beta
  title TCP Packet
  0-15: "Source Port"
  16-31: "Destination Port"
  +8: "Flags"
''',
    'quadrant chart': '''
quadrantChart
  title Reach and engagement
  x-axis Low Reach --> High Reach
  y-axis Low Engagement --> High Engagement
  quadrant-1 Expand
  quadrant-2 Promote
  quadrant-3 Re-evaluate
  quadrant-4 Improve
  Campaign A: [0.3, 0.6]
''',
    'treemap': '''
treemap-beta
"Products"
    "Electronics"
        "Phones": 50
        "Computers": 30
        "Accessories": 20
    "Clothing"
        "Men's": 40
        "Women's": 40
''',
    'venn': '''
venn-beta
  title Platform skills
  set A["Frontend"]:20
  set B["Backend"]:12
  set C["Data"]:15
  union A,B["APIs"]:5.3
  union C,A,B:1
    text ABC["shared contracts"]
''',
    'swimlane': '''
swimlane-beta LR
  subgraph Customer["Customer"]
    Request["Request help"]
    Done(["Done"])
  end
  subgraph Support["Support"]
    Review{"Can resolve?"}
    Fix["Fix issue"]
  end
  Request --> Review
  Review -->|Yes| Fix --> Done
''',
    'info': 'info showInfo',
    'block': '''
block-beta
  columns 3
  one["One slot"]
  two["Two slots"]:2
  space:2
  three(("Three"))
  one --> two
''',
    'c4 context': r'''
C4Context
  title Banking Context
  Enterprise_Boundary(bank, "Bank") {
    Person(customer, "Customer", "Uses online banking")
    SystemDb(core, "Core banking", "Stores accounts")
  }
  Rel(customer, core, "Uses", "HTTPS")
  UpdateElementStyle(customer, $fontColor="white", $bgColor="#1565C0")
  UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
''',
    'architecture': '''
architecture-beta
  group api(cloud)[API]
  service db(database)[Database] in api
  service disk(disk)[Storage] in api
  service server(server)[Server] in api
  junction split in api
  db:R --> L:split
  split:R -- L:server
  disk:T -[mounts]- B:server
  align row db split server
''',
    'event modeling': '''
eventmodeling
  title Shopping cart
  tf 01 ui CartUI
  tf 02 cmd AddItem { productId: 7 }
  tf 03 evt Cart.ItemAdded [[ItemAddedData]]
  rf 04 evt External.InventoryChanged
  tf 05 pcr InventoryProcessor ->> 04
  data ItemAddedData `json`{
    "productId": 7
  }
  note 03 `text`{
    Published after persistence
  }
''',
    'ishikawa': '''
ishikawa-beta
  Blurry Photo
    Process
      Out of focus
      Shutter speed too slow
    Equipment
      Lens
        Dirty lens
        Damaged lens
    Environment
      Too dark
''',
    'railroad': '''
railroad-beta
  title Command grammar
  command = sequence(
    terminal("git"),
    optional(nonterminal("options")),
    choice(terminal("push"), terminal("pull")),
    zeroOrMore(special("argument"))
  );
''',
    'railroad ebnf': '''
railroad-ebnf-beta
  syntax = "if", condition, [ "then" ], { statement } | ? implementation ?;
''',
    'railroad abnf': '''
railroad-abnf-beta
  token = 1*2ALPHA / %x30-39 [ "x" ];
''',
    'railroad peg': '''
railroad-peg-beta
  token <- !"x" item+ / .;
''',
  };

  test('rejects unsupported Mermaid info grammar', () {
    expect(const MermaidParser().parse('info unsupported'), isNull);
  });

  test('preserves Block grid columns, spaces, and spans', () {
    final result = const MermaidParser().parseWithData('''
block-beta
  columns 3
  A["One"]
  space
  B{"Wide"}:2
  A --> B
''');
    expect(result, isNotNull);
    expect(result!.diagram.type, DiagramType.block);
    expect(result.blockChartData!.columns, 3);
    expect(result.blockChartData!.placements, hasLength(3));
    expect(result.blockChartData!.placements[1].isSpace, isTrue);
    expect(result.blockChartData!.placements[2].span, 2);
    expect(result.diagram.edges, hasLength(1));
    const BlockChartLayout().computeLayout(
      result.diagram,
      result.blockChartData!,
      const MermaidStyle(),
      const Size(600, 400),
    );
    expect(
      result.diagram.getNode('B')!.width,
      greaterThan(result.diagram.getNode('A')!.width),
    );
  });

  test(
    'preserves C4 variant, boundaries, relationships, and layout config',
    () {
      final result = const MermaidParser().parseWithData('''
C4Container
  Container_Boundary(app, "Application") {
    Container(web, "Web", "Dart", "Serves UI")
    ContainerDb(db, "Database", "SQLite", "Stores data")
  }
  Rel(web, db, "Reads", "SQL")
  UpdateLayoutConfig(\$c4ShapeInRow="2")
''');
      expect(result, isNotNull);
      expect(result!.c4ChartData!.kind, C4DiagramKind.container);
      expect(result.c4ChartData!.shapesPerRow, 2);
      expect(result.diagram.subgraphs.single.nodeIds, ['web', 'db']);
      expect(result.diagram.edges.single.label, 'Reads\n[SQL]');
      expect(result.diagram.getNode('db')!.shape, NodeShape.cylinder);
    },
  );

  const c4Variants = <String, C4DiagramKind>{
    'C4Context': C4DiagramKind.context,
    'C4Container': C4DiagramKind.container,
    'C4Component': C4DiagramKind.component,
    'C4Dynamic': C4DiagramKind.dynamic,
    'C4Deployment': C4DiagramKind.deployment,
  };
  for (final variant in c4Variants.entries) {
    test('parses ${variant.key} with native C4 identity', () {
      final result = const MermaidParser().parseWithData('''
${variant.key}
  System(a, "A")
  System(b, "B")
  Rel(a, b, "Uses")
''');
      expect(result?.c4ChartData?.kind, variant.value);
    });
  }

  test(
    'preserves Architecture ports, icons, groups, arrows, and alignment',
    () {
      final result = const MermaidParser().parseWithData('''
architecture-beta title Native Architecture
  group api(cloud)[API]
  group frontend(cloud)[Frontend]
  service db(database)[Database] in api
  service app(server)[Application] in frontend
  junction route in api
  db{group}:R <--> L:app{group}
  app:B -[routes]- T:route
  align column app route
''');
      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.architecture);
      expect(result.diagram.title, 'Native Architecture');
      expect(result.diagram.subgraphs.first.nodeIds, ['db', 'route']);
      expect(result.diagram.subgraphs.last.nodeIds, ['app']);
      expect(result.architectureChartData!.items.first.icon, 'database');
      final edge = result.architectureChartData!.edges.first;
      expect(edge.fromPort, ArchitecturePort.right);
      expect(edge.toPort, ArchitecturePort.left);
      expect(edge.fromGroup, isTrue);
      expect(edge.toGroup, isTrue);
      expect(edge.arrowAtStart, isTrue);
      expect(edge.arrowAtEnd, isTrue);
      expect(
        result.architectureChartData!.alignments.single.axis,
        ArchitectureAlignmentAxis.column,
      );
    },
  );

  test('preserves Event Modeling frames, lanes, data, resets, and sources', () {
    final result = const MermaidParser().parseWithData('''
eventmodeling
  entity CartUI
  entity AddItem
  entity ItemAdded
  tf 01 ui CartUI
  tf 02 command AddItem [[AddItemData]]
  tf 03 event Cart.ItemAdded ->> 02
  rf 04 event External.InventoryChanged
  data AddItemData `json`{
    "productId": 7
  }
  note 03 `text`{
    Stored event
  }
  gwt 03 given ui CartUI when cmd AddItem then evt ItemAdded
''');
    expect(result, isNotNull);
    expect(result!.diagram.type, DiagramType.eventModeling);
    expect(result.eventModelingChartData!.frames, hasLength(4));
    expect(result.eventModelingChartData!.lanes, hasLength(4));
    expect(result.eventModelingChartData!.frames[2].sourceFrameIds, ['02']);
    expect(result.eventModelingChartData!.frames[3].isReset, isTrue);
    expect(result.eventModelingChartData!.data.single.type, 'json');
    expect(result.eventModelingChartData!.notes.single.frameId, '03');
    expect(result.eventModelingChartData!.scenarios.single.frameId, '03');
    expect(
      result.diagram.edges.map((edge) => '${edge.from}-${edge.to}'),
      containsAll(['01-02', '02-03']),
    );
  });

  test('preserves Ishikawa relative indentation and arbitrary depth', () {
    final result = const MermaidParser().parseWithData('''
ishikawa-beta
    Server Outage
Hardware
  Disk
    Capacity
      Full
Software
  Race condition
''');
    expect(result, isNotNull);
    expect(result!.diagram.type, DiagramType.ishikawa);
    final effect = result.ishikawaChartData!.effect;
    expect(effect.text, 'Server Outage');
    expect(effect.children.map((node) => node.text), ['Hardware', 'Software']);
    expect(effect.children.first.children.first.text, 'Disk');
    expect(
      effect.children.first.children.first.children.first.text,
      'Capacity',
    );
    expect(
      effect.children.first.children.first.children.first.children.single.text,
      'Full',
    );
    expect(effect.depth, 5);
  });

  test('normalizes all Railroad dialects into the shared recursive AST', () {
    const examples = <String, RailroadDialect>{
      '''railroad-beta
rule = sequence(terminal("a"), optional(nonterminal("next")), oneOrMore(special("value")));''':
          RailroadDialect.railroad,
      '''railroad-ebnf-beta
rule ::= "a", item?, { "b" } | ? native ?;''':
          RailroadDialect.ebnf,
      '''railroad-abnf-beta
rule = 2*4ALPHA / %x30-39 [ "x" ];''':
          RailroadDialect.abnf,
      '''railroad-peg-beta
rule <- &item item+ / !"x" .;''':
          RailroadDialect.peg,
    };
    for (final example in examples.entries) {
      final result = const MermaidParser().parseWithData(example.key);
      expect(result, isNotNull, reason: '${example.value} should parse');
      expect(result!.diagram.type, DiagramType.railroad);
      expect(result.railroadChartData!.dialect, example.value);
      expect(result.railroadChartData!.rules.single.name, 'rule');
      expect(
        result.railroadChartData!.rules.single.definition.kind,
        anyOf(RailroadExpressionKind.sequence, RailroadExpressionKind.choice),
      );
    }
  });

  test('parses Wardley coordinates, strategy, evolution, and annotations', () {
    const source = '''wardley-beta
title Tea Shop
size [800,600]
evolution Genesis@0.25 -> Custom@0.5 -> Product@0.75 -> Commodity@1.0
anchor Customer [0.95,0.9]
component App [0.8,0.6] label [-20,10] (build)
component Database [0.4,0.5] (buy) (inertia)
Customer -> App
App +'queries'> Database
evolve Database 0.8
pipeline Database {
  component SQL [0.55]
  component "Cloud DB" [0.9]
}
note "Risk" [0.5,0.4]
annotations [0.1,0.9]
annotation 1,[0.6,0.7] "Decision"
accelerator "Cloud" [0.2,0.8]
deaccelerator "Legacy" [0.3,0.2]''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    expect(result!.diagram.type, DiagramType.wardley);
    final data = result.wardleyChartData!;
    expect(data.width, 800);
    expect(data.height, 600);
    expect(data.stages.map((stage) => stage.name), [
      'Genesis',
      'Custom',
      'Product',
      'Commodity',
    ]);
    final app = data.components.firstWhere((item) => item.name == 'App');
    expect(app.strategy, WardleyStrategy.build);
    expect(app.labelOffsetX, -20);
    expect(app.labelOffsetY, 10);
    final database = data.components.firstWhere(
      (item) => item.name == 'Database',
    );
    expect(database.inertia, isTrue);
    expect(data.links.last.label, 'queries');
    expect(data.evolutions.single.target, .8);
    expect(
      data.components.where((item) => item.pipelineParent == 'Database'),
      hasLength(2),
    );
    expect(data.notes.single.text, 'Risk');
    expect(data.annotations.single.text, 'Decision');
    expect(data.forces, hasLength(2));
  });

  test('parses all Cynefin domains, items, and labeled transitions', () {
    const source = '''cynefin-beta:
title Incident Response
complex
  "Investigate root cause"
complicated
  "Expert review"
clear
  "Apply known fix"
chaotic
  "Page on-call"
confusion
  "Unknown failure"
complex --> complicated : "Pattern identified"
clear --> chaotic : "Complacency"''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    expect(result!.diagram.type, DiagramType.cynefin);
    expect(result.diagram.title, 'Incident Response');
    final data = result.cynefinChartData!;
    expect(data.domains, hasLength(5));
    expect(
      data.domains
          .firstWhere((domain) => domain.name == CynefinDomainName.complex)
          .items,
      ['Investigate root cause'],
    );
    expect(data.transitions, hasLength(2));
    expect(data.transitions.first.label, 'Pattern identified');
  });

  for (final example in supportedMermaidExamples.entries) {
    test('parses the official-style ${example.key} compatibility case', () {
      expect(
        const MermaidParser().parse(example.value),
        isNotNull,
        reason: '${example.key} should remain in the admitted native subset',
      );
    });
  }
}
