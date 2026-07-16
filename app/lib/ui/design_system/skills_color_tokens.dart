/*
 * [INPUT]: Depends on Flutter ThemeExtension and resolved primitive/accent colors from the SkillsGo theme builder.
 * [OUTPUT]: Provides Primer-inspired semantic colors for canvas, Folder hierarchy, surfaces, foregrounds, borders, and interactions.
 * [POS]: Serves as the stable color interface consumed by SkillsGo product widgets independently of palette implementation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

const primerPrimitivesVersion = '11.9.0';
const primerPrimitivesIntegrity =
    'sha512-yESOalhd7s7S3unV1V32v3Z0RszXiiz6pzy6hVI9xpdTh1q1'
    'Gt8vyDFxRlqIvuwc5ZaO1+gYQTDbjxb4nWBzMw==';
const primerPrimitivesSource =
    'https://www.npmjs.com/package/@primer/primitives/v/11.9.0';

@immutable
class SkillsColorTokens extends ThemeExtension<SkillsColorTokens> {
  const SkillsColorTokens({
    required this.canvas,
    required this.folderBody,
    required this.folderTabInactive,
    required this.surfaceDefault,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.surfaceInset,
    required this.foregroundDefault,
    required this.foregroundMuted,
    required this.foregroundSubtle,
    required this.borderDefault,
    required this.borderMuted,
    required this.accent,
    required this.accentHover,
    required this.accentMuted,
    required this.onAccent,
    required this.shadow,
  });

  final Color canvas;
  final Color folderBody;
  final Color folderTabInactive;
  final Color surfaceDefault;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color surfaceInset;
  final Color foregroundDefault;
  final Color foregroundMuted;
  final Color foregroundSubtle;
  final Color borderDefault;
  final Color borderMuted;
  final Color accent;
  final Color accentHover;
  final Color accentMuted;
  final Color onAccent;
  final Color shadow;

  @override
  SkillsColorTokens copyWith({
    Color? canvas,
    Color? folderBody,
    Color? folderTabInactive,
    Color? surfaceDefault,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? surfaceInset,
    Color? foregroundDefault,
    Color? foregroundMuted,
    Color? foregroundSubtle,
    Color? borderDefault,
    Color? borderMuted,
    Color? accent,
    Color? accentHover,
    Color? accentMuted,
    Color? onAccent,
    Color? shadow,
  }) => SkillsColorTokens(
    canvas: canvas ?? this.canvas,
    folderBody: folderBody ?? this.folderBody,
    folderTabInactive: folderTabInactive ?? this.folderTabInactive,
    surfaceDefault: surfaceDefault ?? this.surfaceDefault,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceInset: surfaceInset ?? this.surfaceInset,
    foregroundDefault: foregroundDefault ?? this.foregroundDefault,
    foregroundMuted: foregroundMuted ?? this.foregroundMuted,
    foregroundSubtle: foregroundSubtle ?? this.foregroundSubtle,
    borderDefault: borderDefault ?? this.borderDefault,
    borderMuted: borderMuted ?? this.borderMuted,
    accent: accent ?? this.accent,
    accentHover: accentHover ?? this.accentHover,
    accentMuted: accentMuted ?? this.accentMuted,
    onAccent: onAccent ?? this.onAccent,
    shadow: shadow ?? this.shadow,
  );

  @override
  SkillsColorTokens lerp(covariant SkillsColorTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SkillsColorTokens(
      canvas: mix(canvas, other.canvas),
      folderBody: mix(folderBody, other.folderBody),
      folderTabInactive: mix(folderTabInactive, other.folderTabInactive),
      surfaceDefault: mix(surfaceDefault, other.surfaceDefault),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceInset: mix(surfaceInset, other.surfaceInset),
      foregroundDefault: mix(foregroundDefault, other.foregroundDefault),
      foregroundMuted: mix(foregroundMuted, other.foregroundMuted),
      foregroundSubtle: mix(foregroundSubtle, other.foregroundSubtle),
      borderDefault: mix(borderDefault, other.borderDefault),
      borderMuted: mix(borderMuted, other.borderMuted),
      accent: mix(accent, other.accent),
      accentHover: mix(accentHover, other.accentHover),
      accentMuted: mix(accentMuted, other.accentMuted),
      onAccent: mix(onAccent, other.onAccent),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension SkillsThemeColors on BuildContext {
  SkillsColorTokens get skillsColors =>
      Theme.of(this).extension<SkillsColorTokens>()!;
}
