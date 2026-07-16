/*
 * [INPUT]: Uses the SkillsGo theme module, semantic color extension, and curated brand seeds.
 * [OUTPUT]: Specifies stable Folder hierarchy, seed-independent neutral surfaces, seed-dependent accents, and readable semantic pairs.
 * [POS]: Serves as the focused contract suite for the SkillsGo design-system interface.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/design_system/radix_palette.dart';
import 'package:skillsgo/ui/native_components.dart';

void main() {
  test('upstream theme sources are pinned to audited releases', () {
    expect(radixColorsVersion, '3.0.0');
    expect(radixColorsIntegrity, startsWith('sha512-'));
    expect(primerPrimitivesVersion, '11.9.0');
    expect(primerPrimitivesIntegrity, startsWith('sha512-'));
    expect(SkillsRadixSand.light.first, const Color(0xFFFDFDFC));
    expect(SkillsRadixSand.light.last, const Color(0xFF21201C));
    expect(SkillsRadixSand.dark.first, const Color(0xFF111110));
    expect(SkillsRadixSand.dark.last, const Color(0xFFEEEEEC));
    expect(SkillsRadixStatus.light.accent.container, const Color(0xFFE6F4FE));
    expect(SkillsRadixStatus.light.accent.solid, const Color(0xFF0D74CE));
    expect(SkillsRadixStatus.light.accent.foreground, const Color(0xFF113264));
    expect(SkillsRadixStatus.light.success.solid, const Color(0xFF218358));
    expect(SkillsRadixStatus.light.attention.solid, const Color(0xFFAB6400));
    expect(SkillsRadixStatus.light.severe.solid, const Color(0xFFCC4E00));
    expect(SkillsRadixStatus.light.danger.solid, const Color(0xFFCE2C31));
    expect(SkillsRadixStatus.dark.accent.container, const Color(0xFF0D2847));
    expect(SkillsRadixStatus.dark.accent.solid, const Color(0xFF70B8FF));
    expect(SkillsRadixStatus.dark.accent.foreground, const Color(0xFFC2E6FF));
    expect(SkillsRadixStatus.dark.success.solid, const Color(0xFF3DD68C));
    expect(SkillsRadixStatus.dark.attention.solid, const Color(0xFFFFCA16));
    expect(SkillsRadixStatus.dark.severe.solid, const Color(0xFFFFA057));
    expect(SkillsRadixStatus.dark.danger.solid, const Color(0xFFFF9592));
  });

  for (final brightness in Brightness.values) {
    test('$brightness keeps Folder hierarchy and readable pairs', () {
      final theme = buildSkillsTheme(
        const Color(0xFF9146FF),
        brightness: brightness,
      );
      final colors = theme.extension<SkillsColorTokens>()!;

      expect(colors.folderBody, isNot(colors.folderTabInactive));
      expect(
        _contrastRatio(colors.folderBody, colors.foregroundDefault),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.accent, colors.onAccent),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  test('seed changes accents without repainting neutral Folder surfaces', () {
    final purple = buildSkillsTheme(const Color(0xFF9146FF));
    final green = buildSkillsTheme(const Color(0xFF3FCF8E));
    final purpleColors = purple.extension<SkillsColorTokens>()!;
    final greenColors = green.extension<SkillsColorTokens>()!;

    expect(purpleColors.accent, isNot(greenColors.accent));
    expect(purpleColors.canvas, greenColors.canvas);
    expect(purpleColors.folderBody, greenColors.folderBody);
    expect(purpleColors.surfaceDefault, greenColors.surfaceDefault);
  });

  test('component tokens preserve Primer state progression', () {
    for (final brightness in Brightness.values) {
      final theme = buildSkillsTheme(
        const Color(0xFF5865F2),
        brightness: brightness,
      );
      final components = theme.extension<SkillsComponentTokens>()!;

      expect(components.controlRest, isNot(components.controlHover));
      expect(components.controlHover, isNot(components.controlActive));
      expect(components.cardRest, isNot(components.cardHover));
      expect(components.cardBorder, isNot(components.cardRest));
      expect(components.overlay, isNot(components.overlayBackdrop));
      expect(components.focusRingWidth, 2);
      expect(components.statusSuccess, isNot(components.statusDanger));
      expect(components.statusAttention, isNot(components.statusSevere));
      expect(
        _contrastRatio(components.primaryHover, components.primaryForeground),
        greaterThanOrEqualTo(4.5),
      );
      for (final pair in [
        (components.statusAccentContainer, components.statusAccent),
        (components.statusSuccessContainer, components.statusSuccess),
        (components.statusAttentionContainer, components.statusAttention),
        (components.statusSevereContainer, components.statusSevere),
        (components.statusDangerContainer, components.statusDanger),
      ]) {
        expect(_contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(
        _contrastRatio(
          components.navigationSelected,
          components.navigationSelectedForeground,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          components.statusDanger,
          components.statusDangerForeground,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness primary buttons resolve readable states', (
      tester,
    ) async {
      final theme = buildSkillsTheme(
        const Color(0xFF3FCF8E),
        brightness: brightness,
      );
      final components = theme.extension<SkillsComponentTokens>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: SkillsButton(child: Text('Action'))),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final restBackground = button.style?.backgroundColor?.resolve({});
      final restForeground = button.style?.foregroundColor?.resolve({});
      final hoverBackground = button.style?.backgroundColor?.resolve({
        WidgetState.hovered,
      });
      final hoverForeground = button.style?.foregroundColor?.resolve({
        WidgetState.hovered,
      });

      expect(restBackground, components.primaryRest);
      expect(restForeground, components.primaryForeground);
      expect(hoverBackground, components.primaryHover);
      expect(hoverForeground, components.primaryForeground);
      expect(
        _contrastRatio(restBackground!, restForeground!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(hoverBackground!, hoverForeground!),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}

double _contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = aLuminance > bLuminance ? aLuminance : bLuminance;
  final darker = aLuminance > bLuminance ? bLuminance : aLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
