/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Locale, folder theme, appearance mode, wallpaper, and Bloom preset behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui' show BoxHeightStyle, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/bloom_color_picker/bloom_color_picker.dart';
import 'package:skillsgo/ui/brand_theme_presets.dart';
import 'package:skillsgo/ui/native_components.dart';
import 'package:skillsgo/ui/primary_folder_shell.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
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
      expect(isSemanticallySelected(tester, route.key), isTrue);
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

  testWidgets('follows an Arabic system locale and renders right to left', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(language: AppLanguage.system)),
    );
    await tester.pumpAndSettle();

    final discover = find.text('اكتشف');
    expect(discover, findsOneWidget);
    expect(Directionality.of(tester.element(discover)), TextDirection.rtl);
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

  testWidgets('language menu keeps long native names on one line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(language: AppLanguage.portugueseBrazil),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    final portuguese = tester.widget<Text>(find.text('Português (Brasil)'));
    expect(portuguese.maxLines, 1);
    expect(portuguese.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.text('Português (Brasil)')).height,
      lessThan(24),
    );
    expect(tester.getSize(find.byKey(const Key('language-picker'))).width, 232);
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
      expect(isSemanticallySelected(tester, destination.value), isTrue);
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
    expect(shellBrightness(tester), Brightness.dark);
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
    expect(shellBrightness(tester), Brightness.light);
    expect(find.text('Light'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discrete-tab-Dark')));
    await tester.pumpAndSettle();
    expect(gateway.themeMode, AppThemeMode.dark);
    expect(shellBrightness(tester), Brightness.dark);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discrete-tab-System')));
    await tester.pumpAndSettle();
    expect(gateway.themeMode, AppThemeMode.system);
    expect(shellBrightness(tester), Brightness.dark);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpAndSettle();
    expect(shellBrightness(tester), Brightness.light);
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

    expect(shellBrightness(tester), Brightness.light);
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
      contrastRatio(folder.style.folderColor, theme.colorScheme.onSurface),
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
        contrastRatio(folder.style.folderColor, theme.colorScheme.onSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'seed ${gateway.folderTheme}',
      );
      expect(
        folder.style.activeTabColor,
        theme.colorScheme.surfaceContainerHighest,
      );
      expect(
        contrastRatio(folder.style.activeTabColor, theme.colorScheme.onSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'active tab for seed ${gateway.folderTheme}',
      );
    }
  });
}
