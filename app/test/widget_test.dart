/*
 * [INPUT]: Uses SkillsGoApp, shared navigation primitives, Loading Animation Widget, Portal Labs indicators, the vendored subscription switch and named-preset Bloom color picker, and a controllable SkillsGateway fake plus locale, motion, focus, and keyboard settings.
 * [OUTPUT]: Specifies Mandatory Onboarding including multi-directory project addition, startup, persistent primary folder navigation, aligned editorial destination frames, leaderboard-style discovery search and tabs, opaque directional discovery/detail transitions, detail product metadata, discovery/detail recovery, outage-resilient Hub/Local/External Library views, fixed All/Global navigation and section dividers with compact independently scrollable Projects and a slim scrollbar, concise project-empty recovery to Discover, Agent filtering, reduced-motion-aware Settings secondary-body entrances, anchored installation-location selection, Installation/Update/Target Management journeys including External removal and location-scoped Batch Takeover progress, offline retry, Local install-more/export, exact-target recovery, focus, accessibility, and mutations.
 * [POS]: Serves as the highest App behavior suite at the rendered desktop interface seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle, PointerDeviceKind, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:portal_labs/portal_labs.dart' as portal;
import 'package:skillsgo/ui/bloom_color_picker/bloom_color_picker.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/agent_logo.dart';
import 'package:skillsgo/ui/brand_theme_presets.dart';
import 'package:skillsgo/ui/native_components.dart';
import 'package:skillsgo/ui/nested_navigation.dart';
import 'package:skillsgo/ui/primary_folder_shell.dart';
import 'package:skillsgo/ui/subscription_segmented_switch.dart';

void main() {
  testWidgets(
    'clean installation completes two-step Mandatory Onboarding before Library',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.welcome,
        ),
        agentNames: const ['codex', 'claude-code'],
        projectsToAdd: const [
          AddedProject(
            id: 'project-a',
            name: 'Project A',
            path: '/work/project-a',
            accessState: ProjectAccessState.accessible,
          ),
          AddedProject(
            id: 'project-b',
            name: 'Project B',
            path: '/work/project-b',
            accessState: ProjectAccessState.accessible,
          ),
        ],
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to SkillsGo'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-skillsgo-logo')), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Discover'), findsNothing);
      expect(gateway.projectLoads, 0);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Add your projects'), findsOneWidget);
      expect(find.text('Add now'), findsOneWidget);
      expect(find.textContaining('skills.sh'), findsNothing);
      expect(find.text('Start Using SkillsGo'), findsOneWidget);

      await tester.tap(find.text('Add now'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-project-project-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-project-project-b')),
        findsOneWidget,
      );
      expect(find.text('Start Using SkillsGo'), findsOneWidget);

      await tester.tap(find.text('Start Using SkillsGo'));
      await tester.pumpAndSettle();

      expect(gateway.onboardingCompletions, 1);
      expect(find.text('local-skill'), findsOneWidget);
    },
  );

  testWidgets('Onboarding startup errors remain retryable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      onboardingState: const OnboardingState(
        completed: false,
        step: OnboardingStep.welcome,
      ),
      onboardingLoadErrors: [StateError('preferences unavailable')],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('SkillsGo could not load setup.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillsGo'), findsOneWidget);
  });

  testWidgets(
    'Onboarding project strip exposes hover removal without deleting files',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.projects,
        ),
        addedProjects: const [
          AddedProject(
            id: 'project-a',
            name: 'Project A',
            path: '/work/project-a',
            accessState: ProjectAccessState.accessible,
          ),
        ],
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final project = find.byKey(
        const ValueKey('onboarding-project-project-a'),
      );
      final remove = find.byKey(
        const ValueKey('onboarding-remove-project-project-a'),
      );
      expect(project, findsOneWidget);
      expect(find.text('1 project added'), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(project));
      await tester.pump(const Duration(milliseconds: 120));
      expect(remove, findsOneWidget);

      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(project, findsNothing);
      expect(gateway.projects, isEmpty);
    },
  );

  testWidgets('Mandatory Onboarding primary actions support the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      onboardingState: const OnboardingState(
        completed: false,
        step: OnboardingStep.welcome,
      ),
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add your projects'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillsGo'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(gateway.onboardingCompletions, 1);
    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets(
    'Onboarding persists the next step before exposing its final action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saved = Completer<void>();
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.welcome,
        ),
        onboardingStepSaveCompleter: saved,
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Welcome to SkillsGo'), findsOneWidget);
      expect(find.text('Start Using SkillsGo'), findsNothing);
      saved.complete();
      await tester.pumpAndSettle();
      expect(find.text('Start Using SkillsGo'), findsOneWidget);
    },
  );

  testWidgets(
    'Onboarding waits for projects before enabling its final action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final projects = Completer<List<AddedProject>>();
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.projects,
        ),
        projectLoadCompleter: projects,
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
      await tester.tap(find.text('Start Using SkillsGo'));
      await tester.pump();
      expect(gateway.onboardingCompletions, 0);

      projects.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('Add now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('subscription switch preserves its sliding selection motion', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SubscriptionSegmentedSwitch(
            options: const [
              SubscriptionSwitchOption(
                label: 'All',
                icon: HugeIcons.strokeRoundedLayers01,
              ),
              SubscriptionSwitchOption(
                label: 'Updates',
                icon: HugeIcons.strokeRoundedArrowReloadVertical,
              ),
            ],
            selectedIndex: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    final thumb = find.byKey(const Key('subscription-switch-thumb'));
    final thumbSize = tester.getSize(thumb);
    final switchSize = tester.getSize(find.byType(SubscriptionSegmentedSwitch));
    expect(thumbSize.height, 28);
    expect(thumbSize.width * 2 + 8, switchSize.width);
    final start = tester.getTopLeft(thumb).dx;
    await tester.tap(find.text('Updates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getTopLeft(thumb).dx;
    var furthest = midway;
    var passedTarget = false;
    var rebounded = false;
    final target = start + thumbSize.width;
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final position = tester.getTopLeft(thumb).dx;
      furthest = math.max(furthest, position);
      if (position > target + .1) passedTarget = true;
      if (passedTarget && position < target - .1) rebounded = true;
    }

    expect(selected, 1);
    expect(midway, greaterThan(start));
    expect(midway, lessThan(target));
    expect(furthest, greaterThan(target));
    expect(furthest, lessThanOrEqualTo(target + 2.51));
    expect(rebounded, isTrue);
  });

  testWidgets('subscription switch adapts its width to localized labels', (
    tester,
  ) async {
    Future<double> pumpSwitch(List<String> labels) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SubscriptionSegmentedSwitch(
              options: [
                SubscriptionSwitchOption(
                  label: labels[0],
                  icon: HugeIcons.strokeRoundedLayers01,
                ),
                SubscriptionSwitchOption(
                  label: labels[1],
                  icon: HugeIcons.strokeRoundedArrowReloadVertical,
                ),
              ],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(SubscriptionSegmentedSwitch)).width;
    }

    final compactWidth = await pumpSwitch(['All', 'Updates']);
    final localizedWidth = await pumpSwitch(['全部已安装项目', '存在可用更新的项目']);

    expect(localizedWidth, greaterThan(compactWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull-progress ink drop keeps its animation ticker enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SkillsLoadingShape(progress: .45)),
    );

    final tickerMode = tester.widget<TickerMode>(
      find
          .ancestor(
            of: find.byKey(const Key('skills-loading-ink-drop')),
            matching: find.byType(TickerMode),
          )
          .first,
    );
    expect(tickerMode.enabled, isTrue);
  });

  testWidgets('follows the system locale and renders Simplified Chinese', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(language: AppLanguage.system)),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现'), findsOneWidget);
    expect(find.text('已安装'), findsOneWidget);
    expect(find.text('多会一点，总是好的。'), findsNothing);
    expect(find.text('搜索技能或粘贴 Git 链接…'), findsOneWidget);

    for (final route in const {
      '排行': '历史排行',
      '趋势': '最近 24 小时趋势',
      '热门': '当前热门',
    }.entries) {
      await tester.tap(find.text(route.key));
      await tester.pumpAndSettle();
      expect(_isSemanticallySelected(tester, route.key), isTrue);
    }

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.text('搜索已安装技能'), findsOneWidget);
    expect(find.text('搜索技能或粘贴 Git 链接…'), findsNothing);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final localizedPresets = tester
        .widget<BloomColorPicker>(find.byType(BloomColorPicker))
        .presets
        .map((preset) => preset.name)
        .toSet();
    expect(localizedPresets, containsAll(['网易云音乐', '中国东方航空', '英伟达', '淘宝']));
    expect(localizedPresets, containsAll(['GitHub', 'levels.fyi', 'Figma']));
  });

  testWidgets('compact primary capsule optically centers its Chinese label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          language: AppLanguage.simplifiedChinese,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(PrimaryCapsuleButton, '安装').first;
    final label = find.descendant(of: button, matching: find.text('安装'));
    final paragraph = tester.renderObject<RenderParagraph>(label);
    final glyphBox = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
          boxHeightStyle: BoxHeightStyle.tight,
        )
        .single
        .toRect()
        .shift(tester.getTopLeft(label));

    expect(
      glyphBox.center.dy,
      closeTo(tester.getCenter(button).dy, .5),
      reason: 'The painted Chinese glyphs should sit in the capsule center.',
    );
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
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          cliReady: false,
          language: AppLanguage.system,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('SkillsGo 的必要组件缺失或无法启动。请重新安装 SkillsGo 以恢复该组件。'),
      findsOneWidget,
    );
    expect(find.text('raw process diagnostic'), findsNothing);
  });

  testWidgets('Settings changes and persists the application language', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final discoveryCallsBeforeLanguageChange = gateway.collections.length;
    await tester.tap(find.byKey(const Key('language-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();

    expect(gateway.language, AppLanguage.simplifiedChinese);
    expect(
      gateway.collections.length,
      greaterThan(discoveryCallsBeforeLanguageChange),
    );
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('设置'), findsWidgets);

    await tester.tap(find.byKey(const Key('language-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(gateway.language, AppLanguage.english);
    expect(find.text('Language'), findsOneWidget);
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
    expect(
      picker.presets.map((preset) => preset.color),
      brandThemePresets.map((preset) => preset.color),
    );
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
    expect(
      tester.getSize(find.byKey(const ValueKey('discrete-tab-Light'))),
      const Size.square(36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('discrete-tab-Dark'))),
      const Size.square(36),
    );

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

  testWidgets('General settings changes and persists the celestial wallpaper', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallpaper-picker')), findsOneWidget);

    final indicator = find.byKey(const Key('wallpaper-selection-indicator'));
    final earth = find.byKey(const ValueKey('wallpaper-earth'));
    await tester.ensureVisible(earth);
    final initialPosition = tester.getTopLeft(indicator);
    final targetPosition = tester.getTopLeft(earth);
    await tester.tap(earth);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final movingPosition = tester.getTopLeft(indicator);
    expect(movingPosition.dx, greaterThan(initialPosition.dx));
    expect(movingPosition.dx, lessThan(targetPosition.dx));
    await tester.pumpAndSettle();
    final settledPosition = tester.getTopLeft(indicator);
    expect(settledPosition.dx, closeTo(targetPosition.dx, .01));
    expect(settledPosition.dy, closeTo(targetPosition.dy, .01));

    expect(gateway.wallpaper, AppWallpaper.earth);
    final background = tester.widget<Image>(
      find.byKey(const Key('app-wallpaper')),
    );
    expect(
      (background.image as AssetImage).assetName,
      'assets/backgrounds/earth-starfield.png',
    );
  });

  testWidgets('Bloom presets reveal their brand name on hover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final picker = find.byType(BloomColorPicker);
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
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

    expect(find.byKey(const ValueKey('discover-results-hot')), findsOneWidget);
    expect(_isSemanticallySelected(tester, 'Hot'), isTrue);
    await tester.enterText(_searchInput(), 'flutter');
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
          skills: FakeSkillsGateway._defaultSearchResults,
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

    await tester.enterText(_searchInput(), 'https://github.com/example/skills');
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
      const DiscoveryPage(skills: FakeSkillsGateway._defaultSearchResults),
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

    await tester.enterText(_searchInput(), 'https://github.com/example/skills');
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
      Theme.of(tester.element(_searchInput())).colorScheme.primary,
    );
    expect(loading.style.transitionDuration, const Duration(milliseconds: 800));
    expect(loading.style.enableHaptics, isFalse);
    expect(loading.style.shapes, hasLength(7));

    pendingSearch.complete(FakeSkillsGateway._defaultSearchResults);
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
      _searchInput(),
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

    await tester.enterText(_searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(_searchInput()).controller.text,
      isEmpty,
    );
    expect(find.byKey(const ValueKey('discover-results-hot')), findsOneWidget);
    expect(_isSemanticallySelected(tester, 'Hot'), isTrue);
  });

  testWidgets('Discover search shifts into query mode and reverses on clear', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('skill-search-input'));
    final restingY = tester.getTopLeft(search).dy;
    await tester.enterText(_searchInput(), 'flutter');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final enteringY = tester.getTopLeft(search).dy;
    expect(enteringY, lessThan(restingY));

    await tester.pumpAndSettle();
    final queryY = tester.getTopLeft(search).dy;
    expect(queryY, lessThan(enteringY));
    await tester.tap(find.byKey(const Key('skill-search-clear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final clearingY = tester.getTopLeft(search).dy;
    expect(clearingY, greaterThan(queryY));
    expect(clearingY, lessThan(restingY));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(search).dy, restingY);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('Discover keeps search in the collection rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('skill-search-input')), findsOneWidget);
    expect(find.byKey(const Key('discovery-options-mode')), findsOneWidget);
    expect(find.text('⌘ F'), findsOneWidget);
    expect(find.byKey(const Key('discovery-search-close')), findsNothing);
    await tester.enterText(_searchInput(), 'flutter');
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
    expect(_isSemanticallySelected(tester, 'Hot'), isTrue);
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

  testWidgets(
    'desktop pull refresh keeps content and uses the ink-drop loader',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final initial = Completer<DiscoveryPage>()
        ..complete(
          const DiscoveryPage(
            skills: [
              SkillSummary(
                id: 'github.com/acme/original',
                installName: 'original',
                name: 'Original',
                source: 'github.com/acme/original',
                installs: 2,
              ),
            ],
          ),
        );
      final refresh = Completer<DiscoveryPage>();
      final gateway = FakeSkillsGateway(
        discoveryCompleters: [initial, refresh],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('discover-results-hot'))),
      );
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(const Offset(0, 55));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Original'), findsOneWidget);
      expect(find.byKey(const Key('discover-refresh-loading')), findsOneWidget);
      expect(find.byKey(const Key('skills-loading-ink-drop')), findsOneWidget);
      expect(
        find.byKey(const Key('skills-loading-progressive-dots')),
        findsNothing,
      );
      expect(gateway.requestedOffsets, [0, 0]);

      refresh.complete(
        const DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/refreshed',
              installName: 'refreshed',
              name: 'Refreshed',
              source: 'github.com/acme/refreshed',
              installs: 3,
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('skills-loading-ink-drop')), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('discover-refresh-opacity')),
            )
            .opacity,
        greaterThan(0),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsNothing);
      expect(find.text('Refreshed'), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('discover-refresh-opacity')),
            )
            .opacity,
        0,
      );
      expect(
        TickerMode.valuesOf(
          tester.element(find.byKey(const Key('discover-refresh-opacity'))),
        ).enabled,
        isTrue,
      );
    },
  );

  testWidgets('installed discovery action never repeats the known target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const installedSkill = SkillSummary(
      id: 'github.com/acme/skills/-/planner',
      installName: 'planner',
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

  testWidgets(
    'installation selector headings share a foreground across themes and seeds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      for (final themeMode in [AppThemeMode.light, AppThemeMode.dark]) {
        for (final seed in ['#FFFFFF', '#5865F2']) {
          final gateway = FakeSkillsGateway(
            installed: false,
            agentNames: const ['codex', 'claude-code'],
            folderTheme: seed,
            themeMode: themeMode,
          );
          await tester.pumpWidget(SkillsGoApp(gateway: gateway));
          await tester.pumpAndSettle();

          final card = find.byType(SkillCard).first;
          await tester.tap(
            find.descendant(of: card, matching: find.text('Install')),
          );
          await tester.pumpAndSettle();

          final installTitle = tester.renderObject<RenderParagraph>(
            find.text('Install Flutter Pro to'),
          );
          final agentsTitle = tester.renderObject<RenderParagraph>(
            find.text('For Agents'),
          );
          expect(
            installTitle.text.style?.color,
            agentsTitle.text.style?.color,
            reason: '$themeMode with $seed seed',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    },
  );

  testWidgets('card installation opens a skeleton before detail resolves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    final detail = Completer<SkillDetail>();
    final gateway = FakeSkillsGateway(
      installed: false,
      detailCompleter: detail,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    final card = find.byType(SkillCard).first;
    await tester.tap(find.descendant(of: card, matching: find.text('Install')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('install-location-skeleton')),
      findsOneWidget,
    );
    expect(find.text('Install Flutter Pro to'), findsOneWidget);
    detail.complete(FakeSkillsGateway.defaultRemoteDetail);
    await tester.pumpAndSettle();
    expect(find.text('All projects'), findsOneWidget);
  });

  testWidgets(
    'failed card installation keeps the selector open and shows a stacked toast',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        installPlanErrors: const [
          SkillsException(
            'local lock is incompatible',
            kind: SkillsFailureKind.invalidLocalData,
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final card = find.byType(SkillCard).first;
      await tester.tap(
        find.descendant(of: card, matching: find.text('Install')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Install Flutter Pro to'), findsOneWidget);
      expect(find.text('Installation could not be completed'), findsOneWidget);
      expect(
        find.textContaining('local installation information is damaged'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('detail-back')), findsNothing);
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
    final summary = tester.widget<Text>(
      find.byKey(const Key('detail-description-markdown')),
    );
    expect(summary.maxLines, 3);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(
      find.text(FakeSkillsGateway.defaultRemoteDetail.description),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-sticky-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('detail-scroll-view')), findsOneWidget);
    expect(find.byKey(const Key('detail-compact-identity')), findsNothing);
    expect(find.byKey(const Key('detail-hero-install')), findsOneWidget);
    expect(
      tester
          .widget<PrimaryCapsuleButton>(
            find.byKey(const Key('detail-hero-install')),
          )
          .onPressed,
      isNotNull,
    );
    expect(gateway.agentInspections, 1);
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
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AgentLogo && widget.agentId == 'codex',
      ),
      findsOneWidget,
    );
    expect(find.text('v1.2.3'), findsOneWidget);

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
      expect(find.byKey(const Key('detail-instructions')), findsOneWidget);
      expect(_searchInput(), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('discover-detail-motion'))),
        tester.getTopLeft(find.byKey(const Key('discover-body-stack'))),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('discover-detail-motion'))),
        tester.getSize(find.byKey(const Key('discover-body-stack'))),
      );

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

  testWidgets('installation selector keeps explicit project and Agent targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
    const projectC = AddedProject(
      id: 'project-c',
      name: 'Project C',
      path: '/work/project-c',
      accessState: ProjectAccessState.accessible,
    );
    final gateway = FakeSkillsGateway(
      installed: false,
      agentNames: const ['codex', 'claude-code'],
      addedProjects: const [projectA],
      projectsToAdd: const [projectB, projectC],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pump();
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Selected projects'));
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('0 projects · 2 Agents'), findsOneWidget);

    await tester.tap(find.text('Add Project'));
    await tester.pump();
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Project B'), findsOneWidget);
    expect(find.text('Project C'), findsOneWidget);

    await tester.tap(
      find.ancestor(of: find.text('Project A'), matching: find.byType(InkWell)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('3 projects · 2 Agents'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      gateway.lastPlanSelections
          .map(
            (selection) =>
                '${selection.scope.name}:${selection.projectRoot}:${selection.agent}',
          )
          .toList(),
      [
        'project:/work/project-a:codex',
        'project:/work/project-a:claude-code',
        'project:/work/project-b:codex',
        'project:/work/project-b:claude-code',
        'project:/work/project-c:codex',
        'project:/work/project-c:claude-code',
      ],
    );
    expect(gateway.installCalls, 1);
  });

  testWidgets('installation selector does not expose installed target status', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(installed: true);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(_searchInput(), 'installed-target-status');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final card = find.byType(SkillCard).first;
    final cardTopBeforeInstall = tester.getTopLeft(card).dy;
    await tester.tap(find.text('Install').first);
    await tester.pumpAndSettle();
    final discoveryRequestsBeforeInstall = gateway.collections.length;

    expect(find.text('Installed'), findsNothing);
    final confirm = find.widgetWithText(
      PrimaryCapsuleButton,
      'Confirm Installation',
    );
    expect(tester.widget<PrimaryCapsuleButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(gateway.lastPlanSelections, hasLength(1));
    expect(gateway.lastPlanSelections.single.agent, 'codex');
    expect(gateway.lastPlanSelections.single.scope, InstallationScope.user);
    expect(gateway.installCalls, 1);
    expect(gateway.collections, hasLength(discoveryRequestsBeforeInstall));
    expect(tester.getTopLeft(card).dy, cardTopBeforeInstall);
    expect(find.text('Installation complete'), findsOneWidget);
    expect(
      find.text('The Skill is now available in the selected locations.'),
      findsOneWidget,
    );
    final successTextContext = tester.element(
      find.text('Installation complete'),
    );
    expect(
      tester.widget<Text>(find.text('Installation complete')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(
      tester
          .widget<Text>(
            find.text('The Skill is now available in the selected locations.'),
          )
          .style
          ?.fontWeight,
      FontWeight.w400,
    );
    expect(
      DefaultTextStyle.of(successTextContext).style.decoration,
      isNot(TextDecoration.underline),
    );
  });

  testWidgets(
    'confirmed installation overwrites a Local Modification directly',
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

      expect(gateway.installCalls, 1);
      expect(find.text('Installation results'), findsOneWidget);
      expect(find.text('Review Installation Plan'), findsNothing);
      expect(find.byKey(const ValueKey('installation-matrix')), findsNothing);
    },
  );

  testWidgets('the install confirmation also confirms High risk', (
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

    expect(gateway.installCalls, 1);
    expect(find.text('Installation results'), findsOneWidget);
    expect(find.textContaining('risk blocked'), findsNothing);
  });

  testWidgets('Critical risk still follows the Settings policy', (
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

    expect(gateway.installCalls, 0);
    expect(find.text('Review Installation Plan'), findsNothing);
    expect(find.byKey(const ValueKey('installation-matrix')), findsNothing);
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
      updateCheckErrors: const [
        SkillsException(
          'Update check is offline',
          kind: SkillsFailureKind.offline,
          isOffline: true,
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

    expect(find.text('Service temporarily unavailable'), findsOneWidget);
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

    expect(find.byKey(const ValueKey('detail-skeleton')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Loading auditable Skill detail')),
      findsOneWidget,
    );
    expect(find.text('Flutter Pro'), findsOneWidget);
    detail.complete(FakeSkillsGateway.defaultRemoteDetail);
    await tester.pumpAndSettle();
    expect(find.text('Real instructions'), findsOneWidget);
  });

  testWidgets('installation selector only shows detected Agents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      agentStatuses: const [
        AgentStatus(
          id: 'codex',
          displayName: 'Codex',
          installed: true,
          supportedScopes: [InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.codex/skills',
            exists: true,
          ),
          discoveryRoots: [
            '/Users/test/.codex/skills',
            '/Users/test/.agents/skills',
          ],
        ),
        AgentStatus(
          id: 'cursor',
          displayName: 'Cursor',
          installed: false,
          supportedScopes: [InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.cursor/skills',
            exists: false,
          ),
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

    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Cursor'), findsNothing);
  });

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
          installName: 'skill-$index',
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
    await tester.enterText(_searchInput(), 'stateful');
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
      tester.widget<EditableText>(_searchInput()).controller.text,
      'stateful',
    );
    expect(find.text('Flutter Pro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    expect(_isSemanticallySelected(tester, 'Agents'), isTrue);

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
      expect(find.byKey(const ValueKey('discover-skeleton')), findsOneWidget);
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
    await tester.pump();
    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pump(const Duration(milliseconds: 500));

    install.complete(_success(['skillsgo', 'add']));
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
          id: 'example/skills/skill-$index',
          installName: 'skill-$index',
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
    await tester.scrollUntilVisible(
      find.text('Agent 19'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Agent 19').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('library-search')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('Library renders a cold-load skeleton before CLI inspection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final library = Completer<List<InstalledSkill>>();
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(installed: false, libraryCompleter: library),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pump();

    expect(find.byKey(const ValueKey('library-skeleton')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    library.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library identifies malformed CLI data as local', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryError: const SkillsException(
            'invalid local Agent data',
            kind: SkillsFailureKind.invalidLocalData,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('Can’t read an installed skill'), findsOneWidget);
    expect(find.text('SkillsGo needs an update'), findsNothing);
  });

  testWidgets('Library refresh retains the last valid inventory', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);

    final refresh = Completer<List<InstalledSkill>>();
    gateway.libraryCompleter = refresh;
    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(find.text('local-skill'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-skeleton')), findsNothing);
    refresh.completeError(const SkillsException('refresh failed'));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);
  });

  testWidgets('Library clears an Agent filter when that Agent disappears', (
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
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);

    agents.clear();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsNothing);
    expect(find.text('All Agents'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library exposes Global and Added Projects in a location rail', (
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
      projectsToAdd: const [
        AddedProject(
          id: 'bravo',
          name: 'Project Bravo',
          path: '/work/bravo',
          accessState: ProjectAccessState.accessible,
        ),
        AddedProject(
          id: 'charlie',
          name: 'Project Charlie',
          path: '/work/charlie',
          accessState: ProjectAccessState.accessible,
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('All Skills'), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(_libraryLocation('Project Alpha'), findsOneWidget);
    expect(find.byKey(const Key('library-project-filter')), findsNothing);
    final projectScroll = find.byKey(const Key('side-rail-scroll'));
    final projectScrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('side-rail-scrollbar')),
    );
    expect(projectScrollbar.thickness, 2);
    expect(projectScrollbar.radius, const Radius.circular(999));
    expect(
      find.descendant(
        of: projectScroll,
        matching: _libraryLocation('All Skills'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: projectScroll, matching: _libraryLocation('Global')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: _libraryLocation('Project Alpha'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: find.byKey(const ValueKey('side-rail-header-divider')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: find.byKey(const ValueKey('side-rail-footer-divider')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: find.byKey(const Key('library-add-project')),
      ),
      findsNothing,
    );

    await tester.tap(_libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('No Skills yet'), findsOneWidget);
    expect(find.text('Browse Skills'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-add-project')));
    await tester.pumpAndSettle();
    expect(find.text('Project Bravo'), findsWidgets);
    expect(find.text('Project Charlie'), findsWidgets);
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library project rail avoids duplicate macOS scrollbars', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.binding.setSurfaceSize(const Size(1200, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final projects = List.generate(
        16,
        (index) => AddedProject(
          id: 'project-$index',
          name: 'Project $index',
          path: '/work/project-$index',
          accessState: ProjectAccessState.accessible,
        ),
      );

      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(installed: false, addedProjects: projects),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      final explicitScrollbar = find.byKey(const Key('side-rail-scrollbar'));
      expect(explicitScrollbar, findsOneWidget);
      expect(
        find.descendant(
          of: explicitScrollbar,
          matching: find.byType(Scrollbar),
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('empty Added Project links directly to Discover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          addedProjects: const [
            AddedProject(
              id: 'alpha',
              name: 'Project Alpha',
              path: '/work/alpha',
              accessState: ProjectAccessState.accessible,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(_libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('No Skills yet'), findsOneWidget);
    expect(find.text('No Skills found in Project Alpha'), findsNothing);
    expect(
      find.text(
        'This project does not need Git or SkillsGo files. '
        'Install its first Skill when you are ready.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Browse Skills'));
    await tester.pumpAndSettle();

    expect(_isSemanticallySelected(tester, 'Discover'), isTrue);
  });

  testWidgets('Library scrolls only the Added Project list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final projects = List.generate(
      16,
      (index) => AddedProject(
        id: 'project-$index',
        name: 'Project ${index.toString().padLeft(2, '0')}',
        path: '/work/project-$index',
        accessState: ProjectAccessState.accessible,
      ),
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(installed: false, addedProjects: projects),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    final allSkills = _libraryLocation('All Skills');
    final global = _libraryLocation('Global');
    final addProject = find.byKey(const Key('library-add-project'));
    final firstProject = _libraryLocation('Project 00');
    final scroll = find.byKey(const Key('side-rail-scroll'));
    final headerDivider = find.byKey(
      const ValueKey('side-rail-header-divider'),
    );
    final footerDivider = find.byKey(
      const ValueKey('side-rail-footer-divider'),
    );
    final allSkillsTop = tester.getTopLeft(allSkills);
    final globalTop = tester.getTopLeft(global);
    final addProjectTop = tester.getTopLeft(addProject);
    final headerDividerTop = tester.getTopLeft(headerDivider);
    final footerDividerTop = tester.getTopLeft(footerDivider);
    final firstProjectTop = tester.getTopLeft(firstProject);
    final allSkillsButton = find
        .ancestor(of: allSkills, matching: find.byType(TextButton))
        .first;
    final firstProjectButton = find
        .ancestor(of: firstProject, matching: find.byType(TextButton))
        .first;

    expect(tester.getSize(allSkillsButton).height, 44);
    expect(tester.getSize(firstProjectButton).height, 38);
    expect(tester.getSize(addProject).height, 44);

    await tester.tap(firstProject);
    await tester.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('rail-indicator'));
    expect(tester.getSize(indicator).height, 34);
    expect(
      tester.getSize(indicator).width,
      tester.getSize(firstProjectButton).width - 8,
    );

    await tester.drag(scroll, const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(allSkills), allSkillsTop);
    expect(tester.getTopLeft(global), globalTop);
    expect(tester.getTopLeft(addProject), addProjectTop);
    expect(tester.getTopLeft(headerDivider), headerDividerTop);
    expect(tester.getTopLeft(footerDivider), footerDividerTop);
    expect(tester.getTopLeft(firstProject).dy, lessThan(firstProjectTop.dy));
  });

  testWidgets('Library location rail filters Global and Project targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const project = AddedProject(
      id: 'alpha',
      name: 'Project Alpha',
      path: '/work/alpha',
      accessState: ProjectAccessState.accessible,
    );
    const globalSkill = InstalledSkill(
      inventoryKey: 'global-skill',
      name: 'global-skill',
      path: '/Users/test/.codex/skills/global-skill',
      agents: ['codex'],
      targetCount: 1,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: '/Users/test/.codex/skills/global-skill',
          version: 'v1',
        ),
      ],
    );
    const projectSkill = InstalledSkill(
      inventoryKey: 'project-skill',
      name: 'project-skill',
      path: '/work/alpha/.agents/skills/project-skill',
      agents: ['codex'],
      targetCount: 1,
      projects: ['/work/alpha'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work/alpha',
          path: '/work/alpha/.agents/skills/project-skill',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          addedProjects: const [project],
          libraryEntries: const [globalSkill, projectSkill],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('global-skill'), findsOneWidget);
    expect(find.text('project-skill'), findsOneWidget);

    await tester.tap(_libraryLocation('Global'));
    await tester.pumpAndSettle();
    expect(find.text('global-skill'), findsOneWidget);
    expect(find.text('project-skill'), findsNothing);

    await tester.tap(_libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('global-skill'), findsNothing);
    expect(find.text('project-skill'), findsOneWidget);
  });

  testWidgets('inaccessible Project stays visible and supports Relocate', (
    tester,
  ) async {
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
    await tester.tap(_libraryLocation('Moved Project — unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Project directory is missing'), findsOneWidget);
    expect(find.textContaining('/Volumes/offline/project'), findsOneWidget);
    expect(find.textContaining('volume offline'), findsNothing);
    await tester.tap(find.text('Relocate').last);
    await tester.pumpAndSettle();
    expect(find.text('No Skills yet'), findsOneWidget);
    expect(find.text('Browse Skills'), findsOneWidget);
    expect(gateway.projects.single.id, 'stable-id');
    expect(gateway.projects.single.path, '/work/project');

    expect(find.text('Remove from List'), findsNothing);
  });

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
        inventoryKey: 'hub:github.com/acme/skills/-/hub-demo',
        name: 'hub-demo',
        path: '/work/alpha/.agents/skills/hub-demo',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'github.com/acme/skills/-/hub-demo',
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
        inventoryKey: 'local:private',
        name: 'private-local',
        path: '/Users/test/.codex/skills/private-local',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'local.skillsgo/abc/private-local',
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
        reminderSettings: const ReminderSettings(
          updateAvailable: true,
          securityAdvisory: false,
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(_libraryLocation('Project Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Can’t connect to SkillsGo'), findsOneWidget);
      expect(find.text('hub-demo'), findsOneWidget);

      await tester.tap(_libraryLocation('All Skills'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();
      expect(find.text('hub-demo'), findsOneWidget);
      expect(find.text('private-local'), findsOneWidget);
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
        inventoryKey: 'hub:github.com/example/skills/-/demo',
        name: 'demo',
        description: 'Coordinates reliable multi-Agent skill workflows.',
        skillId: 'github.com/example/skills/-/demo',
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

      expect(find.text('Version divergence'), findsNothing);
      expect(find.text('/Users/test/.codex/skills/demo'), findsNothing);
      expect(find.byTooltip('Codex'), findsOneWidget);
      expect(find.byTooltip('Claude Code'), findsNothing);
      expect(_libraryLocation('Project Alpha'), findsOneWidget);
      expect(_libraryLocation('Project Beta'), findsOneWidget);
      expect(
        find.byKey(const Key('library-scope-project-alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library-scope-project-beta')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('library-scope-project-alpha')))
            .dx,
        greaterThan(tester.getTopLeft(find.text('demo').first).dx),
      );
      final projectHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await projectHover.addPointer(
        location: tester.getCenter(
          find.byKey(const Key('library-scope-project-alpha')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('/work/alpha'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('copy-project-path-alpha')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const Key('copy-project-path-copied-alpha')),
        findsOneWidget,
      );
      await projectHover.moveTo(tester.getCenter(find.text('Claude Code')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('/work/alpha'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      await projectHover.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha'), findsNothing);
      expect(find.text('Claude Code'), findsNothing);
      await projectHover.removePointer();
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Cursor'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(_libraryLocation('Project Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Version divergence'), findsNothing);
      await tester.tap(find.text('demo').first);
      await tester.pump();
      final openingDetail = tester.widget<SlideTransition>(
        find.byKey(const Key('library-detail-surface')),
      );
      expect(openingDetail.position.value.dx, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-detail-surface')), findsOneWidget);
      expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('installation-scope-toggle-project:/work/alpha')),
      );
      await tester.tap(find.byKey(const Key('installation-scope-toggle-user')));
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha/.claude/skills/demo'), findsWidgets);
      expect(find.text('/Users/test/.codex/skills/demo'), findsWidgets);
      expect(
        find.byKey(const Key('installed-detail-compact-identity')),
        findsNothing,
      );
      await tester.binding.setSurfaceSize(const Size(1200, 500));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('installed-detail-scroll-view')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('installed-detail-compact-identity')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back to Library'));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpAndSettle();

      final librarySearch = tester.widget<SkillSearchField>(
        find.byKey(const Key('library-search')),
      );
      expect(librarySearch.appearance, SkillSearchAppearance.leaderboard);
      expect(find.byKey(const Key('library-update-filter')), findsOneWidget);
      expect(find.byType(SubscriptionSegmentedSwitch), findsOneWidget);
      expect(find.text('Add Project'), findsOneWidget);
      expect(find.text('Check updates'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
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
        inventoryKey: 'hub:github.com/example/skills/-/demo',
        name: 'demo',
        skillId: 'github.com/example/skills/-/demo',
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

      expect(find.text(path), findsNothing);
      expect(find.text('Target missing'), findsNothing);
      await tester.tap(find.byKey(const Key('installation-scope-toggle-user')));
      await tester.pumpAndSettle();
      expect(find.text(path), findsOneWidget);
      expect(find.text('Target missing'), findsOneWidget);
      expect(find.text('Can’t read this Skill'), findsOneWidget);
    },
  );

  testWidgets(
    'Library selection toolbar springs through entrance, exit, and reversal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            libraryEntries: const [
              InstalledSkill(
                inventoryKey: 'hub:github.com/example/skills/-/demo',
                name: 'demo',
                skillId: 'github.com/example/skills/-/demo',
                path: '/Users/test/.codex/skills/demo',
                agents: ['codex'],
                targetCount: 1,
                versions: ['v1'],
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.user,
                    path: '/Users/test/.codex/skills/demo',
                    version: 'v1',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      final selection = find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      );
      const visibleKey = ValueKey('selection-bar-visible');
      await tester.tap(selection);
      await tester.pump();
      expect(find.byKey(visibleKey), findsOneWidget);
      final selectionBarSwitcher = find.byKey(
        const Key('library-selection-bar-switcher'),
      );
      expect(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(SlideTransition),
        ),
        findsWidgets,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);

      await tester.tap(find.byTooltip('Clear selection'));
      await tester.pump();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsNothing);

      await tester.tap(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear selection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final exitingFade = tester.widget<FadeTransition>(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(FadeTransition),
        ),
      );
      expect(exitingFade.opacity.value, inExclusiveRange(.45, .6));
      await tester.tap(selection);
      await tester.pump();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    },
  );

  testWidgets(
    'Library selection toolbar removes translation for reduced motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            libraryEntries: const [
              InstalledSkill(
                inventoryKey: 'hub:github.com/example/skills/-/demo',
                name: 'demo',
                skillId: 'github.com/example/skills/-/demo',
                path: '/Users/test/.codex/skills/demo',
                agents: ['codex'],
                targetCount: 1,
                versions: ['v1'],
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.user,
                    path: '/Users/test/.codex/skills/demo',
                    version: 'v1',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
        ),
      );
      await tester.pump();

      final selectionBarSwitcher = find.byKey(
        const Key('library-selection-bar-switcher'),
      );
      expect(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('Library select-all follows the current filtered results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    InstalledSkill entry(String name) => InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills/-/$name',
      name: name,
      skillId: 'github.com/example/skills/-/$name',
      path: '/Users/test/.codex/skills/$name',
      agents: const ['codex'],
      targetCount: 1,
      versions: const ['v1'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: '/Users/test/.codex/skills/$name',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryEntries: [entry('alpha'), entry('demo')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    const selectAllKey = Key('library-select-visible');
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isFalse,
    );
    expect(
      tester.getCenter(find.byKey(selectAllKey)).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('search-visual-icon'))).dy + 2,
        1,
      ),
    );
    expect(
      tester.getCenter(find.byKey(selectAllKey)).dx,
      closeTo(
        tester
            .getCenter(
              find.byKey(
                const ValueKey(
                  'library-select-hub:github.com/example/skills/-/demo',
                ),
              ),
            )
            .dx,
        1,
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).indeterminate,
      isTrue,
    );

    await tester.tap(find.byKey(selectAllKey));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isTrue,
    );
    expect(find.text('2 selected'), findsOneWidget);

    final search = find.descendant(
      of: find.byKey(const Key('library-search')),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'demo');
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isTrue,
    );

    await tester.tap(find.byKey(selectAllKey));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isFalse,
    );
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('Target Management removes only the selected healthy target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          skillId: 'github.com/example/skills/-/demo',
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

    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-manage-selected')));
    await tester.pumpAndSettle();
    expect(find.byType(SkillsDialog), findsOneWidget);
    expect(find.text('0 of 2 targets selected'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SkillsDialog),
            matching: find.byType(SkillsCheckbox),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 targets selected'), findsOneWidget);
    await tester.tap(find.text('Apply selected actions'));
    await tester.pumpAndSettle();
    expect(find.text('1 succeeded, 0 failed'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(gateway.managementTargetHistory, hasLength(1));
    expect(gateway.managementTargetHistory.single, hasLength(1));
    expect(
      gateway.managementTargetHistory.single.values.single,
      TargetManagementAction.remove,
    );
    expect(gateway.libraryEntries!.single.targets.single.agent, 'claude-code');
  });

  testWidgets('unhealthy targets offer Repair without Remove', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          skillId: 'github.com/example/skills/-/demo',
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
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-manage-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Repair'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SkillsDialog),
        matching: find.byType(SkillsCheckbox),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Repair'));
    await tester.pumpAndSettle();
    expect(find.text('Stop Managing'), findsNothing);
  });

  testWidgets('Repair restores an unhealthy managed target', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          skillId: 'github.com/example/skills/-/demo',
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
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-manage-selected')));
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

  testWidgets('External Installation stays visible and exposes exact removal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const path = '/Users/test/.codex/skills/external-demo';
    const entry = InstalledSkill(
      inventoryKey: 'external:abc',
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
    await tester.tap(find.byKey(const ValueKey('library-select-external:abc')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    final removeButtonFinder = find.byKey(const Key('library-manage-selected'));
    final removeButton = tester.widget<TextButton>(removeButtonFinder);
    final removeButtonContext = tester.element(removeButtonFinder);
    expect(
      removeButton.style?.foregroundColor?.resolve(const {}),
      removeButtonContext.skillsComponents.statusDangerOnInverse,
    );
    await tester.tap(find.text('external-demo').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('installed-detail-back')), findsOneWidget);
    expect(
      find.byKey(const Key('installed-detail-skill-avatar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('installed-detail-scroll-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('installed-detail-instructions')),
      findsOneWidget,
    );
    expect(find.text(path), findsNothing);
    await tester.tap(find.byTooltip('Show target details'));
    await tester.pumpAndSettle();
    expect(find.text(path), findsOneWidget);
    expect(find.text('scripts/run.sh'), findsNothing);
    expect(find.text('Risk unknown'), findsNothing);
    expect(find.textContaining('scripts or executable content'), findsNothing);

    await tester.tap(find.byTooltip('Back to Library'));
    await tester.pumpAndSettle();
    expect(find.text('external-demo'), findsWidgets);
    expect(find.text('External installation'), findsWidgets);
  });

  testWidgets(
    'Library Batch Takeover follows All, Global, and Project locations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      const path = '/Users/test/.codex/skills/external-demo';
      const alpha = AddedProject(
        id: 'alpha',
        name: 'Alpha',
        description: '',
        path: '/work/alpha',
        accessState: ProjectAccessState.accessible,
      );
      const beta = AddedProject(
        id: 'beta',
        name: 'Beta',
        description: '',
        path: '/work/beta',
        accessState: ProjectAccessState.accessible,
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [alpha, beta],
        libraryEntries: const [
          InstalledSkill(
            inventoryKey: 'external:abc',
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
              ),
            ],
          ),
        ],
        takeoverResult: const BatchTakeoverResult(takenOver: 2, skipped: 1),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      expect(gateway.takeoverRequests, isEmpty);
      expect(find.text('Take over existing skills?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gateway.takeoverRequests, isEmpty);

      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take over'));
      await tester.pumpAndSettle();

      expect(gateway.takeoverRequests, hasLength(1));
      expect(gateway.takeoverRequests.single.includeUser, isTrue);
      expect(gateway.takeoverRequests.single.projectRoots, [
        '/work/alpha',
        '/work/beta',
      ]);
      expect(find.text('2 skills taken over, 1 skipped.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(_libraryLocation('Global'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take over'));
      await tester.pumpAndSettle();
      expect(gateway.takeoverRequests.last.includeUser, isTrue);
      expect(gateway.takeoverRequests.last.projectRoots, isEmpty);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(_libraryLocation('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take over'));
      await tester.pumpAndSettle();
      expect(gateway.takeoverRequests.last.includeUser, isFalse);
      expect(gateway.takeoverRequests.last.projectRoots, ['/work/alpha']);
    },
  );

  testWidgets('Library Batch Takeover publishes next-frame progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final takeover = Completer<BatchTakeoverResult>();
    final gateway = FakeSkillsGateway(
      installed: false,
      takeoverCompleter: takeover,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-batch-takeover')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take over'));
    await tester.pump();

    expect(find.text('Taking over skills…'), findsOneWidget);
    final pendingButton = tester.widget<SecondaryCapsuleButton>(
      find.byKey(const Key('library-batch-takeover')),
    );
    expect(pendingButton.onPressed, isNull);
    expect(
      find.byKey(const Key('primary-destination-settings')),
      findsOneWidget,
    );

    takeover.complete(const BatchTakeoverResult(takenOver: 1, skipped: 0));
    await tester.pumpAndSettle();
    expect(find.text('1 skills taken over, 0 skipped.'), findsOneWidget);
  });

  testWidgets('installed detail presents provenance-specific actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));

    Future<void> open(InstalledSkill entry, {UpdateState? updateState}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            libraryEntries: [entry],
            updateState: updateState ?? UpdateState.available,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.name).first);
      await tester.pumpAndSettle();
    }

    const target = SkillInstallationTarget(
      agent: 'codex',
      scope: InstallationScope.user,
      path: '/Users/test/.codex/skills/action-demo',
      version: 'v1',
    );
    const hub = InstalledSkill(
      inventoryKey: 'hub:github.com/test/skills/-/action-demo',
      name: 'action-demo',
      path: '/Users/test/.codex/skills/action-demo',
      agents: ['codex'],
      targetCount: 1,
      skillId: 'github.com/test/skills/-/action-demo',
      versions: ['v1'],
      targets: [target],
    );
    await open(hub);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Install in more locations'), findsOneWidget);
    await tester.tap(find.byTooltip('Show target details'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'remove-installation-target-/Users/test/.codex/skills/action-demo',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'remove-installation-target-/Users/test/.codex/skills/action-demo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm remove'), findsOneWidget);
    expect(find.text('Manage installation targets'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await open(hub, updateState: UpdateState.upToDate);
    expect(find.text('UP TO DATE'), findsNothing);
    expect(find.text('Update'), findsNothing);

    await open(
      const InstalledSkill(
        inventoryKey: 'local:action-demo',
        name: 'local-action-demo',
        path: '/Users/test/.codex/skills/local-action-demo',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'local.skillsgo/action-demo',
        provenance: LibraryProvenance.local,
        versions: ['v1'],
        targets: [target],
      ),
    );
    expect(find.text('Manage scope'), findsNothing);
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    await open(
      const InstalledSkill(
        inventoryKey: 'external:action-demo',
        name: 'external-action-demo',
        path: '/Users/test/.codex/skills/external-action-demo',
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/Users/test/.codex/skills/external-action-demo',
            version: '',
            mode: InstallationMode.external,
          ),
        ],
      ),
    );
    expect(find.text('Manage installation'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('installed Hub detail stays local-first through Hub failure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    final gateway = FakeSkillsGateway(
      detailErrors: const [
        SkillsException(
          'Hub is offline',
          kind: SkillsFailureKind.offline,
          isOffline: true,
        ),
      ],
      localDetail: const SkillDetail(
        name: 'local-skill',
        source: 'Local cache',
        markdown: '# Available offline',
        immutableVersion: 'v1',
        files: [SkillFile(path: 'SKILL.md', contents: '# Available offline')],
        installationTargets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/tmp/local-skill',
            version: 'v1',
          ),
        ],
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill').first);
    await tester.pumpAndSettle();

    expect(find.text('Available offline'), findsOneWidget);
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    expect(find.text('Service temporarily unavailable'), findsNothing);
    expect(find.text('Can’t connect to SkillsGo'), findsNothing);
    expect(find.text('CHECK FAILED'), findsNothing);
  });

  testWidgets('Hub enrichment preserves installed-detail geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    final remote = Completer<SkillDetail>();
    final gateway = FakeSkillsGateway(detailCompleter: remote);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill').first);
    await tester.pump();
    await tester.pump();

    expect(find.text('Local'), findsOneWidget);
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    final scopeBefore = tester
        .getTopLeft(find.byKey(const Key('installation-scope-panel')))
        .dy;

    remote.complete(FakeSkillsGateway.defaultRemoteDetail);
    await tester.pumpAndSettle();

    expect(find.text('Build reliable Flutter products.'), findsOneWidget);
    final scopeAfter = tester
        .getTopLeft(find.byKey(const Key('installation-scope-panel')))
        .dy;
    expect(scopeAfter, scopeBefore);
  });

  testWidgets('Local Skill installs to one more exact Agent target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const skillId = 'local.skillsgo/abc/private-demo';
    const path = '/Users/test/.codex/skills/private-demo';
    final gateway = FakeSkillsGateway(
      installed: false,
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'local:$skillId',
          name: 'private-demo',
          path: path,
          agents: ['codex'],
          targetCount: 1,
          skillId: skillId,
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
    await tester.tap(find.text('Install in more locations'));
    await tester.pumpAndSettle();

    expect(find.text('Installed'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pumpAndSettle();

    expect(gateway.executionSelectionHistory.single.single.agent, 'cursor');
    expect(gateway.libraryEntries!.single.agents, ['codex', 'cursor']);
    expect(find.text('Global / Cursor · local-abc'), findsOneWidget);
  });

  testWidgets('leaderboard tabs change selection without moving layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final indicator = find.byKey(const Key('discover-tab-indicator'));
    final hotIndicatorX = tester.getTopLeft(indicator).dx;
    final rankingX = tester
        .getTopLeft(find.byKey(const ValueKey('discover-tab-ranking')))
        .dx;
    await tester.tap(find.text('Ranking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final movingIndicatorX = tester.getTopLeft(indicator).dx;
    expect(movingIndicatorX, lessThan(hotIndicatorX));
    expect(movingIndicatorX, greaterThan(rankingX));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(indicator).dx, closeTo(rankingX, 0.01));
    expect(_isSemanticallySelected(tester, 'Ranking'), isTrue);
    expect(find.text('It’s nice to know a little more.'), findsNothing);
    expect(find.byKey(const Key('discovery-options-mode')), findsOneWidget);
  });

  testWidgets('reduced motion keeps tab selection immediate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ranking'));
    await tester.pump();

    final rankingSemantics = find.bySemanticsLabel('Ranking');
    expect(
      List.generate(
        rankingSemantics.evaluate().length,
        (index) => tester.getSemantics(rankingSemantics.at(index)),
      ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue),
      isTrue,
    );
  });

  testWidgets('keyboard focus can activate the first leaderboard tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_isSemanticallySelected(tester, 'Ranking'), isTrue);
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
    await tester.ensureVisible(find.text('Save & detect'));
    await tester.tap(find.text('Save & detect'));
    await tester.pumpAndSettle();

    expect(gateway.savedPath, '/custom/skills');
  });

  testWidgets('Settings secondary body enters with a short depth motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
    await tester.pump();

    final body = find.byKey(const Key('skills-destination-body'));
    final fade = tester.widget<FadeTransition>(body);
    final slide = fade.child! as SlideTransition;
    final scale = slide.child! as ScaleTransition;
    expect(find.byKey(const Key('update-reminder-label')), findsOneWidget);
    expect(fade.opacity.value, closeTo(.86, .001));
    expect(slide.position.value.dy, closeTo(.012, .001));
    expect(scale.scale.value, closeTo(.985, .001));

    await tester.pump(const Duration(milliseconds: 90));
    expect(fade.opacity.value, inExclusiveRange(.86, 1));
    expect(scale.scale.value, inExclusiveRange(.985, 1));

    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(slide.position.value, Offset.zero);
    expect(scale.scale.value, 1);
  });

  testWidgets('Settings secondary body skips motion when animations are off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
    await tester.pump();

    final body = find.byKey(const Key('skills-destination-body'));
    expect(body, findsOneWidget);
    expect(tester.widget(body), isA<KeyedSubtree>());
    expect(find.byKey(const Key('update-reminder-label')), findsOneWidget);
  });

  testWidgets('Settings keeps infrequent controls behind one advanced route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    final settingsRail = find.byWidgetPredicate(
      (widget) => widget is SkillsSideRail,
      description: 'settings side rail',
    );
    expect(
      find.descendant(of: settingsRail, matching: find.byType(HugeIcon)),
      findsNWidgets(4),
    );
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Reminder settings'), findsNothing);
    expect(find.text('Choose which reminders to receive.'), findsNothing);
    final updateReminderLabel = tester.widget<Text>(
      find.byKey(const Key('update-reminder-label')),
    );
    final securityReminderLabel = tester.widget<Text>(
      find.byKey(const Key('security-reminder-label')),
    );
    expect(
      updateReminderLabel.textSpan!.toPlainText(),
      'Update reminders  Check for updates when Library opens.',
    );
    expect(
      securityReminderLabel.textSpan!.toPlainText(),
      'High-risk alerts  Notify you of new High or Critical risks in installed skills.',
    );
    expect(updateReminderLabel.maxLines, 1);
    expect(securityReminderLabel.maxLines, 1);
    expect(find.byKey(const Key('update-reminder')), findsOneWidget);
    expect(find.byKey(const Key('security-reminder')), findsOneWidget);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Hub Origin'), findsOneWidget);
    expect(find.text('Personal risk policy'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Storage'), findsNothing);
    expect(find.text('Color Scheme'), findsNothing);
    expect(find.text('About'), findsNothing);
  });

  testWidgets(
    'Advanced Settings can restart Onboarding without clearing data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway();
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('primary-destination-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('restart-onboarding')));
      await tester.tap(find.byKey(const Key('restart-onboarding')));
      await tester.pumpAndSettle();

      expect(gateway.onboardingResets, 1);
      expect(find.text('Welcome to SkillsGo'), findsOneWidget);
    },
  );

  testWidgets('reminder settings persist and drive the Library update prompt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      reminderSettings: const ReminderSettings(),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-update-reminder')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-update-reminder')));
    await tester.pumpAndSettle();
    expect(find.text('Updates'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-reminder')));
    await tester.pumpAndSettle();
    expect(gateway.reminderSettings.updateAvailable, isFalse);
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
          discoveryRoots: [
            '/Users/test/.codex/skills',
            '/Users/test/.agents/skills',
          ],
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

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Cursor'), findsOneWidget);
    expect(find.text('Installed · 1'), findsOneWidget);
    expect(find.text('Not installed · 1'), findsOneWidget);
    expect(find.byKey(const Key('installed-agents-group')), findsOneWidget);
    expect(find.byKey(const Key('not-installed-agents-group')), findsOneWidget);
    expect(find.byType(AgentLogo), findsNWidgets(2));
    expect(find.textContaining('/Users/test/.codex/skills'), findsOneWidget);
    expect(find.textContaining('/Users/test/.agents/skills'), findsOneWidget);
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

  testWidgets('Agents exposes CLI recovery when the runtime is missing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(cliReady: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget);
    expect(find.text('INCOMPATIBLE'), findsNothing);
    expect(
      find.textContaining('required SkillsGo component is missing'),
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
    await tester.tap(find.text('Advanced'));
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
    await tester.tap(find.text('Advanced'));
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
      await tester.tap(find.text('Advanced'));
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
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-hub:github.com/test/skills/-/local-skill',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('library-update-selected')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Update Plan changes only explicitly selected targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/user/local-skill',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          skillId: 'github.com/test/skills/-/local-skill',
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
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-hub:github.com/test/skills/-/local-skill',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-update-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Select targets to update'), findsOneWidget);
    expect(find.text('2 of 2 updateable targets selected'), findsOneWidget);
    expect(find.textContaining('/tmp/project/skillsgo.mod'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SkillsDialog),
            matching: find.byType(SkillsCheckbox),
          )
          .at(1),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 updateable targets selected'), findsOneWidget);
    expect(find.textContaining('/tmp/project/skillsgo.mod'), findsNothing);
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();

    expect(gateway.updateTargetHistory, hasLength(1));
    expect(gateway.updateTargetHistory.single, hasLength(1));
    expect(gateway.updateTargetHistory.single.single, contains('codex'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
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
          inventoryKey: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/user/local-skill',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          skillId: 'github.com/test/skills/-/local-skill',
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
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-hub:github.com/test/skills/-/local-skill',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-update-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();

    expect(find.text('Retry 1 Failed Update'), findsOneWidget);
    expect(
      find.text(
        'This location could not be updated. Other locations were not affected, so you can retry only this one.',
      ),
      findsOneWidget,
    );
    expect(find.text('Target is not writable.'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(find.text('Target is not writable.'), findsOneWidget);
    expect(gateway.updateTargetHistory.first, hasLength(2));
    await tester.tap(find.text('Retry 1 Failed Update'));
    await tester.pumpAndSettle();

    expect(gateway.updateTargetHistory, hasLength(2));
    expect(gateway.updateTargetHistory.last, hasLength(1));
    expect(gateway.updateTargetHistory.last.single, contains('claude-code'));
    expect(find.text('Retry 1 Failed Update'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Version divergence'), findsNothing);
  });

  testWidgets('installed detail refreshes target versions after update', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/local-skill',
          agents: ['codex'],
          targetCount: 1,
          skillId: 'github.com/test/skills/-/local-skill',
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
    expect(find.text('Global / Codex · v1'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Global / Codex · v2'), findsOneWidget);
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
      expect(gateway.installCalls, 1);
      await tester.tap(
        find.byKey(const ValueKey('primary-destination-library')),
      );
      await tester.pumpAndSettle();
      expect(find.text('local-skill'), findsOneWidget);

      await tester.tap(find.text('Check updates'));
      await tester.pumpAndSettle();
      expect(find.text('UPDATE'), findsNothing);
      await tester.tap(find.text('local-skill').first);
      await tester.pumpAndSettle();
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
    this.onboardingState = const OnboardingState(
      completed: true,
      step: OnboardingStep.projects,
    ),
    List<Object> onboardingLoadErrors = const [],
    this.onboardingStepSaveCompleter,
    this.cliReady = true,
    this.installed = true,
    this.searchCompleter,
    this.installCompleter,
    this.libraryCompleter,
    List<SkillSummary>? searchResults,
    this.agentNames = const ['codex'],
    this.agentStatuses,
    this.agentInspectionError,
    this.libraryError,
    List<AddedProject> addedProjects = const [],
    this.projectLoadCompleter,
    AddedProject? projectToAdd,
    List<AddedProject>? projectsToAdd,
    this.projectToRelocate,
    List<InstalledSkill>? libraryEntries,
    this.localDetailError,
    this.localDetail,
    this.hubOrigin = 'https://hub.skillsgo.ai',
    this.folderTheme = 'manila',
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.english,
    this.wallpaper = AppWallpaper.sun,
    this.hubTestState = HealthState.ready,
    this.storageStatus = const StorageStatus(
      path: '/Users/test/.skillsgo/store',
      state: HealthState.ready,
    ),
    this.appVersion = '1.0.0',
    this.discoveryPages = const {},
    List<Completer<DiscoveryPage>> discoveryCompleters = const [],
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
    List<SkillsException> updateCheckErrors = const [],
    this.updateState = UpdateState.available,
    this.takeoverResult = const BatchTakeoverResult(takenOver: 0, skipped: 0),
    this.takeoverCompleter,
    this.reminderSettings = const ReminderSettings(
      updateAvailable: false,
      securityAdvisory: false,
    ),
  }) : searchResults = searchResults ?? _defaultSearchResults,
       remoteDetail =
           remoteDetail ??
           (installed
               ? defaultRemoteDetail
               : _withoutInstallationTargets(defaultRemoteDetail)),
       detailErrors = List.of(detailErrors),
       installPlanErrors = List.of(installPlanErrors),
       updateCheckErrors = List.of(updateCheckErrors),
       discoveryCompleters = List.of(discoveryCompleters),
       libraryEntries = libraryEntries == null ? null : List.of(libraryEntries),
       onboardingLoadErrors = List.of(onboardingLoadErrors),
       projectsToAdd = List.of(
         projectsToAdd ??
             (projectToAdd == null ? const [] : <AddedProject>[projectToAdd]),
       ),
       projects = List.of(addedProjects);
  OnboardingState onboardingState;
  final List<Object> onboardingLoadErrors;
  final Completer<void>? onboardingStepSaveCompleter;
  int onboardingCompletions = 0;
  int onboardingResets = 0;
  final bool cliReady;
  final Completer<List<SkillSummary>>? searchCompleter;
  final Completer<CommandResult>? installCompleter;
  Completer<List<InstalledSkill>>? libraryCompleter;
  final Completer<SkillDetail>? detailCompleter;
  final List<String> agentNames;
  final List<AgentStatus>? agentStatuses;
  final SkillsException? agentInspectionError;
  final SkillsException? libraryError;
  final List<AddedProject> projectsToAdd;
  final AddedProject? projectToRelocate;
  final Completer<List<AddedProject>>? projectLoadCompleter;
  List<InstalledSkill>? libraryEntries;
  final SkillsException? localDetailError;
  final SkillDetail? localDetail;
  final List<AddedProject> projects;
  int projectLoads = 0;
  String hubOrigin;
  String folderTheme;
  AppThemeMode themeMode;
  AppLanguage language;
  AppWallpaper wallpaper;
  final HealthState hubTestState;
  PersonalRiskPolicy riskPolicy;
  final String planConflictReason;
  final StorageStatus storageStatus;
  final String appVersion;
  final Map<String, DiscoveryPage> discoveryPages;
  final List<Completer<DiscoveryPage>> discoveryCompleters;
  final SkillsException? discoveryError;
  final Map<String, SkillsException> discoveryErrors;
  final SkillDetail remoteDetail;
  final List<SkillsException> detailErrors;
  final List<Set<String>> installFailures;
  final List<SkillsException> installPlanErrors;
  final List<Set<String>> updateFailures;
  final List<SkillsException> updateCheckErrors;
  final UpdateState updateState;
  final BatchTakeoverResult takeoverResult;
  final Completer<BatchTakeoverResult>? takeoverCompleter;
  ReminderSettings reminderSettings;
  bool installed;
  final queries = <String>[];
  final collections = <DiscoveryCollection>[];
  final requestedOffsets = <int>[];
  int installCalls = 0;

  @override
  Future<OnboardingState> loadOnboardingState() async {
    if (onboardingLoadErrors.isNotEmpty) {
      throw onboardingLoadErrors.removeAt(0);
    }
    return onboardingState;
  }

  @override
  Future<void> saveOnboardingStep(OnboardingStep step) async {
    await onboardingStepSaveCompleter?.future;
    onboardingState = OnboardingState(completed: false, step: step);
  }

  @override
  Future<void> completeOnboarding() async {
    onboardingCompletions++;
    onboardingState = OnboardingState(
      completed: true,
      step: onboardingState.step,
    );
  }

  @override
  Future<void> resetOnboarding() async {
    onboardingResets++;
    onboardingState = const OnboardingState(
      completed: false,
      step: OnboardingStep.welcome,
    );
  }

  int updateCalls = 0;
  List<InstallationTargetSelection> lastPlanSelections = const [];
  final executionSelectionHistory = <List<InstallationTargetSelection>>[];
  final updateTargetHistory = <List<String>>[];
  final managementTargetHistory = <Map<String, TargetManagementAction>>[];
  final takeoverRequests = <({bool includeUser, List<String> projectRoots})>[];
  int exportCalls = 0;
  int detailLoads = 0;
  int agentInspections = 0;
  String? savedPath;
  static const _defaultSearchResults = [
    SkillSummary(
      id: 'example/skills/flutter-pro',
      installName: 'flutter-pro',
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
    stars: 12800,
    sourceUpdatedAt: DateTime.utc(2026, 7, 15),
    archiveSize: 24576,
    description: 'Build reliable Flutter products.',
    markdown: '# Real instructions',
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
  Future<AppWallpaper> loadWallpaper() async => wallpaper;

  @override
  Future<void> saveWallpaper(AppWallpaper value) async => wallpaper = value;

  @override
  Future<AppThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async => themeMode = mode;

  @override
  Future<AppLanguage> loadLanguage() async => language;

  @override
  Future<void> saveLanguage(AppLanguage value) async => language = value;

  @override
  Future<ReminderSettings> loadReminderSettings() async => reminderSettings;

  @override
  Future<void> saveReminderSettings(ReminderSettings value) async {
    reminderSettings = value;
  }

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
    if (discoveryCompleters.isNotEmpty) {
      return discoveryCompleters.removeAt(0).future;
    }
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
  }) async => libraryError != null
      ? throw libraryError!
      : await libraryCompleter?.future ??
            libraryEntries ??
            (installed
                ? [
                    InstalledSkill(
                      inventoryKey: 'hub:github.com/test/skills/-/local-skill',
                      name: 'local-skill',
                      path: '/tmp/local-skill',
                      agents: agentNames,
                      targetCount: agentNames.length,
                      skillId: 'github.com/test/skills/-/local-skill',
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
  Future<AgentCatalog> inspectOnboardingAgents() => inspectAgents();

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
  Future<List<AddedProject>> loadAddedProjects() async {
    projectLoads++;
    return await projectLoadCompleter?.future ?? List.of(projects);
  }

  @override
  Future<AddedProject> resolveProjectIcon(AddedProject project) async =>
      project;
  @override
  Future<List<AddedProject>> addProjects() async {
    for (final project in projectsToAdd) {
      if (!projects.any((item) => item.id == project.id)) {
        projects.add(project);
      }
    }
    return List.of(projectsToAdd);
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
        (skill.inventoryKey.isEmpty ? skill.name : skill.inventoryKey):
            updateState,
    };
  }

  @override
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    final risk = remoteDetail.riskAssessment;
    if ((risk == SkillRiskAssessment.high && !confirmRisk) ||
        (risk == SkillRiskAssessment.critical &&
            (!confirmRisk || !allowCritical))) {
      throw const SkillsException(
        'Risk confirmation is required.',
        kind: SkillsFailureKind.validation,
      );
    }
    if (installPlanErrors.isNotEmpty) throw installPlanErrors.removeAt(0);
    installCalls++;
    lastPlanSelections = List.unmodifiable(selections);
    executionSelectionHistory.add(List.unmodifiable(selections));

    var forceAllFailed = false;
    var failureDiagnostic = '';
    if (installCompleter != null) {
      final command = await installCompleter!.future;
      forceAllFailed = !command.succeeded;
      failureDiagnostic = command.output.stderr;
    }
    final configuredFailures = installCalls <= installFailures.length
        ? installFailures[installCalls - 1]
        : const <String>{};
    final results = selections
        .map((selection) {
          final failed =
              forceAllFailed || configuredFailures.contains(selection.agent);
          return InstallationTargetResult(
            target: InstallationPlanTarget(
              scope: selection.scope,
              projectRoot: selection.projectRoot,
              agent: selection.agent,
              mode: selection.mode,
              path: selection.scope == InstallationScope.user
                  ? '/Users/test/.${selection.agent}/skills/${skill.installName}'
                  : '${selection.projectRoot}/.agents/skills/${skill.installName}',
            ),
            action: planConflictReason.isEmpty
                ? InstallationPlanAction.create
                : InstallationPlanAction.replace,
            outcome: failed
                ? InstallationTargetOutcome.failed
                : InstallationTargetOutcome.succeeded,
            error: failed
                ? TargetFailure(
                    code: 'installation.target_failed',
                    retryable: true,
                    diagnostic: failureDiagnostic,
                  )
                : null,
          );
        })
        .toList(growable: false);
    final succeeded = results
        .where(
          (result) => result.outcome == InstallationTargetOutcome.succeeded,
        )
        .length;
    final failed = results.length - succeeded;
    installed = succeeded > 0;
    final entries = libraryEntries;
    if (entries != null && succeeded > 0) {
      final index = entries.indexWhere((entry) => entry.skillId == skill.id);
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
              version: immutableVersion,
              mode: result.target.mode,
            ),
          );
        }
        entries[index] = existing.withTargets(targets);
      }
    }
    return InstallationExecution(
      skillId: skill.id,
      version: immutableVersion,
      name: skill.installName,
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
  Future<BatchTakeoverResult> takeoverExistingSkills({
    required bool includeUser,
    List<String> projectRoots = const [],
  }) async {
    takeoverRequests.add((
      includeUser: includeUser,
      projectRoots: List.unmodifiable(projectRoots),
    ));
    if (takeoverCompleter != null) return takeoverCompleter!.future;
    return takeoverResult;
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
          skillId: skill.skillId,
          version: target.version,
          health: target.health,
          allowedActions: target.health == InstallationHealth.healthy
              ? const [TargetManagementAction.remove]
              : const [TargetManagementAction.repair],
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
          skillId: item.skillId,
          version: item.version,
          action: item.action!,
          state: InstallationProgressState.started,
        ),
      );
      final result = TargetManagementResult(
        target: item.target,
        name: item.name,
        skillId: item.skillId,
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
          skillId: item.skillId,
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
            if (action == TargetManagementAction.remove) {
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
          skillId: skill.skillId,
          sourceRef: 'main',
          fromVersion: target.version,
          toVersion: 'v2',
          action: UpdatePlanAction.update,
          stateToken: 'state-${target.agent}-${target.path}',
          workspaceManifestChange: target.scope == InstallationScope.project,
        ),
    ];
    return UpdatePlan(
      targets: items,
      workspaceManifestChanges: [
        for (final item in items)
          if (item.workspaceManifestChange)
            WorkspaceManifestChange(
              projectRoot: item.target.projectRoot,
              path: '${item.target.projectRoot}/skillsgo.mod',
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
          skillId: item.skillId,
          fromVersion: item.fromVersion,
          toVersion: item.toVersion,
          state: InstallationProgressState.started,
        ),
      );
      final failed = configuredFailures.contains(item.target.agent);
      final result = UpdateTargetResult(
        target: item.target,
        name: item.name,
        skillId: item.skillId,
        fromVersion: item.fromVersion,
        toVersion: item.toVersion,
        outcome: failed
            ? UpdateTargetOutcome.failed
            : UpdateTargetOutcome.succeeded,
        error: failed
            ? const TargetFailure(
                code: 'update.target_failed',
                retryable: true,
                diagnostic: 'Target is not writable.',
              )
            : null,
      );
      results.add(result);
      onProgress?.call(
        UpdateTargetProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          skillId: item.skillId,
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
  of: find.byKey(const Key('skill-search-input')),
  matching: find.byType(EditableText),
);

Finder _librarySearchInput() => find.descendant(
  of: find.byKey(const Key('library-search')),
  matching: find.byType(EditableText),
);

Finder _libraryLocation(String label) => find.descendant(
  of: find.byKey(const Key('library-location-rail')),
  matching: find.text(label),
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
