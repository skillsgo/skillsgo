/*
 * [INPUT]: Depends on Flutter widget testing and the native Mermaid widget interaction and overflow APIs.
 * [OUTPUT]: Verifies participant link callbacks and cross-platform preservation of diagrams wider than their host.
 * [POS]: Serves as a widget-level compatibility gate for native Mermaid interaction and embedding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/mermaid/flutter_mermaid.dart';

void main() {
  testWidgets('dispatches a single Sequence participant link natively', (
    tester,
  ) async {
    (String, String, String)? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MermaidDiagram(
            width: 400,
            height: 300,
            code: '''sequenceDiagram
participant A as Alice
link A: Dashboard @ https://example.com/dashboard
A->>A: Check
''',
            onParticipantLinkTap: (participantId, label, url) {
              selected = (participantId, label, url);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paint = find.byType(CustomPaint).last;
    final origin = tester.getTopLeft(paint);
    await tester.tapAt(origin + const Offset(125, 42));
    await tester.pump();

    expect(selected, ('A', 'Dashboard', 'https://example.com/dashboard'));
  });

  testWidgets('keeps a wide desktop diagram horizontally scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: MermaidDiagram(
                height: 300,
                code: '''mindmap
  root((Mermaid))
    Graphs
      Flowchart
      Sequence
    Charts
      Pie
      Radar''',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final horizontalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScroll, findsOneWidget);
  });
}
