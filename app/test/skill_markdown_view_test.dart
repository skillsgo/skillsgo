/*
 * [INPUT]: Uses the SkillsGo seeded Material themes and centralized SkillMarkdownView.
 * [OUTPUT]: Specifies semantic Markdown styling and selectable rendering in Light and Dark modes.
 * [POS]: Serves as the focused contract suite for the App's unified Skill document reader.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/brand.dart';
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
}
