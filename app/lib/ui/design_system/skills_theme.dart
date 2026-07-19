/*
 * [INPUT]: Depends on Flutter Material 3 color generation, platform-localized system typography, Radix Sand primitives, and SkillsGo semantic color and typography tokens.
 * [OUTPUT]: Provides the single theme-building interface for seed-aware Light and Dark SkillsGo themes, including inverse-neutral primary actions for near-white Light seeds, with system-font-first semantic typography.
 * [POS]: Serves as the deep theme module that maps stable product semantics onto Flutter Material roles.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import 'radix_palette.dart';
import 'skills_color_tokens.dart';
import 'skills_component_tokens.dart';
import 'skills_typography.dart';

ThemeData buildSkillsTheme(
  Color seed, {
  Brightness brightness = Brightness.dark,
}) {
  final accentScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final dark = brightness == Brightness.dark;
  final sand = dark ? SkillsRadixSand.dark : SkillsRadixSand.light;
  final status = dark ? SkillsRadixStatus.dark : SkillsRadixStatus.light;
  final useInverseNeutralAccent =
      !dark &&
      seed.computeLuminance() >= .95 &&
      HSLColor.fromColor(seed).saturation <= .06;
  final resolvedAccent = useInverseNeutralAccent
      ? SkillsRadixSand.light[11]
      : accentScheme.primary;
  final resolvedOnAccent = useInverseNeutralAccent
      ? SkillsRadixSand.light[0]
      : accentScheme.onPrimary;
  final accentHoverOverlay = useInverseNeutralAccent ? sand[0] : sand[11];

  // Primer Primitives 11.9.0 supplies the semantic model used here:
  // bgColor-default for the main content plane, bgColor-muted for secondary
  // grouping, bgColor-inset for recessed regions, fgColor-default/muted for
  // text hierarchy, and borderColor-default/muted for structure. SkillsGo
  // maps those roles onto Radix Sand rather than copying GitHub brand values,
  // then adds Folder-specific spatial roles above that semantic vocabulary.
  final tokens = SkillsColorTokens(
    canvas: sand[0],
    folderBody: sand[1],
    folderTabInactive: sand[2],
    surfaceDefault: sand[1],
    surfaceMuted: sand[2],
    surfaceRaised: dark ? sand[3] : sand[0],
    surfaceInset: dark ? sand[0] : sand[2],
    foregroundDefault: sand[11],
    foregroundMuted: sand[10],
    foregroundSubtle: dark ? sand[9] : sand[8],
    borderDefault: sand[6],
    borderMuted: sand[5],
    accent: resolvedAccent,
    accentHover: Color.alphaBlend(
      accentHoverOverlay.withValues(alpha: .08),
      resolvedAccent,
    ),
    accentMuted: Color.alphaBlend(
      resolvedAccent.withValues(alpha: dark ? .18 : .10),
      sand[1],
    ),
    onAccent: resolvedOnAccent,
    shadow: Colors.black.withValues(alpha: dark ? .42 : .16),
  );
  final components = SkillsComponentTokens(
    controlRest: dark ? sand[2] : sand[1],
    controlHover: dark ? sand[3] : sand[2],
    controlActive: dark ? sand[4] : sand[3],
    controlDisabled: sand[2].withValues(alpha: .54),
    controlForeground: tokens.foregroundDefault,
    controlForegroundDisabled: tokens.foregroundSubtle,
    controlBorder: tokens.borderDefault,
    primaryRest: tokens.accent,
    primaryHover: tokens.accentHover,
    primaryForeground: tokens.onAccent,
    cardRest: dark ? tokens.surfaceMuted : tokens.surfaceRaised,
    cardHover: dark ? sand[3] : sand[2],
    cardBorder: tokens.borderMuted,
    overlay: dark ? sand[2] : sand[0],
    overlayBorder: tokens.borderMuted.withValues(alpha: dark ? 1 : .5),
    overlayBackdrop: (dark ? sand[2] : sand[6]).withValues(alpha: .4),
    navigationRest: tokens.folderTabInactive,
    navigationSelected: tokens.foregroundDefault,
    navigationSelectedForeground: tokens.canvas,
    searchRest: dark ? sand[2] : sand[1],
    searchActive: tokens.accentMuted,
    focusRing: tokens.accent,
    statusAccent: status.accent.foreground,
    statusAccentContainer: status.accent.container,
    statusSuccess: status.success.foreground,
    statusSuccessContainer: status.success.container,
    statusAttention: status.attention.foreground,
    statusAttentionContainer: status.attention.container,
    statusSevere: status.severe.foreground,
    statusSevereContainer: status.severe.container,
    statusDanger: status.danger.foreground,
    statusDangerContainer: status.danger.container,
    statusDangerSolid: status.danger.solid,
    statusDangerOnInverse: dark
        ? SkillsRadixStatus.light.danger.foreground
        : SkillsRadixStatus.dark.danger.solid,
    statusDangerForeground: dark ? sand[0] : Colors.white,
  );
  final scheme = accentScheme.copyWith(
    surface: tokens.canvas,
    surfaceDim: dark ? sand[0] : sand[3],
    surfaceBright: dark ? sand[3] : sand[0],
    surfaceContainerLowest: tokens.surfaceInset,
    surfaceContainerLow: tokens.surfaceDefault,
    surfaceContainer: tokens.surfaceMuted,
    surfaceContainerHigh: tokens.folderTabInactive,
    surfaceContainerHighest: tokens.folderBody,
    onSurface: tokens.foregroundDefault,
    onSurfaceVariant: tokens.foregroundMuted,
    outline: tokens.borderDefault,
    outlineVariant: tokens.borderMuted,
    primary: tokens.accent,
    onPrimary: tokens.onAccent,
    primaryContainer: tokens.accentMuted,
    onPrimaryContainer: tokens.accent,
    inverseSurface: tokens.foregroundDefault,
    onInverseSurface: tokens.canvas,
    shadow: tokens.shadow,
    surfaceTint: Colors.transparent,
  );

  final platformTextTheme = ThemeData(brightness: brightness).textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final typography = SkillsTypography.fromTheme(platformTextTheme, scheme);
  final semanticTextTheme = platformTextTheme.copyWith(
    displayLarge: typography.display,
    displayMedium: typography.display,
    displaySmall: typography.pageTitle,
    headlineLarge: typography.display,
    headlineMedium: typography.pageTitle,
    headlineSmall: typography.pageTitle,
    titleLarge: typography.pageTitle,
    titleMedium: typography.sectionTitle,
    titleSmall: typography.label,
    bodyLarge: typography.body,
    bodyMedium: typography.bodySecondary,
    bodySmall: typography.metadata,
    labelLarge: typography.label,
    labelMedium: typography.metadata,
    labelSmall: typography.caption,
  );
  final baseTheme = ThemeData.from(colorScheme: scheme, useMaterial3: true)
      .copyWith(
        textTheme: semanticTextTheme,
        scaffoldBackgroundColor: tokens.canvas,
        canvasColor: tokens.canvas,
        dividerColor: tokens.borderMuted,
        splashFactory: InkSparkle.splashFactory,
      );
  return baseTheme.copyWith(extensions: [tokens, components, typography]);
}
