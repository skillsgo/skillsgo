/*
 * [INPUT]: Uses Flutter test finders and rendered theme data, and re-exports canonical skill fixtures.
 * [OUTPUT]: Provides shared finders, semantic matchers, contrast helpers, and the rendered-test fixture surface.
 * [POS]: Serves as presentation-focused support for the split rendered desktop behavior suites.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

export 'skill_fixtures.dart';

Finder searchInput() => find.descendant(
  of: find.byKey(const Key('skill-search-input')),
  matching: find.byType(EditableText),
);

Finder librarySearchInput() => find.descendant(
  of: find.byKey(const Key('library-search')),
  matching: find.byType(EditableText),
);

Finder libraryLocation(String label) => find.descendant(
  of: find.byKey(const Key('library-location-rail')),
  matching: find.text(label),
);

bool isSemanticallySelected(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  return List.generate(
    finder.evaluate().length,
    (index) => tester.getSemantics(finder.at(index)),
  ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue);
}

double contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = aLuminance > bLuminance ? aLuminance : bLuminance;
  final darker = aLuminance > bLuminance ? bLuminance : aLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Brightness shellBrightness(WidgetTester tester) => Theme.of(
  tester.element(find.byKey(const Key('primary-folder-shell'))),
).brightness;
