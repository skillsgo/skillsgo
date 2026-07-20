/*
 * [INPUT]: Depends on Flutter widget testing and the locally vendored Portal Labs Archive Folder public interaction contract.
 * [OUTPUT]: Specifies front-child composition beneath the Portal glass border, dark-surface-visible ambient shadow, caller-controlled text colors, optional toggle interaction, open/close behavior, fixed archive-label geometry, archive-item presence, and reduced-motion behavior.
 * [POS]: Serves as the focused regression suite for the exact vendored Archive Folder and its sole additive frontChild extension.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/archive_folder/archive_folder.dart';
import 'package:skillsgo/ui/archive_folder/archive_folder_style.dart';
import 'package:skillsgo/ui/archive_folder/archive_item.dart';

Widget _folder({
  required ValueChanged<bool> onToggle,
  required ValueChanged<int> onItemTap,
  bool reduceMotion = false,
  Color titleColor = Colors.white,
  Color subtitleColor = Colors.white70,
  bool toggleEnabled = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(
      child: ArchiveFolder(
        title: 'Skills',
        subtitles: [
          ArchiveFolderSubtitle(label: 'Status', dotColor: Colors.red),
        ],
        style: ArchiveFolderStyle(
          orientation: ArchiveFolderOrientation.vertical,
          titleStyle: TextStyle(color: titleColor),
          subtitleStyle: TextStyle(color: subtitleColor),
          animationDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          enableHaptics: false,
        ),
        onToggle: onToggle,
        toggleEnabled: toggleEnabled,
        onItemTap: onItemTap,
        frontChild: const ColoredBox(
          key: Key('archive-front-child'),
          color: Colors.transparent,
        ),
        items: const [
          ColoredBox(key: Key('archive-pain-item'), color: Colors.white),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('toggle interaction can be disabled for embedded controls', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _folder(
        onToggle: (_) => toggles++,
        onItemTap: (_) {},
        toggleEnabled: false,
      ),
    );

    final toggle = tester.widget<GestureDetector>(
      find.byKey(const Key('archive-folder-toggle')),
    );
    expect(toggle.onTap, isNull);
    expect(toggles, 0);
  });

  testWidgets('Portal glass border stays above additive front content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArchiveFolder(
            title: 'Archive',
            subtitles: [],
            items: [],
            frontChild: ColoredBox(color: Colors.transparent),
          ),
        ),
      ),
    );

    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byKey(const Key('archive-folder-glass-border')),
            matching: find.byType(Stack),
          )
          .first,
    );
    final frontIndex = stack.children.indexWhere(
      (child) => child.key == const Key('archive-folder-front-child'),
    );
    final borderIndex = stack.children.indexWhere(
      (child) => child.key == const Key('archive-folder-glass-border'),
    );
    expect(frontIndex, greaterThanOrEqualTo(0));
    expect(borderIndex, greaterThan(frontIndex));
  });

  testWidgets('dark surfaces retain a visible folder-colored ambient shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: ArchiveFolder(
            title: 'Archive',
            subtitles: [],
            items: [],
            style: ArchiveFolderStyle(folderColor: Color(0xff0082f4)),
          ),
        ),
      ),
    );

    final flap = tester.widget<Container>(
      find.byKey(const Key('archive-folder-front-flap')),
    );
    final decoration = flap.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNotEmpty);
    expect(decoration.boxShadow!.first.color.r, 0);
    expect(decoration.boxShadow!.first.color.g, closeTo(130 / 255, .001));
    expect(decoration.boxShadow!.first.color.b, closeTo(244 / 255, .001));
    expect(decoration.boxShadow!.first.color.a, closeTo(.28, .001));
  });

  testWidgets('archive item can reserve a fixed two-line label region', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ArchiveItem(
            width: 68,
            height: 68,
            label: 'a very long skill name that needs clamping',
            labelHeight: 28,
            labelMaxLines: 2,
            child: SizedBox.square(dimension: 20),
          ),
        ),
      ),
    );

    final label = tester.widget<Text>(find.textContaining('a very long'));
    expect(label.maxLines, 2);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(
      tester
          .widgetList<Container>(
            find.ancestor(
              of: find.textContaining('a very long'),
              matching: find.byType(Container),
            ),
          )
          .any((container) => container.constraints?.maxHeight == 28),
      isTrue,
    );
  });

  testWidgets('title and subtitle honor caller-provided theme colors', (
    tester,
  ) async {
    const titleColor = Color(0xff123456);
    const subtitleColor = Color(0xff654321);
    await tester.pumpWidget(
      _folder(
        onToggle: (_) {},
        onItemTap: (_) {},
        titleColor: titleColor,
        subtitleColor: subtitleColor,
      ),
    );

    expect(tester.widget<Text>(find.text('Skills')).style?.color, titleColor);
    expect(
      tester.widget<Text>(find.text('Status')).style?.color,
      subtitleColor,
    );
  });

  testWidgets(
    'front child stays on the original flap and items remain usable',
    (tester) async {
      final toggles = <bool>[];
      await tester.pumpWidget(
        _folder(onToggle: toggles.add, onItemTap: (_) {}),
      );

      expect(find.byKey(const Key('archive-front-child')), findsOneWidget);
      await tester.tap(find.text('Skills'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(toggles, [true]);

      expect(find.byKey(const ValueKey('hit_0')), findsOneWidget);

      await tester.tap(find.text('Skills'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(toggles, [true, false]);
    },
  );

  testWidgets('reduced motion opens the folder without transitional frames', (
    tester,
  ) async {
    final toggles = <bool>[];
    await tester.pumpWidget(
      _folder(onToggle: toggles.add, onItemTap: (_) {}, reduceMotion: true),
    );

    await tester.tap(find.text('Skills'));
    await tester.pump();

    expect(toggles, [true]);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
