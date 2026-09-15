/*
 * [INPUT]: Uses SkillsPendingSpinner, material widgets, the platform accessibility test dispatcher, and the pending-indicator motion seam.
 * [OUTPUT]: Specifies that the pending indicator rotates while statistics count, holds a still glyph under reduced motion, and renders a determinate ring when progress is measurable.
 * [POS]: Serves as focused motion coverage for the native pending-activity component used by Library statistics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/native_components.dart';

void main() {
  final spinner = find.byType(SkillsPendingSpinner);
  final spin = find.descendant(
    of: spinner,
    matching: find.byType(RotationTransition),
  );

  double turns(WidgetTester tester) =>
      tester.widget<RotationTransition>(spin).turns.value;

  testWidgets('pending indicator rotates while statistics count', (
    tester,
  ) async {
    debugPendingIndicatorMotionEnabled = true;
    addTearDown(() => debugPendingIndicatorMotionEnabled = false);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: SkillsPendingSpinner(size: 14))),
      ),
    );
    expect(turns(tester), 0);

    await tester.pump(const Duration(milliseconds: 450));
    expect(turns(tester), greaterThan(0));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(turns(tester), 0);
  });

  testWidgets('pending indicator shows a determinate ring for known progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: SkillsPendingSpinner(fraction: .4))),
      ),
    );

    expect(spin, findsNothing);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.descendant(
              of: spinner,
              matching: find.byType(CircularProgressIndicator),
            ),
          )
          .value,
      .4,
    );
  });
}
