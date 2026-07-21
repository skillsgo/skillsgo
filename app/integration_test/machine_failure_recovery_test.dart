/*
 * [INPUT]: Depends on the rendered App, its bundled CLI, isolated preferences, and an intentionally unreachable Hub origin.
 * [OUTPUT]: Verifies that a real CLI machine failure becomes App-owned localized recovery without exposing developer diagnostics as product copy.
 * [POS]: Serves as the black-box App-to-CLI failure-contract journey orchestrated by e2e/app.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsgo/main.dart' as skillsgo;
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'bundled CLI failure renders App-owned recovery',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('hub_origin', 'http://127.0.0.1:1');
      addTearDown(() => preferences.remove('hub_origin'));

      await skillsgo.runSkillsGoApp(initializeBinding: false);
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();

      final search = find.byKey(const Key('skill-search-input'));
      await _pumpUntil(tester, search, timeout: const Duration(seconds: 30));
      expect(search, findsOneWidget);
      await tester.enterText(
        search,
        'https://github.com/skillsgo/e2e-versioned-skills',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);

      await _pumpUntil(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.contains('Check your internet connection') ==
                      true ||
                  widget.data?.contains('请检查网络连接') == true),
        ),
        timeout: const Duration(seconds: 30),
      );
      expect(find.textContaining('connection refused'), findsNothing);
      expect(find.textContaining('dial tcp'), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}
