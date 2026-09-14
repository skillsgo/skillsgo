/*
 * [INPUT]: Uses SkillsGoApp, Arabic presentation locale rendering, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies mirrored primary navigation, collection and wallpaper indicator geometry, and LTR isolation for English Hub content.
 * [POS]: Serves as the rendered RTL regression suite for the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/l10n/app_localizations.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  test('Arabic copy uses product terminology and isolates dynamic values', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));

    expect(l10n.hot, 'الأكثر رواجًا');
    expect(l10n.trending, 'الرائجة');
    expect(l10n.commitIdentity('abc123'), 'Commit \u2068abc123\u2069');
    expect(
      l10n.targetSummary('عام', 'Codex', 'v1.2.3'),
      contains('\u2068Codex\u2069'),
    );
    expect(
      l10n.targetSummary('عام', 'Codex', 'v1.2.3'),
      contains('\u2068v1.2.3\u2069'),
    );
  });

  testWidgets('Arabic selected collection indicator follows its tab', (
    tester,
  ) async {
    await _pumpArabicApp(tester);

    final selectedTab = find.byKey(const ValueKey('discover-tab-hot'));
    final indicator = find.byKey(const Key('discover-tab-indicator'));
    expect(
      tester.getCenter(indicator).dx,
      closeTo(tester.getCenter(selectedTab).dx, 1),
    );
  });

  testWidgets('Arabic primary navigation mirrors logical destination order', (
    tester,
  ) async {
    await _pumpArabicApp(tester);

    final discover = tester.getCenter(
      find.byKey(const Key('primary-destination-discover')),
    );
    final settings = tester.getCenter(
      find.byKey(const Key('primary-destination-settings')),
    );
    expect(discover.dx, greaterThan(settings.dx));
  });

  testWidgets('English Hub content remains left to right in Arabic UI', (
    tester,
  ) async {
    await _pumpArabicApp(tester);
    await tester.enterText(
      find.byKey(const Key('skill-search-input')),
      'flutter',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    for (final text in const [
      'Flutter Pro',
      'example/skills',
      'Build Flutter products with reliable engineering flows.',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.textDirection, TextDirection.ltr, reason: text);
    }
  });

  testWidgets('Arabic Library and Settings render without layout overflow', (
    tester,
  ) async {
    await _pumpArabicApp(tester);

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-picker')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic wallpaper indicator follows the visually selected tile', (
    tester,
  ) async {
    await _pumpArabicApp(tester, size: const Size(1200, 1000));
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    final indicator = find.byKey(const Key('wallpaper-selection-indicator'));
    final earth = find.byKey(const ValueKey('wallpaper-earth'));
    await tester.ensureVisible(earth);
    await tester.tap(earth);
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(indicator),
      offsetMoreOrLessEquals(tester.getCenter(earth), epsilon: 0.01),
    );
  });

  testWidgets('English remote detail identity stays left to right', (
    tester,
  ) async {
    await _pumpArabicApp(tester);
    await tester.enterText(
      find.byKey(const Key('skill-search-input')),
      'flutter',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    final title = tester.renderObject<RenderParagraph>(
      find.text('Flutter Pro'),
    );
    expect(title.textDirection, TextDirection.ltr);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpArabicApp(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    SkillsGoApp(gateway: FakeSkillsGateway(language: AppLanguage.arabic)),
  );
  await tester.pumpAndSettle();
}
