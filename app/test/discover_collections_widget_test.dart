/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Discover search, source collections, leaderboard layout, pagination, and refresh behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_labs/portal_labs.dart' as portal;
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets(
    'a completed request never writes through a disposed Discover provider',
    (tester) async {
      final pending = Completer<DiscoveryPage>();
      final gateway = FakeSkillsGateway(discoveryCompleters: [pending]);
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pump();
      expect(gateway.collections, isNotEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(const DiscoveryPage(skills: []));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('starts in Discover and searches through the gateway', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discover-results-hot')), findsOneWidget);
    expect(isSemanticallySelected(tester, 'Hot'), isTrue);
    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(gateway.queries, ['flutter']);
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
  });

  testWidgets('a Git link keeps current Skill cards inside source context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      discoveryPages: {
        'search:0': DiscoveryPage(
          skills: defaultSearchResults,
          repository: RepositorySummary(
            id: 'github.com/example/skills',
            description: 'A focused collection of Flutter engineering skills.',
            stars: 12800,
            latestVersion: 'v1.2.3',
            updatedAt: DateTime.utc(2026, 7, 15),
            license: 'MIT',
          ),
        ),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'https://github.com/example/skills');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-source-context')), findsOneWidget);
    expect(find.text('example / skills'), findsOneWidget);
    expect(
      find.text('A focused collection of Flutter engineering skills.'),
      findsOneWidget,
    );
    expect(find.text('★ 12.8K'), findsOneWidget);
    expect(find.text('MIT'), findsOneWidget);
    expect(find.text('v1.2.3'), findsOneWidget);
    expect(find.text('1 skill'), findsOneWidget);
    expect(find.text('Install all skills'), findsOneWidget);
    final installAll = tester.widget<PrimaryCapsuleButton>(
      find.byKey(const Key('repository-install-all')),
    );
    expect(installAll.height, 40);
    expect(installAll.horizontalPadding, 18);
    expect(installAll.labelStyle?.fontSize, 15);
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.byType(SkillCard), findsWidgets);

    final postInstallRefresh = Completer<DiscoveryPage>();
    gateway.discoveryCompleters.add(postInstallRefresh);

    await tester.tap(find.byKey(const Key('repository-install-all')));
    await tester.pumpAndSettle();
    expect(find.text('Install all skills to'), findsOneWidget);
    expect(find.text('Install all skills'), findsNWidgets(2));
    expect(find.text('Confirm installation'), findsNothing);
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Install all skills').last,
    );
    await tester.pump();
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.byType(SkillCard), findsWidgets);
    expect(find.byKey(const ValueKey('discover-skeleton')), findsNothing);
    postInstallRefresh.complete(
      const DiscoveryPage(skills: defaultSearchResults),
    );
    await tester.pumpAndSettle();
    expect(gateway.installCalls, 1);
    expect(find.text('Install all skills to'), findsNothing);
  });

  testWidgets('a Git Repository cold load uses themed Portal Loading Shapes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final pendingSearch = Completer<List<SkillSummary>>();
    final gateway = FakeSkillsGateway(searchCompleter: pendingSearch);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'https://github.com/example/skills');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('discover-repository-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('discover-skeleton')), findsNothing);
    expect(find.text('Parsing Repository…'), findsOneWidget);
    final loading = tester.widget<portal.LoadingShapes>(
      find.byKey(const Key('portal-repository-loading-shape')),
    );
    expect(loading.style.size, 56);
    expect(
      loading.style.color,
      Theme.of(tester.element(searchInput())).colorScheme.primary,
    );
    expect(loading.style.transitionDuration, const Duration(milliseconds: 800));
    expect(loading.style.enableHaptics, isFalse);
    expect(loading.style.shapes, hasLength(7));

    pendingSearch.complete(defaultSearchResults);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discover-repository-loading')),
      findsNothing,
    );
    expect(find.byType(SkillCard), findsWidgets);
  });

  testWidgets('an uncataloged Git link has a dedicated next-step state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(searchResults: const []);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(
      searchInput(),
      'gitlab.example.com/group/subgroup/skills',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('This link is ready to inspect'), findsOneWidget);
    expect(
      find.text(
        'gitlab.example.com/group/subgroup/skills is not in the current '
        'search results. SkillsGo can inspect the link directly in the next '
        'step.',
      ),
      findsOneWidget,
    );
    expect(find.text('View skills in this link'), findsOneWidget);
    expect(find.text('No skills found'), findsNothing);
  });

  testWidgets('clearing native Discover search returns to Hot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(searchInput()).controller.text, isEmpty);
    expect(find.byKey(const ValueKey('discover-results-hot')), findsOneWidget);
    expect(isSemanticallySelected(tester, 'Hot'), isTrue);
  });

  testWidgets(
    'Discover collection controls collapse for query mode and reverse on clear',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('skill-search-input'));
      final controls = find.byKey(
        const Key('discover-leaderboard-tabs-motion'),
      );
      final restingY = tester.getTopLeft(search).dy;
      final restingHeight = tester.getSize(controls).height;
      await tester.enterText(searchInput(), 'flutter');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final enteringHeight = tester.getSize(controls).height;
      expect(tester.getTopLeft(search).dy, restingY);
      expect(enteringHeight, lessThan(restingHeight));

      await tester.pumpAndSettle();
      final queryHeight = tester.getSize(controls).height;
      expect(queryHeight, 0);
      await tester.tap(find.byKey(const Key('skill-search-clear')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final clearingHeight = tester.getSize(controls).height;
      expect(clearingHeight, greaterThan(queryHeight));
      expect(clearingHeight, lessThan(restingHeight));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(search).dy, restingY);
      expect(tester.getSize(controls).height, restingHeight);
      expect(FocusManager.instance.primaryFocus, isNotNull);
    },
  );

  testWidgets('Discover keeps search in the collection rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('skill-search-input')), findsOneWidget);
    expect(find.byKey(const Key('discovery-options-mode')), findsOneWidget);
    expect(find.text('⌘ F'), findsOneWidget);
    expect(find.byKey(const Key('discovery-search-close')), findsNothing);
    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.byKey(const Key('skill-search-input')), findsOneWidget);
  });

  testWidgets('Discover rail exposes all collection options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final tabs = find.byKey(const Key('discovery-options-mode'));
    expect(tabs, findsOneWidget);
    expect(
      find.descendant(of: tabs, matching: find.bySemanticsLabel('Hot')),
      findsWidgets,
    );
    expect(
      find.descendant(of: tabs, matching: find.bySemanticsLabel('Trending')),
      findsWidgets,
    );
    expect(
      find.descendant(of: tabs, matching: find.bySemanticsLabel('Ranking')),
      findsWidgets,
    );
    expect(isSemanticallySelected(tester, 'Hot'), isTrue);
  });

  testWidgets('all Discover collections show compact card metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const base = SkillSummary(
      id: 'github.com/acme/skills/-/planner',
      installName: 'planner',
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
              installName: 'planner',
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
              installName: 'planner',
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
    expect(find.text('acme/skills'), findsOneWidget);
    expect(find.text('v1.2.3'), findsNothing);
    expect(find.text('Community verified'), findsNothing);
    expect(find.text('Low risk'), findsNothing);
    expect(find.text('Installed'), findsOneWidget);
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

  testWidgets('Discover leaderboard header stays fixed while results scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      discoveryPages: {
        'ranking:0': DiscoveryPage(
          skills: List.generate(
            24,
            (index) => SkillSummary(
              id: 'example/skills/ranked-$index',
              installName: 'ranked-$index',
              name: 'Ranked $index',
              source: 'example/skills',
              installs: 24 - index,
            ),
          ),
        ),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('It’s nice to know a little more.'), findsNothing);
    expect(find.byKey(const Key('skill-search-input')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('discover-results-ranking')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('skill-search-input')), findsOneWidget);
    expect(find.text('Ranked 6'), findsOneWidget);
  });

  testWidgets('Discover and Library begin on the same toolbar row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final discoverSearch = find.byKey(const Key('skill-search-input'));
    final discoverOrigin = tester.getTopLeft(discoverSearch);
    expect(find.text('It’s nice to know a little more.'), findsNothing);

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    final librarySearch = find.byKey(const Key('library-search'));
    final libraryOrigin = tester.getTopLeft(librarySearch);
    expect(find.text('What you know is all here.'), findsNothing);
    expect(libraryOrigin.dy, discoverOrigin.dy);
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
              installName: 'a',
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
              installName: 'b',
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
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    expect(gateway.requestedOffsets, [0, 0, 20]);
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
              installName: 'a',
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

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining('did not respond in time'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('raw'), findsNothing);
  });
}
