/*
 * [INPUT]: Uses Flutter widget geometry, StackedToastInteraction, and its controller-driven presentation API.
 * [OUTPUT]: Specifies responsive desktop-right and mobile-centered geometry for the shared transient notification component.
 * [POS]: Serves as the focused responsive-layout contract for global App toast feedback.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/stacked_toast.dart';

void main() {
  Future<Rect> renderToast(WidgetTester tester, {required Size surface}) async {
    await tester.binding.setSurfaceSize(surface);
    final controller = StackedToastController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: StackedToastInteraction(controller: controller),
          ),
        ),
      ),
    );
    controller.show(
      const StackedToastItem(
        id: 'geometry',
        title: 'Installed',
        message: 'Ready to use.',
        duration: Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(const ValueKey('stacked-toast-geometry')));
  }

  testWidgets('desktop toast is compact and anchored to the top right', (
    tester,
  ) async {
    final rect = await renderToast(tester, surface: const Size(1200, 800));

    expect(rect.width, closeTo(440, .01));
    expect(rect.right, closeTo(1200 - 24, .01));
    expect(rect.top, closeTo(10, .05));
  });

  testWidgets('mobile toast remains centered between horizontal insets', (
    tester,
  ) async {
    final rect = await renderToast(tester, surface: const Size(390, 844));

    expect(rect.left, closeTo(16, .01));
    expect(rect.right, closeTo(390 - 16, .01));
    expect(rect.center.dx, closeTo(390 / 2, .01));
    expect(rect.top, closeTo(10, .05));
  });
}
