/*
 * [INPUT]: Uses the shared SkillsNavigationButton, SkillsGo theme, HugeIcons, image widgets, and localized labels from multiple writing systems.
 * [OUTPUT]: Specifies icon/image/fallback identity precedence, accessible button semantics, layout-stable selected coloring, and Unicode-safe multilingual navigation abbreviations.
 * [POS]: Serves as the focused component contract suite for reusable side-navigation buttons.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skillsgo/ui/design_system/skills_theme.dart';
import 'package:skillsgo/ui/nested_navigation.dart';

void main() {
  testWidgets(
    'navigation button resolves icon, image, then fallback identity',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSkillsTheme(const Color(0xFF5865F2)),
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: Column(
                children: [
                  SkillsNavigationButton(
                    label: 'Global Skills',
                    icon: HugeIcons.strokeRoundedUser,
                    selected: false,
                    onPressed: _noop,
                  ),
                  SkillsNavigationButton(
                    label: 'Rspack',
                    image: const ColoredBox(
                      key: Key('navigation-test-image'),
                      color: Colors.blue,
                    ),
                    selected: false,
                    onPressed: _noop,
                  ),
                  SkillsNavigationButton(
                    label: '技能管理',
                    selected: true,
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HugeIcon), findsOneWidget);
      expect(find.byKey(const Key('navigation-test-image')), findsOneWidget);
      expect(
        find.byKey(const Key('skills-navigation-fallback-identity')),
        findsOneWidget,
      );
      expect(find.text('技能'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('技能管理'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    },
  );

  test('navigation abbreviations preserve multilingual grapheme clusters', () {
    expect(skillsNavigationAbbreviation('Rspack'), 'RS');
    expect(skillsNavigationAbbreviation('Skill Manager'), 'SM');
    expect(skillsNavigationAbbreviation('技能管理'), '技能');
    expect(skillsNavigationAbbreviation('スキル管理'), 'スキ');
    expect(skillsNavigationAbbreviation('إدارة المهارات'), 'إا');
    expect(skillsNavigationAbbreviation('👩🏽‍💻 tools'), '👩🏽‍💻T');
    expect(skillsNavigationAbbreviation('  '), '?');
  });

  testWidgets('selection coloring does not mutate text layout style', (
    tester,
  ) async {
    var selected = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkillsTheme(const Color(0xFF5865F2)),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SkillsNavigationButton(
                label: 'Global Skills',
                icon: HugeIcons.strokeRoundedUser,
                selected: selected,
                onPressed: _noop,
              );
            },
          ),
        ),
      ),
    );

    Text label() => tester.widget<Text>(find.text('Global Skills'));
    final initialStyle = label().style;
    final initialSize = tester.getSize(find.text('Global Skills'));
    update(() => selected = true);
    await tester.pump();

    expect(label().style, initialStyle);
    expect(tester.getSize(find.text('Global Skills')), initialSize);
    expect(
      find.byKey(const Key('skills-navigation-label-color')),
      findsOneWidget,
    );
  });
}

void _noop() {}
