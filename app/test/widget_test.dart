/*
 * [INPUT]: Uses SkillsPlayApp with a controllable SkillsGateway fake plus locale, motion, focus, and keyboard settings.
 * [OUTPUT]: Specifies startup, persistent nested navigation, accessibility, discovery, settings, and mutation journeys.
 * [POS]: Serves as the highest App behavior suite at the rendered desktop interface seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsplay/app.dart';
import 'package:skillsplay/domain/skills_gateway.dart';

void main() {
  testWidgets('follows the system locale and renders Simplified Chinese', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.text('发现'), findsOneWidget);
    expect(find.text('技能库'), findsOneWidget);
    expect(find.text('找到下一步所需的技能。'), findsOneWidget);
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
      SkillsPlayApp(gateway: FakeSkillsGateway(cliReady: false)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('内置的 SkillsGo CLI 缺失或无法运行。请重新安装 SkillsPlay。'),
      findsOneWidget,
    );
    expect(find.text('raw process diagnostic'), findsNothing);
  });

  testWidgets('starts in Discover and searches through the gateway', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Find a skill for your next move.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('skill-search')), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(gateway.queries, ['flutter']);
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
  });

  testWidgets('nested rails keep each destination subroute and input state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('skill-search')), 'stateful');
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
      tester
          .widget<TextField>(find.byKey(const Key('skill-search')))
          .controller!
          .text,
      'stateful',
    );
  });

  testWidgets(
    'a Discover request completes while another destination is open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final search = Completer<List<SkillSummary>>();
      final gateway = FakeSkillsGateway(searchCompleter: search);
      await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('skill-search')), 'async');
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
        tester
            .widget<TextField>(find.byKey(const Key('skill-search')))
            .controller!
            .text,
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('skill-search')), 'install');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install for Codex'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back to search'));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('skill-search')), 'many');
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
      SkillsPlayApp(
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
      SkillsPlayApp(
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
      SkillsPlayApp(gateway: FakeSkillsGateway(agentNames: agents)),
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

  testWidgets('the selected rail capsule follows spring motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
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

  testWidgets('About distinguishes a missing CLI from incompatibility', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsPlayApp(gateway: FakeSkillsGateway(cliReady: false)),
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
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
      await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
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
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('skill-search')), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('--agent codex --yes'), findsOneWidget);

    await tester.tap(find.text('Install for Codex'));
    await tester.pumpAndSettle();
    expect(find.text('Command completed'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to search'));
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
    this.registryOrigin = 'https://registry.skillsgo.dev',
    this.registryTestState = HealthState.ready,
    this.storageStatus = const StorageStatus(
      path: '/Users/test/.skillsgo/store',
      state: HealthState.ready,
    ),
    this.appVersion = '1.0.0',
  }) : searchResults = searchResults ?? _defaultSearchResults;
  final bool cliReady;
  final Completer<List<SkillSummary>>? searchCompleter;
  final Completer<CommandResult>? installCompleter;
  final List<String> agentNames;
  String registryOrigin;
  final HealthState registryTestState;
  PersonalRiskPolicy riskPolicy = const PersonalRiskPolicy();
  final StorageStatus storageStatus;
  final String appVersion;
  bool installed;
  final queries = <String>[];
  String? savedPath;
  static const _defaultSearchResults = [
    SkillSummary(
      id: 'example/skills/flutter-pro',
      skillId: 'flutter-pro',
      name: 'Flutter Pro',
      source: 'example/skills',
      installs: 1200,
    ),
  ];
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
  Future<List<SkillSummary>> search(String query) async {
    queries.add(query);
    return searchCompleter?.future ?? searchResults;
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async =>
      const SkillDetail(
        name: 'Flutter Pro',
        source: 'example/skills',
        markdown: '# Flutter Pro',
        files: [SkillFile(path: 'SKILL.md', contents: '# Flutter Pro')],
      );
  @override
  Future<List<InstalledSkill>> listInstalled() async => installed
      ? [
          InstalledSkill(
            name: 'local-skill',
            path: '/tmp/local-skill',
            agents: agentNames,
          ),
        ]
      : const [];
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

bool _isSemanticallySelected(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  return List.generate(
    finder.evaluate().length,
    (index) => tester.getSemantics(finder.at(index)),
  ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue);
}
