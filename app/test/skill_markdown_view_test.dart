/*
 * [INPUT]: Uses the SkillsGo seeded Material themes, shared official Mermaid WebView bridge, and centralized SkillMarkdownView.
 * [OUTPUT]: Specifies semantic Markdown styling, selectable rendering, and WebView-only Mermaid block composition.
 * [POS]: Serves as the focused contract suite for the App's unified Skill document reader.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/mermaid_webview_diagram.dart';
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

  testWidgets('routes a Mermaid fenced flowchart to the WebView renderer', (
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

    expect(find.byType(MermaidWebViewDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
  });

  testWidgets('routes unsupported Mermaid source to the WebView renderer', (
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

    expect(find.byType(MermaidWebViewDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('routes packet diagrams to the WebView renderer', (tester) async {
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

    expect(find.byType(MermaidWebViewDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('routes quadrant diagrams to the WebView renderer', (
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

    expect(find.byType(MermaidWebViewDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('routes treemap diagrams to the WebView renderer', (
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

    expect(find.byType(MermaidWebViewDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

  testWidgets('routes venn diagrams to the WebView renderer', (tester) async {
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

    expect(find.byType(MermaidWebViewDiagram), findsOneWidget);
    expect(find.byKey(const Key('mermaid-source-fallback')), findsNothing);
  });

}
