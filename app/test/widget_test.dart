/*
 * [INPUT]: Uses SkillsGoApp, the vendored named-preset Bloom color picker, and a controllable SkillsGateway fake plus locale, motion, focus, and keyboard settings.
 * [OUTPUT]: Specifies startup, persistent primary folder navigation, opaque directional discovery/detail transitions, detail product metadata, discovery/detail recovery, outage-resilient Hub/Local/External Library views, projects, Agents, Settings, anchored installation-location selection, Installation/Update/Target Management/External Adoption journeys, offline retry, Local install-more/export, exact-target recovery, focus, accessibility, and mutations.
 * [POS]: Serves as the highest App behavior suite at the rendered desktop interface seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui'
    show CheckedState, PointerDeviceKind, SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skillsgo/ui/bloom_color_picker/bloom_color_picker.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand_theme_presets.dart';
import 'package:skillsgo/ui/native_components.dart';
import 'package:skillsgo/ui/primary_folder_shell.dart';

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
    expect(find.text('已安装'), findsOneWidget);
    expect(find.text('当前热门'), findsWidgets);

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

  testWidgets('primary Folder persists across every primary destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final folder = find.byKey(const Key('primary-folder-shell'));
    expect(folder, findsOneWidget);

    for (final destination in const {
      'discover': 'Discover',
      'library': 'Library',
      'settings': 'Settings',
    }.entries) {
      await tester.tap(
        find.byKey(Key('primary-destination-${destination.key}')),
      );
      await tester.pumpAndSettle();

      expect(folder, findsOneWidget);
      expect(_isSemanticallySelected(tester, destination.value), isTrue);
    }
  });

  testWidgets('General settings changes and persists the Folder theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final picker = tester.widget<BloomColorPicker>(
      find.byType(BloomColorPicker),
    );
    expect(picker.presets, hasLength(18));
    expect(picker.presets, same(brandThemePresets));
    expect(picker.presets.first.name, 'GitHub');
    expect(picker.presets.first.color, const Color(0xFF181717));
    expect(picker.presets.last.name, 'Figma');
    expect(picker.presets.last.color, const Color(0xFFF24E1E));
    picker.onColorChanged(const Color(0xFF3D5141));
    await tester.pumpAndSettle();

    expect(gateway.folderTheme, '#3D5141');
  });

  testWidgets('Appearance switches between system, light, and dark modes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(_shellBrightness(tester), Brightness.dark);
    expect(gateway.themeMode, AppThemeMode.system);

    await tester.tap(find.byKey(const ValueKey('discrete-tab-Light')));
    await tester.pumpAndSettle();
    expect(gateway.themeMode, AppThemeMode.light);
    expect(_shellBrightness(tester), Brightness.light);
    expect(find.text('Light'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discrete-tab-Dark')));
    await tester.pumpAndSettle();
    expect(gateway.themeMode, AppThemeMode.dark);
    expect(_shellBrightness(tester), Brightness.dark);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discrete-tab-System')));
    await tester.pumpAndSettle();
    expect(gateway.themeMode, AppThemeMode.system);
    expect(_shellBrightness(tester), Brightness.dark);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpAndSettle();
    expect(_shellBrightness(tester), Brightness.light);
  });

  testWidgets('Appearance restores a persisted explicit mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(themeMode: AppThemeMode.light)),
    );
    await tester.pumpAndSettle();

    expect(_shellBrightness(tester), Brightness.light);
  });

  testWidgets('Bloom presets reveal their brand name on hover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final picker = find.byType(BloomColorPicker);
    await tester.tap(
      find.descendant(of: picker, matching: find.byType(GestureDetector)).first,
    );
    await tester.pumpAndSettle();

    final githubPreset = find.byKey(const Key('bloom-preset-GitHub'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(githubPreset));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('Bloom center selects and persists white', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final picker = find.byType(BloomColorPicker);
    await tester.tap(
      find.descendant(of: picker, matching: find.byType(GestureDetector)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bloom-center-white')));
    await tester.pumpAndSettle();

    expect(gateway.folderTheme, '#FFFFFF');
  });

  testWidgets('a white seed keeps the folder surface and text readable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(folderTheme: '#FFFFFF')),
    );
    await tester.pumpAndSettle();

    final folderFinder = find.byWidgetPredicate(
      (widget) => widget is SkillsPrimaryFolder,
      description: 'SkillsPrimaryFolder',
    );
    final folder = tester.widget<SkillsPrimaryFolder<dynamic>>(folderFinder);
    final theme = Theme.of(
      tester.element(find.byKey(const Key('primary-folder-shell'))),
    );
    expect(folder.style.folderColor, theme.colorScheme.surfaceContainerHighest);
    expect(
      folder.style.activeTabColor,
      theme.colorScheme.surfaceContainerHighest,
    );
    expect(folder.style.inactiveTabColor, theme.colorScheme.surfaceContainer);
    expect(folder.style.activeLabelStyle.color, theme.colorScheme.onSurface);
    expect(
      _contrastRatio(folder.style.folderColor, theme.colorScheme.onSurface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('all supported seeds keep the desktop shell readable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final seeds = <Color>[
      Colors.black,
      Colors.white,
      ...brandThemePresets.map((preset) => preset.color),
    ];

    for (final seed in seeds) {
      final gateway = FakeSkillsGateway(
        folderTheme:
            '#${(seed.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final folder = tester.widget<SkillsPrimaryFolder<dynamic>>(
        find.byWidgetPredicate(
          (widget) => widget is SkillsPrimaryFolder,
          description: 'SkillsPrimaryFolder',
        ),
      );
      final theme = Theme.of(
        tester.element(find.byKey(const Key('primary-folder-shell'))),
      );
      expect(
        _contrastRatio(folder.style.folderColor, theme.colorScheme.onSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'seed ${gateway.folderTheme}',
      );
      expect(
        folder.style.activeTabColor,
        theme.colorScheme.surfaceContainerHighest,
      );
      expect(
        _contrastRatio(
          folder.style.activeTabColor,
          theme.colorScheme.onSurface,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'active tab for seed ${gateway.folderTheme}',
      );
    }
  });

  testWidgets('starts in Discover and searches through the gateway', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Hot right now'), findsWidgets);
    expect(_isSemanticallySelected(tester, 'Hot'), isTrue);
    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(gateway.queries, ['flutter']);
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
  });

  testWidgets('clearing native Discover search returns to Hot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-search-clear')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(_searchInput()).controller.text,
      isEmpty,
    );
    expect(find.text('Hot right now'), findsWidgets);
    expect(_isSemanticallySelected(tester, 'Hot'), isTrue);
  });

  testWidgets('submitted Discover query owns a persistent active style', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    TextField field() => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('skill-search')),
        matching: find.byType(TextField),
      ),
    );
    BoxDecoration surface() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('skill-search-surface')),
                )
                .decoration
            as BoxDecoration;

    final scheme = Theme.of(tester.element(_searchInput())).colorScheme;
    expect(field().decoration?.fillColor, scheme.primaryContainer);
    expect(field().style?.color, scheme.onPrimaryContainer);
    expect(surface().boxShadow, isNotEmpty);

    await tester.enterText(_searchInput(), 'flutter ui');
    await tester.pumpAndSettle();

    expect(field().decoration?.fillColor, scheme.surfaceContainerHigh);
    expect(field().style?.color, scheme.onSurface);
    expect(surface().boxShadow, isEmpty);
  });

  testWidgets('Discover collection icons share the designed Hugeicons spec', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final icons = tester.widgetList<HugeIcon>(find.byType(HugeIcon)).toList();
    expect(icons, hasLength(3));
    expect(icons.map((icon) => icon.size), everyElement(18));
    expect(icons.map((icon) => icon.strokeWidth), everyElement(1.8));
    expect(icons[0].icon, same(HugeIcons.strokeRoundedFire));
    expect(icons[1].icon, same(HugeIcons.strokeRoundedChampion));
    expect(icons[2].icon, same(HugeIcons.strokeRoundedChartLineData01));
  });

  testWidgets('all Discover collections show compact card metadata', (
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
    expect(find.text('acme/skills'), findsOneWidget);
    expect(find.text('v1.2.3'), findsNothing);
    expect(find.text('Community verified'), findsNothing);
    expect(find.text('Low risk'), findsNothing);
    expect(find.text('Install'), findsOneWidget);
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

  testWidgets('Discover title scrolls with its collection cards', (
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
              skillId: 'ranked-$index',
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

    expect(find.text('All-time ranking').hitTestable(), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('discover-results-ranking')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('All-time ranking').hitTestable(), findsNothing);
    expect(find.text('Ranked 6'), findsOneWidget);
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
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();

    expect(gateway.installCalls, 0);
    expect(find.text('Set installation location'), findsNothing);
    expect(find.text('Installed'), findsOneWidget);
    final installAction = find.widgetWithText(SkillsButton, 'Install');
    expect(tester.widget<SkillsButton>(installAction).enabled, isFalse);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'card and detail installation use the shared anchored location selector',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      const project = AddedProject(
        id: 'project-a',
        name: 'Project A',
        path: '/work/project-a',
        accessState: ProjectAccessState.accessible,
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        agentNames: const ['codex', 'claude-code'],
        addedProjects: const [project],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'location');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      final card = find.byType(SkillCard).first;
      await tester.tap(
        find.descendant(of: card, matching: find.text('Install')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set installation location'), findsNothing);
      expect(find.text('Install Flutter Pro to'), findsOneWidget);
      expect(find.text('All projects'), findsOneWidget);
      expect(find.text('Selected projects'), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Available to 2 Agents at user level'), findsOneWidget);
      await tester.tap(find.byType(Radio<InstallationScope>).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Project A'), findsOneWidget);
      expect(find.text('0 projects · 2 Agents'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-hero-install')));
      await tester.pumpAndSettle();
      expect(find.text('Set installation location'), findsNothing);
      expect(find.text('Available to 2 Agents at user level'), findsOneWidget);
    },
  );

  testWidgets('auditable detail exposes immutable evidence and files', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Real instructions'), findsOneWidget);
    expect(find.text('Immutable v1.2.3'), findsNothing);
    expect(find.text('Commit commit-abc'), findsNothing);
    expect(find.text('Tree tree-def'), findsNothing);
    expect(find.text('Publisher verified'), findsNothing);
    expect(find.text('Medium risk'), findsNothing);
    final detailAvatarSize = tester.getSize(
      find.byKey(const Key('detail-skill-avatar')),
    );
    expect(detailAvatarSize, const Size.square(116));
    expect(
      find.byKey(const Key('detail-description-markdown')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('detail-description-markdown')))
          .height,
      68,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-description-markdown')),
        matching: find.byType(Markdown),
      ),
      findsOneWidget,
    );
    expect(
      find.text(FakeSkillsGateway.defaultRemoteDetail.description),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-sticky-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('detail-scroll-view')), findsOneWidget);
    expect(find.byKey(const Key('detail-compact-identity')), findsNothing);
    expect(find.byKey(const Key('detail-hero-install')), findsOneWidget);
    expect(find.text('Installs'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
    expect(find.text('github.com/example/skills'), findsNothing);
    expect(find.text('12.8K'), findsOneWidget);
    expect(find.text('2026-07-15'), findsOneWidget);
    expect(find.text('24 KB'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-instructions')),
        matching: find.byType(MarkdownBody),
      ),
      findsOneWidget,
    );

    final detailScrollable = find.descendant(
      of: find.byKey(const Key('detail-scroll-view')),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(detailScrollable.first).position.jumpTo(180);
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-compact-identity')))
          .opacity,
      1,
    );
    expect(
      find.textContaining('does not certify artifact safety'),
      findsNothing,
    );
    expect(find.text('User Scope / codex · v1.2.3'), findsOneWidget);

    expect(find.text('Snapshot files'), findsNothing);
    expect(find.text('references/guide.md'), findsNothing);
    expect(find.text('Manifest'), findsNothing);
  });

  testWidgets('detail transition keeps the moving page opaque', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pump(const Duration(milliseconds: 80));

    final detailMotion = find.byKey(const ValueKey('discover-detail-motion'));
    expect(detailMotion, findsOneWidget);
    expect(find.byKey(const ValueKey('discover-list-motion')), findsOneWidget);
    expect(
      find.descendant(of: detailMotion, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: detailMotion, matching: find.byType(ColoredBox)),
      findsWidgets,
    );
  });

  testWidgets('remote detail inherits the selected App theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    const seed = Color(0xFF5865F2);
    final gateway = FakeSkillsGateway(
      folderTheme: '#5865F2',
      themeMode: AppThemeMode.dark,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(_searchInput(), 'theme');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    final detailTheme = Theme.of(
      tester.element(find.byKey(const Key('detail-instructions'))),
    );
    final expected = buildSkillsTheme(seed);
    expect(detailTheme.brightness, Brightness.dark);
    expect(detailTheme.colorScheme.primary, expected.colorScheme.primary);
    expect(detailTheme.colorScheme.surface, expected.colorScheme.surface);
  });

  testWidgets(
    'remote detail stays inside Discover and restores the originating list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
      await tester.pumpAndSettle();

      await tester.enterText(_searchInput(), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('primary-folder-shell')), findsOneWidget);
      expect(find.text('Hot'), findsOneWidget);
      expect(find.byKey(const Key('detail-instructions')), findsOneWidget);
      expect(_searchInput(), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail-instructions')), findsNothing);
      expect(find.text('Flutter Pro'), findsOneWidget);
      expect(
        tester.widget<EditableText>(_searchInput()).controller.text,
        'flutter',
      );
    },
  );

  testWidgets(
    'Installation Plan keeps explicit cells across row, column, and Add Project shortcuts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      const projectA = AddedProject(
        id: 'project-a',
        name: 'Project A',
        path: '/work/project-a',
        accessState: ProjectAccessState.accessible,
      );
      const projectB = AddedProject(
        id: 'project-b',
        name: 'Project B',
        path: '/work/project-b',
        accessState: ProjectAccessState.accessible,
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        agentNames: const ['codex', 'claude-code'],
        addedProjects: const [projectA],
        projectToAdd: projectB,
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'matrix');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      final codexShortcut = find.bySemanticsLabel(
        'Select all available targets for Codex',
      );
      var shortcutSemantics = tester.getSemantics(codexShortcut);
      expect(shortcutSemantics.flagsCollection.isChecked, CheckedState.isFalse);
      expect(
        shortcutSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(codexShortcut);
      await tester.pumpAndSettle();
      expect(find.text('2 targets selected'), findsOneWidget);
      shortcutSemantics = tester.getSemantics(codexShortcut);
      expect(shortcutSemantics.flagsCollection.isChecked, CheckedState.isTrue);

      await tester.tap(find.text('Add Project'));
      await tester.pumpAndSettle();
      expect(find.text('Project B'), findsOneWidget);
      expect(find.text('2 targets selected'), findsOneWidget);

      await tester.tap(find.text('Project B'));
      await tester.pumpAndSettle();
      expect(find.text('4 targets selected'), findsOneWidget);
      await tester.tap(find.text('Review 4 Targets'));
      await tester.pumpAndSettle();

      expect(
        gateway.lastPlanSelections
            .map(
              (selection) =>
                  '${selection.scope.name}:${selection.projectRoot}:${selection.agent}',
            )
            .toList(),
        [
          'user::codex',
          'project:/work/project-a:codex',
          'project:/work/project-b:codex',
          'project:/work/project-b:claude-code',
        ],
      );
      expect(find.text('4 create'), findsOneWidget);
      expect(find.text('/work/project-b'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Close installation plan'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Hub installation stays retryable and explains an offline preflight',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        installPlanErrors: const [
          SkillsException(
            'do not parse this diagnostic',
            kind: SkillsFailureKind.offline,
            isOffline: true,
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'offline install');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();
      expect(find.text('Installation plan could not continue'), findsOneWidget);
      expect(
        find.text(
          'SkillsGo could not reach the Hub. Check your network, proxy, or Hub Origin.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 targets selected'), findsOneWidget);

      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();
      expect(find.text('1 create'), findsOneWidget);
      expect(find.text('Install 1 Targets'), findsOneWidget);
    },
  );

  testWidgets(
    'Installation Plan requires an explicit Local Modification replacement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        planConflictReason: 'local-modification',
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'modified');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();

      expect(find.text('1 conflict'), findsOneWidget);
      expect(
        find.text('Discard Local Modifications and replace this target'),
        findsOneWidget,
      );
      expect(gateway.installCalls, 0);

      await tester.tap(
        find.text('Discard Local Modifications and replace this target'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Resolutions'));
      await tester.pumpAndSettle();
      expect(find.text('1 replace'), findsOneWidget);
      expect(
        gateway.lastPlanSelections.single.resolution,
        InstallationTargetResolution.replace,
      );
      expect(
        gateway.lastPlanSelections.single.expectedReason,
        'local-modification',
      );
      expect(
        gateway.lastPlanSelections.single.expectedState,
        'sha256:user-codex-local-modification',
      );
      await tester.tap(find.text('Install 1 Targets'));
      await tester.pumpAndSettle();
      expect(gateway.installCalls, 1);
    },
  );

  testWidgets(
    'shared target conflicts require every affected Agent in the matrix',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        planConflictReason: 'shared-target-conflict',
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'shared');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();

      expect(
        find.text('This path is shared by other Agent targets'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Return to the target matrix and select every affected Agent before replacing: codex, claude-code',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Discard Local Modifications'), findsNothing);
      final applyButton = find.ancestor(
        of: find.text('Apply Resolutions'),
        matching: find.byType(SkillsButton),
      );
      expect(tester.widget<SkillsButton>(applyButton).enabled, isFalse);
      expect(
        gateway.lastPlanSelections.single.resolution,
        InstallationTargetResolution.none,
      );
      expect(gateway.installCalls, 0);
    },
  );

  testWidgets('High risk requires a separate plan confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    final gateway = FakeSkillsGateway(
      installed: false,
      remoteDetail: _withoutInstallationTargets(
        FakeSkillsGateway.defaultRemoteDetail,
        riskAssessment: SkillRiskAssessment.high,
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'risky');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review 1 Targets'));
    await tester.pumpAndSettle();

    expect(find.text('1 risk blocked'), findsOneWidget);
    expect(find.text('High-risk artifact confirmation'), findsOneWidget);
    expect(gateway.installCalls, 0);
    await tester.tap(
      find.text(
        'I reviewed the artifact files and accept this risk for the selected targets',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Resolutions'));
    await tester.pumpAndSettle();
    expect(find.text('1 create'), findsOneWidget);
    await tester.tap(find.text('Install 1 Targets'));
    await tester.pumpAndSettle();
    expect(gateway.installCalls, 1);
  });

  testWidgets('Critical risk stays blocked when its Settings override is off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    final gateway = FakeSkillsGateway(
      installed: false,
      remoteDetail: _withoutInstallationTargets(
        FakeSkillsGateway.defaultRemoteDetail,
        riskAssessment: SkillRiskAssessment.critical,
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'critical');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review 1 Targets'));
    await tester.pumpAndSettle();

    expect(find.text('Critical-risk installation is blocked'), findsOneWidget);
    expect(
      find.textContaining('Enable the explicit Critical-risk override'),
      findsOneWidget,
    );
    expect(
      find.text(
        'I reviewed the artifact files and accept this risk for the selected targets',
      ),
      findsNothing,
    );
    expect(gateway.installCalls, 0);
  });

  testWidgets(
    'Critical risk requires per-install confirmation after Settings override',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        riskPolicy: const PersonalRiskPolicy(allowCriticalOverride: true),
        remoteDetail: _withoutInstallationTargets(
          FakeSkillsGateway.defaultRemoteDetail,
          riskAssessment: SkillRiskAssessment.critical,
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'critical');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();

      expect(find.text('Critical-risk override confirmation'), findsOneWidget);
      expect(gateway.installCalls, 0);
      await tester.tap(
        find.text(
          'I reviewed the artifact files and accept this risk for the selected targets',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Resolutions'));
      await tester.pumpAndSettle();
      expect(find.text('1 create'), findsOneWidget);
      await tester.tap(find.text('Install 1 Targets'));
      await tester.pumpAndSettle();
      expect(gateway.installCalls, 1);
      expect(gateway.lastPlanSelections, hasLength(1));
    },
  );

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

  testWidgets('artifact detail failure can return to the originating results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      detailErrors: const [
        SkillsException('raw server failure', kind: SkillsFailureKind.server),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'recoverable query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Hub unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(_searchInput()).controller.text,
      'recoverable query',
    );
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'skill-card-example/skills/flutter-pro',
    );
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
    await tester.tap(find.byKey(const Key('detail-back')));
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
    SkillsFailureKind.server: 'Hub unavailable',
    SkillsFailureKind.timeout: 'Hub timed out',
    SkillsFailureKind.offline: 'You’re offline',
    SkillsFailureKind.invalidResponse: 'Hub response unsupported',
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

    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);

    await tester.enterText(_searchInput(), 'stateful');
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('User Scope'), findsOneWidget);
    expect(find.text('Add Project'), findsOneWidget);
    expect(find.text('Codex'), findsOneWidget);
    expect(find.byKey(const Key('library-agent-logo-codex')), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Personalize'), findsWidgets);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Hub'), findsOneWidget);
    expect(find.text('Installation Policy'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-discover')));
    await tester.pumpAndSettle();
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('All-time ranking'), findsWidgets);
    expect(_isSemanticallySelected(tester, 'Ranking'), isTrue);

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(_isSemanticallySelected(tester, 'Codex'), isTrue);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(_isSemanticallySelected(tester, 'Hub'), isTrue);

    await tester.tap(find.byKey(const Key('primary-destination-discover')));
    await tester.pumpAndSettle();
    await tester.tap(_searchInput());
    await tester.testTextInput.receiveAction(TextInputAction.search);
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
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      search.complete(gateway.searchResults);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-discover')));
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
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review 1 Targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install 1 Targets'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Close installation plan'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pumpAndSettle();

    install.complete(_success(['skillsgo', 'add']));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Installation results'), findsOneWidget);
  });

  testWidgets(
    'live target progress survives navigation and restores on return',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final install = Completer<CommandResult>();
      final gateway = FakeSkillsGateway(
        installed: false,
        installCompleter: install,
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.enterText(_searchInput(), 'progress');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install 1 Targets'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Close installation plan'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('detail-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Installation in progress'), findsOneWidget);
      expect(find.text('0 of 1 targets finished'), findsOneWidget);

      install.complete(_success(['skillsgo', 'add']));
      await tester.pumpAndSettle();
      expect(find.text('Installation results'), findsOneWidget);
    },
  );

  testWidgets(
    'retry executes only failed targets and retains prior successes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        agentNames: const ['codex', 'claude-code'],
        installFailures: const [
          {'claude-code'},
          <String>{},
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(_searchInput(), 'retry');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel('Select all available targets in User Scope'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 2 Targets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install 2 Targets'));
      await tester.pumpAndSettle();

      expect(find.text('1 targets installed, 1 failed'), findsOneWidget);
      expect(find.text('Retry 1 Failed Target'), findsOneWidget);
      await tester.tap(find.text('Retry 1 Failed Target'));
      await tester.pumpAndSettle();

      expect(find.text('2 targets installed, 0 failed'), findsOneWidget);
      expect(gateway.installCalls, 2);
      expect(gateway.executionSelectionHistory, hasLength(2));
      expect(
        gateway.executionSelectionHistory[1].map((target) => target.agent),
        ['claude-code'],
      );
    },
  );

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

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-discover')));
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
    expect(find.bySemanticsLabel(longAgent), findsWidgets);
    expect(find.byTooltip(longAgent), findsNothing);

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
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('rail-indicator'))),
    ).colorScheme;
    expect(decoration.color, scheme.primaryContainer);
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
    await tester.tap(find.byKey(const Key('primary-destination-library')));
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
    expect(find.text('Installed Skills').hitTestable(), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('primary-destination-library')));
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
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library keeps Added Projects in the agreed rail order', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      addedProjects: const [
        AddedProject(
          id: 'alpha',
          name: 'Project Alpha',
          path: '/work/alpha',
          accessState: ProjectAccessState.accessible,
        ),
      ],
      projectToAdd: const AddedProject(
        id: 'bravo',
        name: 'Project Bravo',
        path: '/work/bravo',
        accessState: ProjectAccessState.accessible,
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    final labels = [
      'All',
      'User Scope',
      'Project Alpha',
      'Add Project',
      'Codex',
    ];
    final positions = labels
        .map((label) => tester.getCenter(find.text(label)).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));

    await tester.tap(find.text('Add Project'));
    await tester.pumpAndSettle();
    expect(find.text('Project Bravo'), findsWidgets);
    expect(find.text('No Skills found in Project Bravo'), findsOneWidget);
  });

  testWidgets(
    'inaccessible Project stays visible and supports Relocate/remove',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [
          AddedProject(
            id: 'stable-id',
            name: 'Moved Project',
            path: '/Volumes/offline/project',
            accessState: ProjectAccessState.missing,
            diagnostic: 'volume offline',
          ),
        ],
        projectToRelocate: const AddedProject(
          id: 'stable-id',
          name: 'Moved Project',
          path: '/work/project',
          accessState: ProjectAccessState.accessible,
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moved Project — unavailable'));
      await tester.pumpAndSettle();

      expect(find.text('Project directory is missing'), findsOneWidget);
      expect(find.textContaining('/Volumes/offline/project'), findsOneWidget);
      expect(find.textContaining('volume offline'), findsNothing);
      await tester.tap(find.text('Relocate').last);
      await tester.pumpAndSettle();
      expect(find.text('No Skills found in Moved Project'), findsOneWidget);
      expect(gateway.projects.single.id, 'stable-id');
      expect(gateway.projects.single.path, '/work/project');

      await tester.tap(find.text('Remove from List').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from List').last);
      await tester.pumpAndSettle();
      expect(gateway.projects, isEmpty);
      expect(find.text('Moved Project'), findsNothing);
    },
  );

  testWidgets(
    'Hub outage never empties the selected Project or local Agent views',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const project = AddedProject(
        id: 'alpha',
        name: 'Project Alpha',
        path: '/work/alpha',
        accessState: ProjectAccessState.accessible,
      );
      const hubEntry = InstalledSkill(
        identity: 'hub:github.com/acme/skills/-/hub-demo',
        name: 'hub-demo',
        path: '/work/alpha/.agents/skills/hub-demo',
        agents: ['codex'],
        targetCount: 1,
        coordinate: 'github.com/acme/skills/-/hub-demo',
        projects: ['/work/alpha'],
        versions: ['v1'],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.project,
            projectRoot: '/work/alpha',
            path: '/work/alpha/.agents/skills/hub-demo',
            version: 'v1',
          ),
        ],
      );
      const localEntry = InstalledSkill(
        identity: 'local:private',
        name: 'private-local',
        path: '/Users/test/.codex/skills/private-local',
        agents: ['codex'],
        targetCount: 1,
        coordinate: 'local.skillsgo/abc/private-local',
        provenance: LibraryProvenance.local,
        versions: ['local-abc'],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/Users/test/.codex/skills/private-local',
            version: 'local-abc',
            mode: InstallationMode.copy,
          ),
        ],
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [project],
        libraryEntries: const [hubEntry, localEntry],
        updateCheckErrors: const [
          SkillsException(
            'network unavailable',
            kind: SkillsFailureKind.offline,
            isOffline: true,
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Project Alpha'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check updates'));
      await tester.pumpAndSettle();
      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text('hub-demo'), findsOneWidget);
      expect(find.text('Remove from List'), findsOneWidget);

      await tester.tap(find.text('Check updates'));
      await tester.pumpAndSettle();
      expect(find.text('You’re offline'), findsNothing);
      expect(find.text('UPDATE'), findsOneWidget);
      expect(find.text('Remove from List'), findsOneWidget);

      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();
      expect(find.text('hub-demo'), findsOneWidget);
      expect(find.text('private-local'), findsOneWidget);
      expect(find.text('Local managed'), findsOneWidget);
    },
  );

  testWidgets(
    'unified Library summarizes and filters multi-location multi-Agent targets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const alpha = AddedProject(
        id: 'alpha',
        name: 'Project Alpha',
        path: '/work/alpha',
        accessState: ProjectAccessState.accessible,
      );
      const beta = AddedProject(
        id: 'beta',
        name: 'Project Beta',
        path: '/work/beta',
        accessState: ProjectAccessState.accessible,
      );
      const entry = InstalledSkill(
        identity: 'hub:github.com/example/skills/-/demo',
        name: 'demo',
        coordinate: 'github.com/example/skills/-/demo',
        path: '/Users/test/.codex/skills/demo',
        agents: ['claude-code', 'codex'],
        targetCount: 3,
        projects: ['/work/alpha', '/work/beta'],
        versions: ['v1', 'v2'],
        versionDivergence: true,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/Users/test/.codex/skills/demo',
            version: 'v1',
          ),
          SkillInstallationTarget(
            agent: 'claude-code',
            scope: InstallationScope.project,
            projectRoot: '/work/alpha',
            path: '/work/alpha/.claude/skills/demo',
            version: 'v2',
          ),
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.project,
            projectRoot: '/work/beta',
            path: '/work/beta/.agents/skills/demo',
            version: 'v2',
          ),
        ],
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [alpha, beta],
        libraryEntries: const [entry],
        agentStatuses: const [
          AgentStatus(
            id: 'codex',
            displayName: 'Codex',
            installed: true,
            supportedScopes: [
              InstallationScope.user,
              InstallationScope.project,
            ],
          ),
          AgentStatus(
            id: 'claude-code',
            displayName: 'Claude Code',
            installed: true,
            supportedScopes: [
              InstallationScope.user,
              InstallationScope.project,
            ],
          ),
          AgentStatus(
            id: 'cursor',
            displayName: 'Cursor',
            installed: true,
            supportedScopes: [InstallationScope.project],
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      expect(find.text('3 local targets'), findsOneWidget);
      expect(find.text('2 Agents'), findsOneWidget);
      expect(find.text('2 projects'), findsOneWidget);
      expect(find.text('2 versions'), findsOneWidget);
      expect(find.text('Version divergence'), findsOneWidget);
      expect(find.text('Cursor'), findsOneWidget);

      await tester.tap(find.text('Project Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('1 local targets'), findsOneWidget);
      await tester.tap(find.text('demo').first);
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha/.claude/skills/demo'), findsWidgets);
      expect(find.text('/Users/test/.codex/skills/demo'), findsNothing);
      await tester.tap(find.byTooltip('Back to Library'));
      await tester.pumpAndSettle();

      await tester.enterText(_librarySearchInput(), 'not-present');
      await tester.pumpAndSettle();
      expect(find.text('No matching Skills'), findsOneWidget);
      await tester.enterText(_librarySearchInput(), 'demo');
      await tester.pumpAndSettle();
      expect(find.text('demo'), findsWidgets);
    },
  );

  testWidgets(
    'local detail keeps target diagnostics visible when reading fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const path = '/missing/.codex/skills/demo';
      const entry = InstalledSkill(
        identity: 'hub:github.com/example/skills/-/demo',
        name: 'demo',
        coordinate: 'github.com/example/skills/-/demo',
        path: path,
        agents: ['codex'],
        targetCount: 1,
        versions: ['v1'],
        health: InstallationHealth.missing,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: path,
            version: 'v1',
            health: InstallationHealth.missing,
          ),
        ],
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            libraryEntries: const [entry],
            localDetailError: const SkillsException('cannot read'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('demo').first);
      await tester.pumpAndSettle();

      expect(find.text(path), findsWidgets);
      expect(find.text('Target missing'), findsWidgets);
      expect(find.text('Can’t read this Skill'), findsOneWidget);
    },
  );

  testWidgets('Target Management removes only the selected healthy target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          identity: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          coordinate: 'github.com/example/skills/-/demo',
          path: '/Users/test/.codex/skills/demo',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/Users/test/.codex/skills/demo',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/work/demo',
              path: '/work/demo/.claude/skills/demo',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage targets'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillsDialog), findsOneWidget);
    expect(find.text('0 of 2 targets selected'), findsOneWidget);
    await tester.tap(find.byType(SkillsCheckbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 targets selected'), findsOneWidget);
    await tester.tap(find.text('Apply selected actions'));
    await tester.pumpAndSettle();
    expect(find.text('1 succeeded, 0 failed'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('1 local targets'), findsOneWidget);
    expect(gateway.managementTargetHistory, hasLength(1));
    expect(gateway.managementTargetHistory.single, hasLength(1));
    expect(
      gateway.managementTargetHistory.single.values.single,
      TargetManagementAction.remove,
    );
    expect(gateway.libraryEntries!.single.targets.single.agent, 'claude-code');
  });

  testWidgets(
    'unhealthy targets offer Repair or Stop Managing without Remove',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final gateway = FakeSkillsGateway(
        libraryEntries: const [
          InstalledSkill(
            identity: 'hub:github.com/example/skills/-/demo',
            name: 'demo',
            coordinate: 'github.com/example/skills/-/demo',
            path: '/Users/test/.codex/skills/demo',
            agents: ['codex', 'claude-code'],
            targetCount: 2,
            versions: ['v1'],
            health: InstallationHealth.localModification,
            targets: [
              SkillInstallationTarget(
                agent: 'codex',
                scope: InstallationScope.user,
                path: '/Users/test/.codex/skills/demo',
                version: 'v1',
              ),
              SkillInstallationTarget(
                agent: 'claude-code',
                scope: InstallationScope.project,
                projectRoot: '/work/demo',
                path: '/work/demo/.claude/skills/demo',
                version: 'v1',
                mode: InstallationMode.copy,
                health: InstallationHealth.localModification,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage targets'));
      await tester.pumpAndSettle();

      expect(find.text('Repair'), findsOneWidget);
      expect(find.text('Stop Managing'), findsOneWidget);
      expect(find.byType(SkillsCheckbox), findsOneWidget);
      await tester.tap(find.text('Stop Managing'));
      await tester.pumpAndSettle();
      expect(
        find.text('Current target content will be preserved.'),
        findsOneWidget,
      );
      expect(find.textContaining('skillsgo.yaml'), findsOneWidget);
      await tester.tap(find.text('Apply selected actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(
        gateway.managementTargetHistory.single.values.single,
        TargetManagementAction.stopManaging,
      );
      expect(gateway.libraryEntries!.single.targets.single.agent, 'codex');
    },
  );

  testWidgets('Repair restores an unhealthy managed target', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          identity: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          coordinate: 'github.com/example/skills/-/demo',
          path: '/Users/test/.codex/skills/demo',
          agents: ['codex'],
          targetCount: 1,
          versions: ['v1'],
          health: InstallationHealth.localModification,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/Users/test/.codex/skills/demo',
              version: 'v1',
              mode: InstallationMode.copy,
              health: InstallationHealth.localModification,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply selected actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(
      gateway.managementTargetHistory.single.values.single,
      TargetManagementAction.repair,
    );
    expect(
      gateway.libraryEntries!.single.targets.single.health,
      InstallationHealth.healthy,
    );
  });

  testWidgets(
    'External Installation stays visible and read-only after inspection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const path = '/Users/test/.codex/skills/external-demo';
      const entry = InstalledSkill(
        identity: 'external:abc',
        name: 'external-demo',
        path: path,
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        versions: [],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: path,
            version: '',
            mode: InstallationMode.external,
            receiptState: ReceiptState.missing,
          ),
        ],
      );
      const detail = SkillDetail(
        name: 'external-demo',
        source: 'External',
        markdown: '# External instructions',
        riskAssessment: SkillRiskAssessment.unknown,
        files: [
          SkillFile(path: 'SKILL.md', contents: '# External instructions'),
          SkillFile(
            path: 'scripts/run.sh',
            contents: '#!/bin/sh',
            executable: true,
          ),
        ],
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            libraryEntries: const [entry],
            localDetail: detail,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      expect(find.text('External installation'), findsOneWidget);
      expect(find.text('Read only'), findsOneWidget);
      expect(find.byTooltip('Manage targets'), findsNothing);
      await tester.tap(find.text('external-demo').first);
      await tester.pumpAndSettle();
      expect(find.text(path), findsWidgets);
      expect(find.text('scripts/run.sh'), findsOneWidget);
      expect(find.text('Risk unknown'), findsOneWidget);
      expect(
        find.textContaining('scripts or executable content'),
        findsOneWidget,
      );
      await tester.tap(find.text('scripts/run.sh'));
      await tester.pumpAndSettle();
      expect(find.text('#!/bin/sh'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to Library'));
      await tester.pumpAndSettle();
      expect(find.text('external-demo'), findsWidgets);
      expect(find.text('External installation'), findsOneWidget);
    },
  );

  testWidgets(
    'External adoption reviews an exact Hub source and requires confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      const path = '/Users/test/.codex/skills/external-demo';
      const entry = InstalledSkill(
        identity: 'external:abc',
        name: 'external-demo',
        path: path,
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: path,
            version: '',
            mode: InstallationMode.external,
            receiptState: ReceiptState.missing,
          ),
        ],
      );
      const match = HubContentMatch(
        coordinate: 'github.com/acme/skills/-/external-demo',
        name: 'Hub Demo',
        source: 'github.com/acme/skills',
        immutableVersion: 'sha256:immutable-version',
        commitSHA: 'commit',
        treeSHA: 'tree',
        contentDigest: 'sha256:external-content',
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        libraryEntries: const [entry],
        adoptionMatches: const [match],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('external-demo').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bring under management'));
      await tester.pumpAndSettle();
      expect(find.text('Source: github.com/acme/skills'), findsOneWidget);
      expect(
        find.text('Immutable version: sha256:immutable-version'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'current installation content will not be replaced',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gateway.adoptionHistory, isEmpty);

      await tester.tap(find.text('Bring under management'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hub Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm association'));
      await tester.pumpAndSettle();

      expect(gateway.adoptionHistory, [ExternalAdoptionAction.associateHub]);
      expect(find.text('Hub managed'), findsOneWidget);
      expect(find.text('Bring under management'), findsNothing);
    },
  );

  testWidgets(
    'External adoption keeps local detail open while Hub matching is offline',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      const path = '/Users/test/.codex/skills/offline-external';
      final gateway = FakeSkillsGateway(
        installed: false,
        libraryEntries: const [
          InstalledSkill(
            identity: 'external:offline',
            name: 'offline-external',
            path: path,
            agents: ['codex'],
            targetCount: 1,
            provenance: LibraryProvenance.external,
            targets: [
              SkillInstallationTarget(
                agent: 'codex',
                scope: InstallationScope.user,
                path: path,
                version: '',
                mode: InstallationMode.external,
                receiptState: ReceiptState.missing,
              ),
            ],
          ),
        ],
        localDetail: const SkillDetail(
          name: 'offline-external',
          source: 'External',
          markdown: '# Still available offline',
          files: [
            SkillFile(path: 'SKILL.md', contents: '# Still available offline'),
          ],
        ),
        adoptionErrors: const [
          SkillsException(
            'localized stderr is not a machine contract',
            kind: SkillsFailureKind.offline,
            isOffline: true,
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('offline-external').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bring under management'));
      await tester.pumpAndSettle();
      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text(path), findsWidgets);
      expect(find.text('External installation'), findsOneWidget);
      expect(find.text('Bring under management'), findsOneWidget);

      await tester.tap(find.text('Bring under management'));
      await tester.pumpAndSettle();
      expect(find.text('Import as Local Skill'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(path), findsWidgets);
      expect(find.text('External installation'), findsOneWidget);
      expect(find.text('Bring under management'), findsOneWidget);
    },
  );

  testWidgets(
    'Unmatched External installation imports as Local and can be exported',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      const path = '/Users/test/.codex/skills/private-demo';
      final gateway = FakeSkillsGateway(
        installed: false,
        libraryEntries: const [
          InstalledSkill(
            identity: 'external:private',
            name: 'private-demo',
            path: path,
            agents: ['codex'],
            targetCount: 1,
            provenance: LibraryProvenance.external,
            targets: [
              SkillInstallationTarget(
                agent: 'codex',
                scope: InstallationScope.user,
                path: path,
                version: '',
                mode: InstallationMode.external,
                receiptState: ReceiptState.missing,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('private-demo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bring under management'));
      await tester.pumpAndSettle();

      expect(find.text('Import as Local Skill'), findsWidgets);
      expect(
        find.textContaining('no publisher or update source'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm Local import'));
      await tester.pumpAndSettle();

      expect(gateway.adoptionHistory, [ExternalAdoptionAction.importLocal]);
      expect(find.text('Local managed'), findsOneWidget);
      expect(find.text('Update'), findsNothing);
      expect(find.text('Install more'), findsOneWidget);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(gateway.exportCalls, 1);
      expect(find.text('Command completed'), findsOneWidget);
    },
  );

  testWidgets('Local Skill installs to one more exact Agent target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const coordinate = 'local.skillsgo/abc/private-demo';
    const path = '/Users/test/.codex/skills/private-demo';
    final gateway = FakeSkillsGateway(
      installed: false,
      libraryEntries: const [
        InstalledSkill(
          identity: 'local:$coordinate',
          name: 'private-demo',
          path: path,
          agents: ['codex'],
          targetCount: 1,
          coordinate: coordinate,
          provenance: LibraryProvenance.local,
          versions: ['local-abc'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: path,
              version: 'local-abc',
              mode: InstallationMode.copy,
            ),
          ],
        ),
      ],
      localDetail: const SkillDetail(
        name: 'private-demo',
        source: 'Local',
        markdown: '# Private',
        immutableVersion: 'local-abc',
        files: [SkillFile(path: 'SKILL.md', contents: '# Private')],
        installationTargets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: path,
            version: 'local-abc',
            mode: InstallationMode.copy,
          ),
        ],
      ),
      agentStatuses: const [
        AgentStatus(
          id: 'codex',
          displayName: 'Codex',
          installed: true,
          supportedScopes: [InstallationScope.user],
        ),
        AgentStatus(
          id: 'cursor',
          displayName: 'Cursor',
          installed: true,
          supportedScopes: [InstallationScope.user],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('private-demo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install more'));
    await tester.pumpAndSettle();

    expect(find.text('Installed'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Select User Scope for Cursor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review 1 Targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install 1 Targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay Here'));
    await tester.pumpAndSettle();

    expect(gateway.executionSelectionHistory.single.single.agent, 'cursor');
    expect(gateway.libraryEntries!.single.agents, ['codex', 'cursor']);
    expect(find.text('User Scope / Cursor · local-abc'), findsOneWidget);
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

    final hotButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Hot'),
    );
    hotButton.focusNode!.requestFocus();
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
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
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
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Make SkillsGo yours'), findsOneWidget);
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();
    expect(find.text('Hub Origin'), findsOneWidget);
    expect(find.text('Make SkillsGo yours'), findsNothing);

    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();
    expect(find.text('/Users/test/.skillsgo/store'), findsOneWidget);
    expect(find.text('Readable'), findsOneWidget);

    await tester.tap(find.text('Color Scheme'));
    await tester.pumpAndSettle();
    expect(find.text('Generated Material color roles'), findsOneWidget);
    expect(find.text('primaryFixedDim'), findsOneWidget);
    expect(find.text('surfaceContainerHighest'), findsOneWidget);
    expect(find.text('inversePrimary'), findsOneWidget);
    expect(find.text('onErrorContainer'), findsOneWidget);

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
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
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
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
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
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
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

  testWidgets('Hub Origin can be tested, saved, and reset immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('hub-origin')),
        matching: find.byType(EditableText),
      ),
      'https://self-hosted.example',
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection ready'), findsOneWidget);

    await tester.tap(find.text('Save Origin'));
    await tester.pumpAndSettle();
    expect(gateway.hubOrigin, 'https://self-hosted.example');

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(gateway.hubOrigin, 'https://hub.skillsgo.ai');
  });

  testWidgets('a Hub Origin is not saved when its protocol test fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(hubTestState: HealthState.invalid);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('hub-origin')),
        matching: find.byType(EditableText),
      ),
      'https://incompatible.example',
    );
    await tester.tap(find.text('Save Origin'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('did not return the SkillsGo Hub'),
      findsOneWidget,
    );
    expect(gateway.hubOrigin, 'https://hub.skillsgo.ai');
  });

  testWidgets(
    'Critical-risk override persists while High confirmation stays required',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway();
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-settings')));
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
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('local-skill'), findsOneWidget);
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE'), findsOneWidget);
  });

  testWidgets('Update Plan changes only explicitly selected targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          identity: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/user/local-skill',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          coordinate: 'github.com/test/skills/-/local-skill',
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/tmp/user/local-skill',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/tmp/project',
              path: '/tmp/project/.claude/skills/local-skill',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('Select targets to update'), findsOneWidget);
    expect(find.text('2 of 2 updateable targets selected'), findsOneWidget);
    expect(
      find.textContaining('/tmp/project/skillsgo-lock.yaml'),
      findsOneWidget,
    );
    await tester.tap(find.byType(SkillsCheckbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 updateable targets selected'), findsOneWidget);
    expect(
      find.textContaining('/tmp/project/skillsgo-lock.yaml'),
      findsNothing,
    );
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();

    expect(gateway.updateTargetHistory, hasLength(1));
    expect(gateway.updateTargetHistory.single, hasLength(1));
    expect(gateway.updateTargetHistory.single.single, contains('codex'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('2 versions'), findsOneWidget);
    expect(find.text('Version divergence'), findsOneWidget);
  });

  testWidgets('Update Plan retries only failed targets and retains success', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      updateFailures: const [
        {'claude-code'},
        <String>{},
      ],
      libraryEntries: const [
        InstalledSkill(
          identity: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/user/local-skill',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          coordinate: 'github.com/test/skills/-/local-skill',
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/tmp/user/local-skill',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/tmp/project',
              path: '/tmp/project/.claude/skills/local-skill',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();

    expect(find.text('Retry 1 Failed Update'), findsOneWidget);
    expect(gateway.updateTargetHistory.first, hasLength(2));
    await tester.tap(find.text('Retry 1 Failed Update'));
    await tester.pumpAndSettle();

    expect(gateway.updateTargetHistory, hasLength(2));
    expect(gateway.updateTargetHistory.last, hasLength(1));
    expect(gateway.updateTargetHistory.last.single, contains('claude-code'));
    expect(find.text('Retry 1 Failed Update'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('1 versions'), findsOneWidget);
    expect(find.text('Version divergence'), findsNothing);
  });

  testWidgets('installed detail refreshes target versions after update', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          identity: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/local-skill',
          agents: ['codex'],
          targetCount: 1,
          coordinate: 'github.com/test/skills/-/local-skill',
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/tmp/local-skill',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill'));
    await tester.pumpAndSettle();
    expect(find.text('User Scope / Codex · v1'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('User Scope / Codex · v2'), findsOneWidget);
  });

  testWidgets(
    'core flow searches, installs, checks updates and removes a target',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway(installed: false);
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.enterText(_searchInput(), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(find.text('Install Flutter Pro to'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1 Targets'));
      await tester.pumpAndSettle();
      expect(find.text('1 create'), findsOneWidget);
      await tester.tap(find.text('Install 1 Targets'));
      await tester.pumpAndSettle();
      expect(find.text('1 targets installed, 0 failed'), findsOneWidget);
      await tester.tap(find.text('View in Library'));
      await tester.pumpAndSettle();
      expect(find.text('local-skill'), findsOneWidget);

      await tester.tap(find.text('Check updates'));
      await tester.pumpAndSettle();
      expect(find.text('UPDATE'), findsOneWidget);
      await tester.tap(find.byTooltip('Manage targets'));
      await tester.pumpAndSettle();
      expect(find.text('Manage installation targets'), findsOneWidget);
      expect(find.byType(SkillsCheckbox), findsOneWidget);
      await tester.tap(find.byType(SkillsCheckbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply selected actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('No skills installed yet'), findsOneWidget);
    },
  );
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
    List<AddedProject> addedProjects = const [],
    this.projectToAdd,
    this.projectToRelocate,
    List<InstalledSkill>? libraryEntries,
    this.localDetailError,
    this.localDetail,
    this.hubOrigin = 'https://hub.skillsgo.ai',
    this.folderTheme = 'manila',
    this.themeMode = AppThemeMode.system,
    this.hubTestState = HealthState.ready,
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
    this.planConflictReason = '',
    this.riskPolicy = const PersonalRiskPolicy(),
    this.installFailures = const [],
    List<SkillsException> installPlanErrors = const [],
    this.updateFailures = const [],
    this.adoptionMatches = const [],
    List<SkillsException> updateCheckErrors = const [],
    List<SkillsException> adoptionErrors = const [],
  }) : searchResults = searchResults ?? _defaultSearchResults,
       remoteDetail =
           remoteDetail ??
           (installed
               ? defaultRemoteDetail
               : _withoutInstallationTargets(defaultRemoteDetail)),
       detailErrors = List.of(detailErrors),
       installPlanErrors = List.of(installPlanErrors),
       updateCheckErrors = List.of(updateCheckErrors),
       adoptionErrors = List.of(adoptionErrors),
       libraryEntries = libraryEntries == null ? null : List.of(libraryEntries),
       projects = List.of(addedProjects);
  final bool cliReady;
  final Completer<List<SkillSummary>>? searchCompleter;
  final Completer<CommandResult>? installCompleter;
  final Completer<SkillDetail>? detailCompleter;
  final List<String> agentNames;
  final List<AgentStatus>? agentStatuses;
  final SkillsException? agentInspectionError;
  final AddedProject? projectToAdd;
  final AddedProject? projectToRelocate;
  List<InstalledSkill>? libraryEntries;
  final SkillsException? localDetailError;
  final SkillDetail? localDetail;
  final List<AddedProject> projects;
  String hubOrigin;
  String folderTheme;
  AppThemeMode themeMode;
  final HealthState hubTestState;
  PersonalRiskPolicy riskPolicy;
  final String planConflictReason;
  final StorageStatus storageStatus;
  final String appVersion;
  final Map<String, DiscoveryPage> discoveryPages;
  final SkillsException? discoveryError;
  final Map<String, SkillsException> discoveryErrors;
  final SkillDetail remoteDetail;
  final List<SkillsException> detailErrors;
  final List<Set<String>> installFailures;
  final List<SkillsException> installPlanErrors;
  final List<Set<String>> updateFailures;
  final List<HubContentMatch> adoptionMatches;
  final List<SkillsException> updateCheckErrors;
  final List<SkillsException> adoptionErrors;
  bool installed;
  final queries = <String>[];
  final collections = <DiscoveryCollection>[];
  final requestedOffsets = <int>[];
  int installCalls = 0;
  int updateCalls = 0;
  List<InstallationTargetSelection> lastPlanSelections = const [];
  final executionSelectionHistory = <List<InstallationTargetSelection>>[];
  final updateTargetHistory = <List<String>>[];
  final managementTargetHistory = <Map<String, TargetManagementAction>>[];
  final adoptionHistory = <ExternalAdoptionAction>[];
  int exportCalls = 0;
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
  static final defaultRemoteDetail = SkillDetail(
    name: 'Flutter Pro',
    source: 'example/skills',
    repository: 'github.com/example/skills',
    installs: 1200,
    githubStars: 12800,
    sourceUpdatedAt: DateTime.utc(2026, 7, 15),
    archiveSize: 24576,
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
    hubExecutableSignal: true,
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
  Future<String> loadFolderTheme() async => folderTheme;
  @override
  Future<void> saveFolderTheme(String theme) async => folderTheme = theme;

  @override
  Future<AppThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async => themeMode = mode;
  @override
  Future<String> loadHubOrigin() async => hubOrigin;
  @override
  Future<void> saveHubOrigin(String origin) async {
    hubOrigin = origin;
  }

  @override
  Future<void> resetHubOrigin() async {
    hubOrigin = 'https://hub.skillsgo.ai';
  }

  @override
  Future<HubStatus> testHubOrigin(String origin) async => HubStatus(
    origin: origin,
    state: hubTestState,
    issue: hubTestState == HealthState.ready ? null : HubIssue.invalidProtocol,
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
  Future<List<InstalledSkill>> listInstalled({
    List<AddedProject> projects = const [],
  }) async =>
      libraryEntries ??
      (installed
          ? [
              InstalledSkill(
                identity: 'hub:github.com/test/skills/-/local-skill',
                name: 'local-skill',
                path: '/tmp/local-skill',
                agents: agentNames,
                targetCount: agentNames.length,
                coordinate: 'github.com/test/skills/-/local-skill',
                versions: const ['v1'],
                targets: [
                  for (final agent in agentNames)
                    SkillInstallationTarget(
                      agent: agent,
                      scope: InstallationScope.user,
                      path: '/tmp/local-skill',
                      version: 'v1',
                    ),
                ],
              ),
            ]
          : const []);
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
  Future<List<AddedProject>> loadAddedProjects() async => List.of(projects);
  @override
  Future<AddedProject?> addProject() async {
    final project = projectToAdd;
    if (project != null && !projects.any((item) => item.id == project.id)) {
      projects.add(project);
    }
    return project;
  }

  @override
  Future<AddedProject?> relocateProject(String id) async {
    final project = projectToRelocate;
    if (project == null || project.id != id) return null;
    final index = projects.indexWhere((item) => item.id == id);
    if (index >= 0) projects[index] = project;
    return project;
  }

  @override
  Future<void> removeProject(String id) async {
    projects.removeWhere((project) => project.id == id);
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async {
    if (localDetailError != null) throw localDetailError!;
    return localDetail ??
        SkillDetail(
          name: 'local-skill',
          source: 'Local',
          markdown: '# Local',
          immutableVersion: skill.versions.length == 1
              ? skill.versions.single
              : '',
          files: const [SkillFile(path: 'SKILL.md', contents: '# Local')],
          installationTargets: skill.targets,
        );
  }

  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async {
    if (updateCheckErrors.isNotEmpty) throw updateCheckErrors.removeAt(0);
    return {
      for (final skill in skills)
        (skill.identity.isEmpty ? skill.name : skill.identity):
            UpdateState.available,
    };
  }

  @override
  Future<InstallationPlan> preflightInstall(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool riskConfirmed = false,
    bool allowCritical = false,
  }) async {
    if (installPlanErrors.isNotEmpty) throw installPlanErrors.removeAt(0);
    lastPlanSelections = List.unmodifiable(selections);
    final riskAssessment = remoteDetail.riskAssessment;
    final riskBlocked =
        (riskAssessment == SkillRiskAssessment.high && !riskConfirmed) ||
        (riskAssessment == SkillRiskAssessment.critical &&
            (!riskConfirmed || !allowCritical));
    final targets = selections
        .map((selection) {
          final stateToken = planConflictReason.isEmpty
              ? ''
              : 'sha256:${selection.scope.name}-${selection.agent}-$planConflictReason';
          final reviewedConflict =
              selection.resolution == InstallationTargetResolution.replace &&
              selection.expectedReason == planConflictReason &&
              selection.expectedState == stateToken;
          final unresolvedConflict =
              planConflictReason.isNotEmpty && !reviewedConflict;
          final action = unresolvedConflict
              ? InstallationPlanAction.conflict
              : riskBlocked
              ? InstallationPlanAction.blockedByRisk
              : reviewedConflict
              ? InstallationPlanAction.replace
              : InstallationPlanAction.create;
          return InstallationPlanItem(
            target: InstallationPlanTarget(
              scope: selection.scope,
              projectRoot: selection.projectRoot,
              agent: selection.agent,
              mode: selection.mode,
              path: selection.scope == InstallationScope.user
                  ? '/Users/test/.${selection.agent}/skills/${skill.skillId}'
                  : '${selection.projectRoot}/.agents/skills/${skill.skillId}',
            ),
            action: action,
            workspaceLockChange: selection.scope == InstallationScope.project,
            reasonCode: unresolvedConflict
                ? planConflictReason
                : riskBlocked
                ? riskAssessment == SkillRiskAssessment.critical
                      ? 'critical-risk'
                      : 'high-risk'
                : reviewedConflict
                ? planConflictReason
                : '',
            stateToken: stateToken,
            affectedBindings: planConflictReason == 'shared-target-conflict'
                ? [
                    InstallationAffectedBinding(
                      agent: selection.agent,
                      scope: selection.scope,
                      mode: selection.mode,
                      path: selection.scope == InstallationScope.user
                          ? '/Users/test/.${selection.agent}/skills/${skill.skillId}'
                          : '${selection.projectRoot}/.agents/skills/${skill.skillId}',
                    ),
                    InstallationAffectedBinding(
                      agent: 'claude-code',
                      scope: selection.scope,
                      mode: selection.mode,
                      path: selection.scope == InstallationScope.user
                          ? '/Users/test/.${selection.agent}/skills/${skill.skillId}'
                          : '${selection.projectRoot}/.agents/skills/${skill.skillId}',
                    ),
                  ]
                : const [],
          );
        })
        .toList(growable: false);
    return InstallationPlan(
      source: skill.id,
      coordinate: skill.id,
      version: immutableVersion,
      name: skill.skillId,
      selections: List.unmodifiable(selections),
      targets: targets,
      summary: InstallationPlanSummary(
        create: targets
            .where((item) => item.action == InstallationPlanAction.create)
            .length,
        replace: targets
            .where((item) => item.action == InstallationPlanAction.replace)
            .length,
        skip: 0,
        conflict: targets
            .where((item) => item.action == InstallationPlanAction.conflict)
            .length,
        blockedByRisk: targets
            .where(
              (item) => item.action == InstallationPlanAction.blockedByRisk,
            )
            .length,
      ),
      workspaceLockChanges: selections
          .where((selection) => selection.scope == InstallationScope.project)
          .map(
            (selection) => WorkspaceLockChange(
              projectRoot: selection.projectRoot,
              path: '${selection.projectRoot}/skillsgo-lock.yaml',
              skill: skill.skillId,
              toVersion: immutableVersion,
            ),
          )
          .toList(growable: false),
      riskAssessment: riskAssessment,
      riskConfirmed: riskConfirmed,
      allowCritical: allowCritical,
    );
  }

  @override
  Future<InstallationExecution> executeInstall(
    InstallationPlan plan, {
    void Function(InstallationTargetProgress progress)? onProgress,
  }) async {
    installCalls++;
    executionSelectionHistory.add(List.unmodifiable(plan.selections));
    var sequence = 0;
    for (final item in plan.targets) {
      onProgress?.call(
        InstallationTargetProgress(
          sequence: ++sequence,
          target: item.target,
          action: item.action,
          state: InstallationProgressState.started,
        ),
      );
    }
    var forceAllFailed = false;
    var failureDiagnostic = '';
    if (installCompleter != null) {
      final result = await installCompleter!.future;
      forceAllFailed = !result.succeeded;
      failureDiagnostic = result.output.stderr;
    }
    final configuredFailures = installCalls <= installFailures.length
        ? installFailures[installCalls - 1]
        : const <String>{};
    final results = <InstallationTargetResult>[];
    for (final item in plan.targets) {
      final failed =
          forceAllFailed || configuredFailures.contains(item.target.agent);
      final result = InstallationTargetResult(
        target: item.target,
        action: item.action,
        outcome: failed
            ? InstallationTargetOutcome.failed
            : InstallationTargetOutcome.succeeded,
        errorCode: failed ? 'install-failed' : '',
        diagnostic: failed ? failureDiagnostic : '',
      );
      results.add(result);
      onProgress?.call(
        InstallationTargetProgress(
          sequence: ++sequence,
          target: item.target,
          action: item.action,
          state: InstallationProgressState.finished,
          result: result,
        ),
      );
    }
    final succeeded = results
        .where(
          (result) => result.outcome == InstallationTargetOutcome.succeeded,
        )
        .length;
    final failed = results.length - succeeded;
    installed = succeeded > 0;
    final entries = libraryEntries;
    if (entries != null && succeeded > 0) {
      final index = entries.indexWhere(
        (entry) => entry.coordinate == plan.coordinate,
      );
      if (index >= 0) {
        final existing = entries[index];
        final targets = List<SkillInstallationTarget>.of(existing.targets);
        for (final result in results.where(
          (item) => item.outcome == InstallationTargetOutcome.succeeded,
        )) {
          if (targets.any(
            (target) =>
                target.scope == result.target.scope &&
                target.projectRoot == result.target.projectRoot &&
                target.agent == result.target.agent,
          )) {
            continue;
          }
          targets.add(
            SkillInstallationTarget(
              agent: result.target.agent,
              scope: result.target.scope,
              projectRoot: result.target.projectRoot,
              path: result.target.path,
              version: plan.version,
              mode: result.target.mode,
            ),
          );
        }
        entries[index] = existing.withTargets(targets);
      }
    }
    return InstallationExecution(
      coordinate: plan.coordinate,
      version: plan.version,
      name: plan.name,
      results: results,
      summary: InstallationExecutionSummary(
        succeeded: succeeded,
        skipped: 0,
        conflict: 0,
        failed: failed,
      ),
    );
  }

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
  Future<ExternalAdoptionPlan> preflightExternalAdoption(
    InstalledSkill skill,
  ) async {
    if (adoptionErrors.isNotEmpty) throw adoptionErrors.removeAt(0);
    final target = skill.targets.single;
    return ExternalAdoptionPlan(
      identity: skill.identity,
      name: skill.name,
      target: InstallationPlanTarget(
        scope: target.scope,
        projectRoot: target.projectRoot,
        agent: target.agent,
        mode: InstallationMode.copy,
        path: target.path,
      ),
      contentDigest: 'sha256:external-content',
      sourceHint: '',
      stateToken: 'sha256:external-state',
      matches: adoptionMatches,
      canImportLocal: true,
    );
  }

  @override
  Future<ExternalAdoptionResult> executeExternalAdoption(
    ExternalAdoptionPlan plan,
  ) async {
    final action = plan.action!;
    adoptionHistory.add(action);
    final match = plan.selectedMatch;
    final provenance = action == ExternalAdoptionAction.importLocal
        ? LibraryProvenance.local
        : LibraryProvenance.hub;
    final coordinate =
        match?.coordinate ?? 'local.skillsgo/content/${plan.name}';
    final version = match?.immutableVersion ?? 'local-content';
    final managedTarget = SkillInstallationTarget(
      agent: plan.target.agent,
      scope: plan.target.scope,
      projectRoot: plan.target.projectRoot,
      path: plan.target.path,
      version: version,
      mode: InstallationMode.copy,
      receiptState: ReceiptState.present,
    );
    libraryEntries = [
      InstalledSkill(
        identity: '${provenance.name}:$coordinate',
        name: plan.name,
        path: plan.target.path,
        agents: [plan.target.agent],
        targetCount: 1,
        coordinate: coordinate,
        provenance: provenance,
        versions: [version],
        targets: [managedTarget],
      ),
    ];
    return ExternalAdoptionResult(
      action: action,
      name: plan.name,
      coordinate: coordinate,
      version: version,
      provenance: provenance,
      contentDigest: plan.contentDigest,
      target: plan.target,
    );
  }

  @override
  Future<CommandResult?> exportLocalSkill(InstalledSkill skill) async {
    exportCalls++;
    return _success(['skillsgo', 'export']);
  }

  @override
  Future<TargetManagementPlan> preflightTargetManagement(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    final items = [
      for (final target in targets)
        TargetManagementPlanItem(
          target: InstallationPlanTarget(
            scope: target.scope,
            projectRoot: target.projectRoot,
            agent: target.agent,
            mode: target.mode,
            path: target.path,
          ),
          name: skill.name,
          coordinate: skill.coordinate,
          version: target.version,
          health: target.health,
          receiptState: target.receiptState,
          allowedActions: target.health == InstallationHealth.healthy
              ? const [TargetManagementAction.remove]
              : const [
                  TargetManagementAction.repair,
                  TargetManagementAction.stopManaging,
                ],
          stateToken: 'manage-${target.agent}-${target.path}',
          workspaceMetadataChange: target.scope == InstallationScope.project,
        ),
    ];
    return TargetManagementPlan(
      targets: items,
      summary: TargetManagementPlanSummary(
        removable: items
            .where(
              (item) =>
                  item.allowedActions.contains(TargetManagementAction.remove),
            )
            .length,
        repairable: items
            .where(
              (item) =>
                  item.allowedActions.contains(TargetManagementAction.repair),
            )
            .length,
        stoppable: items
            .where(
              (item) => item.allowedActions.contains(
                TargetManagementAction.stopManaging,
              ),
            )
            .length,
      ),
    );
  }

  @override
  Future<TargetManagementExecution> executeTargetManagement(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  }) async {
    managementTargetHistory.add({
      for (final item in plan.targets)
        updateTargetKey(item.target): item.action!,
    });
    var sequence = 0;
    final results = <TargetManagementResult>[];
    for (final item in plan.targets) {
      onProgress?.call(
        TargetManagementProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          coordinate: item.coordinate,
          version: item.version,
          action: item.action!,
          state: InstallationProgressState.started,
        ),
      );
      final result = TargetManagementResult(
        target: item.target,
        name: item.name,
        coordinate: item.coordinate,
        version: item.version,
        action: item.action!,
        outcome: TargetManagementOutcome.succeeded,
      );
      results.add(result);
      onProgress?.call(
        TargetManagementProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          coordinate: item.coordinate,
          version: item.version,
          action: item.action!,
          state: InstallationProgressState.finished,
          result: result,
        ),
      );
    }
    final actions = {
      for (final item in plan.targets)
        updateTargetKey(item.target): item.action!,
    };
    libraryEntries = libraryEntries
        ?.map((skill) {
          final remaining = <SkillInstallationTarget>[];
          for (final target in skill.targets) {
            final key = installedUpdateTargetKey(target);
            final action = actions[key];
            if (action == TargetManagementAction.remove ||
                action == TargetManagementAction.stopManaging) {
              continue;
            }
            if (action == TargetManagementAction.repair) {
              remaining.add(
                SkillInstallationTarget(
                  agent: target.agent,
                  scope: target.scope,
                  path: target.path,
                  version: target.version,
                  projectRoot: target.projectRoot,
                  mode: target.mode,
                  receiptState: ReceiptState.present,
                  health: InstallationHealth.healthy,
                ),
              );
            } else {
              remaining.add(target);
            }
          }
          return remaining.isEmpty ? null : skill.withTargets(remaining);
        })
        .whereType<InstalledSkill>()
        .toList(growable: false);
    if (libraryEntries == null || libraryEntries!.isEmpty) installed = false;
    return TargetManagementExecution(
      results: results,
      summary: TargetManagementExecutionSummary(
        succeeded: results.length,
        failed: 0,
      ),
    );
  }

  @override
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    final items = [
      for (final target in targets)
        UpdatePlanItem(
          target: InstallationPlanTarget(
            scope: target.scope,
            projectRoot: target.projectRoot,
            agent: target.agent,
            mode: target.mode,
            path: target.path,
          ),
          name: skill.name,
          coordinate: skill.coordinate,
          sourceRef: 'main',
          fromVersion: target.version,
          toVersion: 'v2',
          action: UpdatePlanAction.update,
          stateToken: 'state-${target.agent}-${target.path}',
          workspaceLockChange: target.scope == InstallationScope.project,
        ),
    ];
    return UpdatePlan(
      targets: items,
      workspaceLockChanges: [
        for (final item in items)
          if (item.workspaceLockChange)
            WorkspaceLockChange(
              projectRoot: item.target.projectRoot,
              path: '${item.target.projectRoot}/skillsgo-lock.yaml',
              skill: item.name,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
            ),
      ],
      summary: UpdatePlanSummary(
        update: items.length,
        current: 0,
        pinned: 0,
        failed: 0,
      ),
    );
  }

  @override
  Future<UpdateExecution> executeUpdate(
    UpdatePlan plan, {
    void Function(UpdateTargetProgress progress)? onProgress,
  }) async {
    updateCalls++;
    updateTargetHistory.add(
      plan.targets.map((item) => updateTargetKey(item.target)).toList(),
    );
    final configuredFailures = updateCalls <= updateFailures.length
        ? updateFailures[updateCalls - 1]
        : const <String>{};
    var sequence = 0;
    final results = <UpdateTargetResult>[];
    for (final item in plan.targets) {
      onProgress?.call(
        UpdateTargetProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          coordinate: item.coordinate,
          fromVersion: item.fromVersion,
          toVersion: item.toVersion,
          state: InstallationProgressState.started,
        ),
      );
      final failed = configuredFailures.contains(item.target.agent);
      final result = UpdateTargetResult(
        target: item.target,
        name: item.name,
        coordinate: item.coordinate,
        fromVersion: item.fromVersion,
        toVersion: item.toVersion,
        outcome: failed
            ? UpdateTargetOutcome.failed
            : UpdateTargetOutcome.succeeded,
        errorCode: failed ? 'update-failed' : '',
        diagnostic: failed ? 'Target is not writable.' : '',
      );
      results.add(result);
      onProgress?.call(
        UpdateTargetProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          coordinate: item.coordinate,
          fromVersion: item.fromVersion,
          toVersion: item.toVersion,
          state: InstallationProgressState.finished,
          result: result,
        ),
      );
    }
    final succeededKeys = results
        .where((result) => result.outcome == UpdateTargetOutcome.succeeded)
        .map((result) => updateTargetKey(result.target))
        .toSet();
    libraryEntries = libraryEntries
        ?.map(
          (skill) => skill.withTargets([
            for (final target in skill.targets)
              if (succeededKeys.contains(
                updateTargetKey(
                  InstallationPlanTarget(
                    scope: target.scope,
                    projectRoot: target.projectRoot,
                    agent: target.agent,
                    mode: target.mode,
                    path: target.path,
                  ),
                ),
              ))
                SkillInstallationTarget(
                  agent: target.agent,
                  scope: target.scope,
                  path: target.path,
                  version: 'v2',
                  projectRoot: target.projectRoot,
                  mode: target.mode,
                  receiptState: target.receiptState,
                  health: target.health,
                )
              else
                target,
          ]),
        )
        .toList(growable: false);
    final succeeded = results
        .where((result) => result.outcome == UpdateTargetOutcome.succeeded)
        .length;
    final failed = results.length - succeeded;
    return UpdateExecution(
      results: results,
      summary: UpdateExecutionSummary(
        succeeded: succeeded,
        skipped: 0,
        failed: failed,
      ),
    );
  }
}

SkillDetail _withoutInstallationTargets(
  SkillDetail detail, {
  SkillRiskAssessment? riskAssessment,
}) => SkillDetail(
  name: detail.name,
  source: detail.source,
  markdown: detail.markdown,
  files: detail.files,
  installs: detail.installs,
  description: detail.description,
  requestedVersion: detail.requestedVersion,
  immutableVersion: detail.immutableVersion,
  commitSHA: detail.commitSHA,
  treeSHA: detail.treeSHA,
  sourceRef: detail.sourceRef,
  contentDigest: detail.contentDigest,
  manifest: detail.manifest,
  trustLevel: detail.trustLevel,
  riskAssessment: riskAssessment ?? detail.riskAssessment,
  riskScannerVersion: detail.riskScannerVersion,
  riskEvidence: detail.riskEvidence,
  hubExecutableSignal: detail.hubExecutableSignal,
);

CommandResult _success(List<String> command) => CommandResult(
  command: command,
  output: const ProcessOutput(exitCode: 0, stdout: 'ok', stderr: ''),
);

Finder _searchInput() => find.descendant(
  of: find.byKey(const Key('skill-search')),
  matching: find.byType(EditableText),
);

Finder _librarySearchInput() => find.descendant(
  of: find.byKey(const Key('library-search')),
  matching: find.byType(EditableText),
);

bool _isSemanticallySelected(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  return List.generate(
    finder.evaluate().length,
    (index) => tester.getSemantics(finder.at(index)),
  ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue);
}

double _contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = aLuminance > bLuminance ? aLuminance : bLuminance;
  final darker = aLuminance > bLuminance ? bLuminance : aLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Brightness _shellBrightness(WidgetTester tester) => Theme.of(
  tester.element(find.byKey(const Key('primary-folder-shell'))),
).brightness;
