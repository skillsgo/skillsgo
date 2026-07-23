/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Cross-destination state restoration, navigation concurrency, focus, scrolling, and accessibility.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/agent_logo.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('detail Back restores query, scroll position and card focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      searchResults: List.generate(
        30,
        (index) => SkillSummary(
          repositoryId: 'example/skills/skill-$index',
          installName: 'skill-$index',
          name: 'Skill $index',
          source: 'example/skills',
          installs: index,
        ),
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'preserve me');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const Key('discover-results')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Skill 20'),
      350,
      scrollable: scrollable,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Skill 20')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(find.text('Skill 20'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(searchInput()).controller.text,
      'preserve me',
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(before, 0.1),
    );
    expect(find.text('Skill 20'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'skill-card-${const SkillCoordinate(repositoryId: 'example/skills/skill-20', name: 'Skill 20').key}',
    );
  });

  testWidgets('an empty ranked collection has localized recovery copy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          discoveryPages: const {'ranking:0': DiscoveryPage(skills: [])},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('No Skills in this collection'), findsOneWidget);
    expect(find.textContaining('nothing here yet'), findsOneWidget);
  });

  for (final failure in const {
    SkillsFailureKind.validation: 'Check what you entered',
    SkillsFailureKind.server: 'Service temporarily unavailable',
    SkillsFailureKind.timeout: 'This is taking too long',
    SkillsFailureKind.offline: 'Can’t connect to SkillsGo',
    SkillsFailureKind.invalidResponse: 'SkillsGo needs an update',
  }.entries) {
    testWidgets('Discover localizes ${failure.key.name} failures', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            discoveryError: SkillsException('raw', kind: failure.key),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();

      expect(find.text(failure.value), findsOneWidget);
      expect(find.text('raw'), findsNothing);
      if (failure.key == SkillsFailureKind.server) {
        final panel = tester.getRect(
          find.byKey(const Key('discover-state-panel')),
        );
        final search = tester.getRect(
          find.byKey(const Key('skill-search-input')),
        );
        expect(panel.width, 720);
        expect(panel.center.dx, search.center.dx);
      }
    });
  }

  testWidgets('destinations keep their independent input and filter state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);

    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'stateful');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('All Skills'), findsOneWidget);
    expect(find.text('All Agents'), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(find.byKey(const Key('library-add-project')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Personalize'), findsWidgets);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Storage'), findsNothing);
    expect(find.text('About'), findsNothing);
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-discover')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(searchInput()).controller.text,
      'stateful',
    );
    expect(find.text('Flutter Pro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(isSemanticallySelected(tester, 'Agents'), isTrue);

    await tester.tap(find.byKey(const Key('primary-destination-discover')));
    await tester.pumpAndSettle();
    await tester.tap(searchInput());
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(searchInput()).controller.text,
      'stateful',
    );
  });

  testWidgets(
    'a Discover request completes while another destination is open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final search = Completer<List<SkillSummary>>();
      final gateway = FakeSkillsGateway(searchCompleter: search);
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.enterText(searchInput(), 'async');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.byKey(const ValueKey('discover-skeleton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      search.complete(gateway.searchResults);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-discover')));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Pro'), findsOneWidget);
      expect(
        tester.widget<EditableText>(searchInput()).controller.text,
        'async',
      );
    },
  );

  testWidgets('an install result survives leaving and reopening Skill detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final install = Completer<CommandResult>();
    final gateway = FakeSkillsGateway(
      installed: false,
      installCompleter: install,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'install');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pump(const Duration(milliseconds: 500));

    install.complete(successCommand(['skillsgo', 'add']));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Installation results'), findsOneWidget);
  });

  testWidgets('Discover restores its collection scroll position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      searchResults: List.generate(
        30,
        (index) => SkillSummary(
          repositoryId: 'example/skills/skill-$index',
          installName: 'skill-$index',
          name: 'Skill $index',
          source: 'example/skills',
          installs: index,
        ),
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'many');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Skill 20'),
      350,
      scrollable: find.descendant(
        of: find.byKey(const Key('discover-results')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Skill 20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-discover')));
    await tester.pumpAndSettle();

    expect(find.text('Skill 20'), findsOneWidget);
  });

  testWidgets('rails and Library filters expose accessible labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const longAgent = 'A Very Long Agent Name That Must Truncate';
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          agentNames: const ['a-very-long-agent-name-that-must-truncate'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hotSemantics = find.bySemanticsLabel('Hot');
    final hotNodes = List.generate(
      hotSemantics.evaluate().length,
      (index) => tester.getSemantics(hotSemantics.at(index)),
    );
    expect(hotNodes.any((node) => node.flagsCollection.isButton), isTrue);
    expect(
      hotNodes.any(
        (node) => node.flagsCollection.isSelected == Tristate.isTrue,
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Add Project'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(longAgent), findsWidgets);
    expect(find.byTooltip(longAgent), findsOneWidget);
  });

  testWidgets('Library Agent filter supports compact multi-selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          agentNames: const ['codex', 'claude-code', 'github-copilot'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('All Agents'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('library-agent-filter'))).width,
      168,
    );
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.bySemanticsLabel('Github Copilot').first).width,
      greaterThan(168),
    );
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claude Code'));
    await tester.pumpAndSettle();

    expect(find.text('× 2'), findsNothing);
    final summaryLogos = find.descendant(
      of: find.byKey(const Key('library-agent-filter')),
      matching: find.byWidgetPredicate(
        (widget) => widget is AgentLogo && widget.size == 17,
      ),
    );
    expect(summaryLogos, findsNWidgets(2));
    expect(
      tester.getTopLeft(summaryLogos.at(1)).dx -
          tester.getTopLeft(summaryLogos.at(0)).dx,
      23,
    );
    expect(find.text('Github Copilot'), findsOneWidget);
    await tester.tap(find.text('All Agents'));
    await tester.pumpAndSettle();
    expect(find.text('All Agents'), findsOneWidget);
  });

  testWidgets('an overflowing Agent filter remains scrollable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 520));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          agentNames: List.generate(20, (index) => 'agent-$index'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    final agentOptions = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.semanticChildCount == 20,
    );
    await tester.drag(agentOptions, const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('Agent 19').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('library-search')).hitTestable(),
      findsOneWidget,
    );
  });
}
