/*
 * [INPUT]: Uses SkillsGoApp with a controllable SkillsGateway fake plus locale, motion, focus, and keyboard settings.
 * [OUTPUT]: Specifies startup, nested navigation, discovery/detail recovery, Agent-aware Library/Settings, focus restoration, accessibility, and mutation journeys.
 * [POS]: Serves as the highest App behavior suite at the rendered desktop interface seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

void main() {
  testWidgets('follows the system locale and renders Simplified Chinese', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.text('发现'), findsOneWidget);
    expect(find.text('技能库'), findsOneWidget);
    expect(find.text('找到下一步所需的技能。'), findsOneWidget);

    for (final route in const {
      '排行': '历史排行',
      '趋势': '最近 24 小时趋势',
      '热门': '当前热门',
    }.entries) {
      await tester.tap(find.text(route.key));
      await tester.pumpAndSettle();
      expect(find.text(route.value), findsOneWidget);
    }
  });

  testWidgets('localizes missing bundled CLI recovery guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(cliReady: false)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('内置的 SkillsGo CLI 缺失或无法运行。请重新安装 SkillsGo。'),
      findsOneWidget,
    );
    expect(find.text('raw process diagnostic'), findsNothing);
  });

  testWidgets('starts in Discover and searches through the gateway', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Find a skill for your next move.'), findsOneWidget);
    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(gateway.queries, ['flutter']);
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
  });

  testWidgets('all Discover collections show comparison metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const base = SkillSummary(
      id: 'github.com/acme/skills/-/planner',
      skillId: 'planner',
      name: 'Planner',
      description: 'Turn product goals into a concrete execution plan.',
      source: 'github.com/acme/skills',
      latestVersion: 'v1.2.3',
      installs: 1200,
      trustLevel: SkillTrustLevel.communityVerified,
      riskAssessment: SkillRiskAssessment.low,
      localTargetCount: 2,
    );
    final gateway = FakeSkillsGateway(
      discoveryPages: const {
        'ranking:0': DiscoveryPage(skills: [base]),
        'trending:0': DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/skills/-/planner',
              skillId: 'planner',
              name: 'Planner',
              description: 'Turn product goals into a concrete execution plan.',
              source: 'github.com/acme/skills',
              latestVersion: 'v1.2.3',
              installs: 42,
              metricKind: SkillMetricKind.installs24h,
            ),
          ],
        ),
        'hot:0': DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/skills/-/planner',
              skillId: 'planner',
              name: 'Planner',
              description: 'Turn product goals into a concrete execution plan.',
              source: 'github.com/acme/skills',
              latestVersion: 'v1.2.3',
              installs: 7,
              metricKind: SkillMetricKind.hotVelocity,
              metricChange: 3,
            ),
          ],
        ),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    expect(
      find.text('Turn product goals into a concrete execution plan.'),
      findsOneWidget,
    );
    expect(find.text('github.com/acme/skills'), findsOneWidget);
    expect(find.text('v1.2.3'), findsOneWidget);
    expect(find.text('Community verified'), findsOneWidget);
    expect(find.text('Low risk'), findsOneWidget);
    expect(find.text('2 local targets'), findsOneWidget);
    expect(find.text('Install to More Targets'), findsOneWidget);
    expect(find.text('1.2K all-time installs'), findsOneWidget);

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    expect(find.text('42 installs / 24h'), findsOneWidget);

    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(find.text('7 this hour · +3'), findsOneWidget);
    expect(
      gateway.collections,
      containsAll(DiscoveryCollection.values.skip(1)),
    );
  });

  testWidgets('Discover pagination appends the next stable page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      discoveryPages: const {
        'ranking:0': DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/a',
              skillId: 'a',
              name: 'Alpha',
              source: 'github.com/acme/a',
              installs: 2,
            ),
          ],
          nextOffset: 20,
        ),
        'ranking:20': DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/b',
              skillId: 'b',
              name: 'Bravo',
              source: 'github.com/acme/b',
              installs: 1,
            ),
          ],
        ),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Bravo'), findsOneWidget);
    expect(gateway.requestedOffsets, [0, 20]);
  });

  testWidgets('Discover keeps results and localizes pagination failures', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      discoveryPages: const {
        'ranking:0': DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/a',
              skillId: 'a',
              name: 'Alpha',
              source: 'github.com/acme/a',
              installs: 2,
            ),
          ],
          nextOffset: 20,
        ),
      },
      discoveryErrors: const {
        'ranking:20': SkillsException('raw', kind: SkillsFailureKind.timeout),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining('too long to respond'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('raw'), findsNothing);
  });

  testWidgets('installed discovery action never repeats the known target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const installedSkill = SkillSummary(
      id: 'github.com/acme/skills/-/planner',
      skillId: 'planner',
      name: 'Planner',
      source: 'github.com/acme/skills',
      installs: 10,
      localTargetCount: 1,
    );
    final gateway = FakeSkillsGateway(
      discoveryPages: const {
        'ranking:0': DiscoveryPage(skills: [installedSkill]),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install to More Targets'));
    await tester.pumpAndSettle();

    expect(gateway.installCalls, 0);
    expect(find.text('Your Library'), findsOneWidget);
  });

  testWidgets('auditable detail exposes immutable evidence and files', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final gateway = FakeSkillsGateway(installed: false);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Real instructions'), findsOneWidget);
    expect(find.text('Immutable v1.2.3'), findsOneWidget);
    expect(find.text('Commit commit-abc'), findsOneWidget);
    expect(find.text('Tree tree-def'), findsOneWidget);
    expect(find.text('Publisher verified'), findsOneWidget);
    expect(find.text('Medium risk'), findsOneWidget);
    expect(
      find.textContaining('does not certify artifact safety'),
      findsOneWidget,
    );
    expect(find.text('User Scope / codex · v1.2.3'), findsOneWidget);

    await tester.tap(find.text('references/guide.md'));
    await tester.pumpAndSettle();
    expect(find.text('Supporting guide'), findsOneWidget);
    await tester.tap(find.text('Manifest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('name: flutter-pro'), findsOneWidget);
  });

  testWidgets('artifact detail failure is localized and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      detailErrors: const [
        SkillsException(
          'raw artifact diagnostic',
          kind: SkillsFailureKind.artifactUnavailable,
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Artifact unavailable'), findsOneWidget);
    expect(find.text('raw artifact diagnostic'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Real instructions'), findsOneWidget);
    expect(gateway.detailLoads, 2);
  });

  testWidgets('detail exposes a localized loading state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final detail = Completer<SkillDetail>();
    final gateway = FakeSkillsGateway(
      installed: false,
      detailCompleter: detail,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Loading auditable Skill detail'), findsOneWidget);
    detail.complete(FakeSkillsGateway.defaultRemoteDetail);
    await tester.pumpAndSettle();
    expect(find.text('Real instructions'), findsOneWidget);
  });

  testWidgets(
    'Discover stays usable and explains an empty Agent target matrix',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway(installed: false, agentNames: const []);
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();

      expect(find.text('No installed Agents detected'), findsOneWidget);
      expect(
        find.textContaining('there is no installation target yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets('detail Back restores query, scroll position and card focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      searchResults: List.generate(
        30,
        (index) => SkillSummary(
          id: 'example/skills/skill-$index',
          skillId: 'skill-$index',
          name: 'Skill $index',
          source: 'example/skills',
          installs: index,
        ),
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'preserve me');
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
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(find.text('Skill 20'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back to search'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(_searchInput()).controller.text,
      'preserve me',
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(before, 0.1),
    );
    expect(find.text('Skill 20'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'skill-card-example/skills/skill-20',
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
    expect(find.textContaining('empty collection'), findsOneWidget);
  });

  for (final failure in const {
    SkillsFailureKind.validation: 'Check this request',
    SkillsFailureKind.server: 'Registry unavailable',
    SkillsFailureKind.timeout: 'Registry timed out',
    SkillsFailureKind.offline: 'You’re offline',
    SkillsFailureKind.invalidResponse: 'Registry response unsupported',
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
    });
  }

  testWidgets('nested rails keep each destination subroute and input state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);

    await tester.enterText(_searchInput(), 'stateful');
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('User Scope'), findsOneWidget);
    expect(find.text('Add Project'), findsOneWidget);
    expect(find.text('Codex'), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('General'), findsWidgets);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Registry'), findsOneWidget);
    expect(find.text('Installation Policy'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    await tester.tap(find.text('Registry'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('All-time ranking'), findsWidgets);
    expect(_isSemanticallySelected(tester, 'Ranking'), isTrue);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(_isSemanticallySelected(tester, 'Codex'), isTrue);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(_isSemanticallySelected(tester, 'Registry'), isTrue);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(_searchInput()).controller.text,
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

      await tester.enterText(_searchInput(), 'async');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      search.complete(gateway.searchResults);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Pro'), findsOneWidget);
      expect(
        tester.widget<EditableText>(_searchInput()).controller.text,
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

    await tester.enterText(_searchInput(), 'install');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install for Codex'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back to search'));
    await tester.pumpAndSettle();

    install.complete(_success(['skillsgo', 'add']));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Command completed'), findsOneWidget);
  });

  testWidgets('Discover restores its collection scroll position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      searchResults: List.generate(
        30,
        (index) => SkillSummary(
          id: 'example/skills/skill-$index',
          skillId: 'skill-$index',
          name: 'Skill $index',
          source: 'example/skills',
          installs: index,
        ),
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(_searchInput(), 'many');
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

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    expect(find.text('Skill 20'), findsOneWidget);
  });

  testWidgets('rails expose selected semantics and full dynamic labels', (
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

    final searchSemantics = find.bySemanticsLabel('Search');
    final searchNodes = List.generate(
      searchSemantics.evaluate().length,
      (index) => tester.getSemantics(searchSemantics.at(index)),
    );
    expect(searchNodes.any((node) => node.flagsCollection.isButton), isTrue);
    expect(
      searchNodes.any(
        (node) => node.flagsCollection.isSelected == Tristate.isTrue,
      ),
      isTrue,
    );

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.byTooltip(longAgent), findsOneWidget);

    final indicator = tester.widget<Positioned>(
      find.byKey(const Key('rail-indicator')),
    );
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(const Key('rail-indicator')),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(indicator.top, 2);
    expect(decoration.color, Colors.white);
  });

  testWidgets('an overflowing Agent rail scrolls independently', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 520));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          agentNames: List.generate(20, (index) => 'agent-$index'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Agent 19'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('side-rail-scroll')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text('Agent 19').hitTestable(), findsOneWidget);
    expect(find.text('Your Library').hitTestable(), findsOneWidget);
  });

  testWidgets('Library falls back to All when its selected Agent disappears', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final agents = <String>['codex'];
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(agentNames: agents)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(_isSemanticallySelected(tester, 'Codex'), isTrue);

    agents.clear();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsNothing);
    expect(_isSemanticallySelected(tester, 'All'), isTrue);
  });

  testWidgets('Library lists a detected Agent with zero installed Skills', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          agentNames: const ['codex'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('Your Library is empty'), findsOneWidget);
  });

  testWidgets('the selected rail capsule follows spring motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ranking'));
    await tester.pump(const Duration(milliseconds: 16));
    final moving = tester.widget<Positioned>(
      find.byKey(const Key('rail-indicator')),
    );
    expect(moving.top, isNot(46));

    await tester.pumpAndSettle();
    final settled = tester.widget<Positioned>(
      find.byKey(const Key('rail-indicator')),
    );
    expect(settled.top, closeTo(46, .01));
  });

  testWidgets('reduced motion moves the selected rail capsule immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ranking'));
    await tester.pump();

    final indicator = tester.widget<Positioned>(
      find.byKey(const Key('rail-indicator')),
    );
    expect(indicator.top, 46);
    final rankingSemantics = find.bySemanticsLabel('Ranking');
    expect(
      List.generate(
        rankingSemantics.evaluate().length,
        (index) => tester.getSemantics(rankingSemantics.at(index)),
      ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue),
      isTrue,
    );
  });

  testWidgets('keyboard focus can activate the next rail destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final searchButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Search'),
    );
    searchButton.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('All-time ranking'), findsWidgets);
  });

  testWidgets('Settings shows a missing CLI and accepts a custom path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(cliReady: false);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('cli-path')),
        matching: find.byType(EditableText),
      ),
      '/custom/skills',
    );
    await tester.tap(find.text('Save & detect'));
    await tester.pumpAndSettle();

    expect(gateway.savedPath, '/custom/skills');
  });

  testWidgets('Settings routes expose distinct operational content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Desktop preferences'), findsOneWidget);
    await tester.tap(find.text('Registry'));
    await tester.pumpAndSettle();
    expect(find.text('Registry Origin'), findsOneWidget);
    expect(find.text('Desktop preferences'), findsNothing);

    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();
    expect(find.text('/Users/test/.skillsgo/store'), findsOneWidget);
    expect(find.text('Readable'), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('App version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('Bundled CLI version'), findsOneWidget);
    expect(find.text('Compatible'), findsOneWidget);
  });

  testWidgets('Agents settings separates detected and supported Agents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final gateway = FakeSkillsGateway(
      agentStatuses: const [
        AgentStatus(
          id: 'codex',
          displayName: 'Codex',
          installed: true,
          supportedScopes: [InstallationScope.project, InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.codex/skills',
            exists: true,
          ),
        ),
        AgentStatus(
          id: 'cursor',
          displayName: 'Cursor',
          installed: false,
          supportedScopes: [InstallationScope.project, InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.cursor/skills',
            exists: false,
          ),
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('1 installed · 2 supported'), findsOneWidget);
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Cursor'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Supported'), findsOneWidget);
    expect(find.textContaining('/Users/test/.codex/skills'), findsOneWidget);
  });

  testWidgets('Agent inspection failure keeps detection retry actionable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      agentInspectionError: const SkillsException('malformed agents'),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(
      find.text('Agent detection data is unavailable. Run detection again.'),
      findsOneWidget,
    );
    expect(find.text('Detect again'), findsOneWidget);
    final inspectionsBeforeRetry = gateway.agentInspections;
    await tester.tap(find.text('Detect again'));
    await tester.pumpAndSettle();
    expect(gateway.agentInspections, inspectionsBeforeRetry + 1);
  });

  testWidgets('About distinguishes a missing CLI from incompatibility', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(cliReady: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget);
    expect(find.text('INCOMPATIBLE'), findsNothing);
    expect(
      find.textContaining('bundled SkillsGo CLI is missing'),
      findsWidgets,
    );
  });

  testWidgets('Registry Origin can be tested, saved, and reset immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registry'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('registry-origin')),
        matching: find.byType(EditableText),
      ),
      'https://self-hosted.example',
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection ready'), findsOneWidget);

    await tester.tap(find.text('Save Origin'));
    await tester.pumpAndSettle();
    expect(gateway.registryOrigin, 'https://self-hosted.example');

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(gateway.registryOrigin, 'https://registry.skillsgo.dev');
  });

  testWidgets('a Registry Origin is not saved when its protocol test fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(registryTestState: HealthState.invalid);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registry'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('registry-origin')),
        matching: find.byType(EditableText),
      ),
      'https://incompatible.example',
    );
    await tester.tap(find.text('Save Origin'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('did not return the SkillsGo Registry'),
      findsOneWidget,
    );
    expect(gateway.registryOrigin, 'https://registry.skillsgo.dev');
  });

  testWidgets(
    'Critical-risk override persists while High confirmation stays required',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway();
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Installation Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Require confirmation for High risk'), findsOneWidget);
      await tester.tap(find.byKey(const Key('critical-risk-override')));
      await tester.pumpAndSettle();

      expect(gateway.riskPolicy.confirmHighRisk, isTrue);
      expect(gateway.riskPolicy.allowCriticalOverride, isTrue);
    },
  );

  testWidgets('Library exposes update state after an explicit check', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('local-skill'), findsOneWidget);
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE'), findsOneWidget);
  });

  testWidgets('core flow searches, installs, checks updates and removes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(installed: false);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('--agent codex --yes'), findsOneWidget);

    await tester.tap(find.text('Install for Codex'));
    await tester.pumpAndSettle();
    expect(find.text('Command completed'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back to search'));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);

    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove local-skill'));
    await tester.pumpAndSettle();
    expect(find.text('Remove local-skill?'), findsOneWidget);
    await tester.tap(find.text('Remove Skill'));
    await tester.pumpAndSettle();
    expect(find.text('Your Library is empty'), findsOneWidget);
  });
}

class FakeSkillsGateway implements SkillsGateway {
  FakeSkillsGateway({
    this.cliReady = true,
    this.installed = true,
    this.searchCompleter,
    this.installCompleter,
    List<SkillSummary>? searchResults,
    this.agentNames = const ['codex'],
    this.agentStatuses,
    this.agentInspectionError,
    this.registryOrigin = 'https://registry.skillsgo.dev',
    this.registryTestState = HealthState.ready,
    this.storageStatus = const StorageStatus(
      path: '/Users/test/.skillsgo/store',
      state: HealthState.ready,
    ),
    this.appVersion = '1.0.0',
    this.discoveryPages = const {},
    this.discoveryError,
    this.discoveryErrors = const {},
    this.detailCompleter,
    SkillDetail? remoteDetail,
    List<SkillsException> detailErrors = const [],
  }) : searchResults = searchResults ?? _defaultSearchResults,
       remoteDetail = remoteDetail ?? defaultRemoteDetail,
       detailErrors = List.of(detailErrors);
  final bool cliReady;
  final Completer<List<SkillSummary>>? searchCompleter;
  final Completer<CommandResult>? installCompleter;
  final Completer<SkillDetail>? detailCompleter;
  final List<String> agentNames;
  final List<AgentStatus>? agentStatuses;
  final SkillsException? agentInspectionError;
  String registryOrigin;
  final HealthState registryTestState;
  PersonalRiskPolicy riskPolicy = const PersonalRiskPolicy();
  final StorageStatus storageStatus;
  final String appVersion;
  final Map<String, DiscoveryPage> discoveryPages;
  final SkillsException? discoveryError;
  final Map<String, SkillsException> discoveryErrors;
  final SkillDetail remoteDetail;
  final List<SkillsException> detailErrors;
  bool installed;
  final queries = <String>[];
  final collections = <DiscoveryCollection>[];
  final requestedOffsets = <int>[];
  int installCalls = 0;
  int detailLoads = 0;
  int agentInspections = 0;
  String? savedPath;
  static const _defaultSearchResults = [
    SkillSummary(
      id: 'example/skills/flutter-pro',
      skillId: 'flutter-pro',
      name: 'Flutter Pro',
      source: 'example/skills',
      installs: 1200,
      description: 'Build Flutter products with reliable engineering flows.',
    ),
  ];
  static const defaultRemoteDetail = SkillDetail(
    name: 'Flutter Pro',
    source: 'example/skills',
    description: 'Build reliable Flutter products.',
    markdown: '# Real instructions',
    manifest:
        'name: flutter-pro\ndescription: Build reliable Flutter products.',
    requestedVersion: 'main',
    immutableVersion: 'v1.2.3',
    commitSHA: 'commit-abc',
    treeSHA: 'tree-def',
    contentDigest: 'sha256:content-digest',
    trustLevel: SkillTrustLevel.publisherVerified,
    riskAssessment: SkillRiskAssessment.medium,
    riskScannerVersion: 'file-signals/v1',
    riskEvidence: [
      SkillRiskEvidence(code: 'script_file', path: 'scripts/run.sh'),
    ],
    registryExecutableSignal: true,
    files: [
      SkillFile(
        path: 'SKILL.md',
        contents: '# Real instructions',
        kind: 'instructions',
      ),
      SkillFile(path: 'references/guide.md', contents: '# Supporting guide'),
      SkillFile(
        path: 'scripts/run.sh',
        contents: 'echo test',
        kind: 'script',
        executable: true,
      ),
    ],
    installationTargets: [
      SkillInstallationTarget(
        agent: 'codex',
        scope: InstallationScope.user,
        path: '/tmp/flutter-pro',
        version: 'v1.2.3',
      ),
    ],
  );
  final List<SkillSummary> searchResults;

  @override
  Future<CliStatus> detectCli({String? customPath}) async => cliReady
      ? CliStatus(
          availability: CliAvailability.ready,
          path: customPath?.isNotEmpty == true
              ? customPath
              : '/usr/local/bin/skills',
          version: '1.5.17',
        )
      : const CliStatus(
          availability: CliAvailability.missing,
          message: 'raw process diagnostic',
          issue: CliIssue.missing,
        );

  @override
  Future<String?> loadCustomCliPath() async => savedPath;
  @override
  Future<void> saveCustomCliPath(String? path) async => savedPath = path;
  @override
  Future<String> loadRegistryOrigin() async => registryOrigin;
  @override
  Future<void> saveRegistryOrigin(String origin) async {
    registryOrigin = origin;
  }

  @override
  Future<void> resetRegistryOrigin() async {
    registryOrigin = 'https://registry.skillsgo.dev';
  }

  @override
  Future<RegistryStatus> testRegistryOrigin(String origin) async =>
      RegistryStatus(
        origin: origin,
        state: registryTestState,
        issue: registryTestState == HealthState.ready
            ? null
            : RegistryIssue.invalidProtocol,
      );

  @override
  Future<PersonalRiskPolicy> loadRiskPolicy() async => riskPolicy;
  @override
  Future<void> saveRiskPolicy(PersonalRiskPolicy policy) async {
    riskPolicy = policy;
  }

  @override
  Future<StorageStatus> inspectStorage() async => storageStatus;
  @override
  Future<String> loadAppVersion() async => appVersion;
  @override
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    collections.add(collection);
    requestedOffsets.add(offset);
    if (discoveryError != null) throw discoveryError!;
    final configuredError = discoveryErrors['${collection.name}:$offset'];
    if (configuredError != null) throw configuredError;
    final configured = discoveryPages['${collection.name}:$offset'];
    if (configured != null) return configured;
    if (collection == DiscoveryCollection.search) queries.add(query);
    final skills = collection == DiscoveryCollection.search
        ? await (searchCompleter?.future ?? Future.value(searchResults))
        : searchResults;
    return DiscoveryPage(skills: skills);
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async {
    detailLoads++;
    if (detailErrors.isNotEmpty) throw detailErrors.removeAt(0);
    return detailCompleter?.future ?? remoteDetail;
  }

  @override
  Future<List<InstalledSkill>> listInstalled() async => installed
      ? [
          InstalledSkill(
            name: 'local-skill',
            path: '/tmp/local-skill',
            agents: agentNames,
            targetCount: agentNames.length,
          ),
        ]
      : const [];
  @override
  Future<AgentCatalog> inspectAgents() async {
    agentInspections++;
    if (agentInspectionError != null) throw agentInspectionError!;
    return AgentCatalog(
      schemaVersion: 1,
      agents:
          agentStatuses ??
          agentNames
              .map(
                (agent) => AgentStatus(
                  id: agent,
                  displayName: agent
                      .split(RegExp(r'[-_]'))
                      .where((part) => part.isNotEmpty)
                      .map(
                        (part) =>
                            '${part[0].toUpperCase()}${part.substring(1)}',
                      )
                      .join(' '),
                  installed: true,
                  supportedScopes: const [
                    InstallationScope.project,
                    InstallationScope.user,
                  ],
                  userTarget: AgentUserTarget(
                    path: '/Users/test/.$agent/skills',
                    exists: true,
                  ),
                ),
              )
              .toList(growable: false),
    );
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async =>
      const SkillDetail(
        name: 'local-skill',
        source: 'Local',
        markdown: '# Local',
        files: [SkillFile(path: 'SKILL.md', contents: '# Local')],
      );
  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async => {'local-skill': UpdateState.available};
  @override
  Future<CommandResult> install(SkillSummary skill) async {
    installCalls++;
    if (installCompleter != null) {
      final result = await installCompleter!.future;
      installed = result.succeeded;
      return result;
    }
    installed = true;
    return _success(['skills', 'add']);
  }

  @override
  Future<CommandResult> remove(InstalledSkill skill) async {
    installed = false;
    return _success(['skills', 'remove']);
  }

  @override
  Future<CommandResult> update(InstalledSkill skill) async =>
      _success(['skills', 'update']);
}

CommandResult _success(List<String> command) => CommandResult(
  command: command,
  output: const ProcessOutput(exitCode: 0, stdout: 'ok', stderr: ''),
);

Finder _searchInput() => find.descendant(
  of: find.byKey(const Key('skill-search')),
  matching: find.byType(EditableText),
);

bool _isSemanticallySelected(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  return List.generate(
    finder.evaluate().length,
    (index) => tester.getSemantics(finder.at(index)),
  ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue);
}
