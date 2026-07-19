/*
 * [INPUT]: Depends on Flutter ThemeExtension, the platform-localized Material TextTheme, and semantic ColorScheme foreground roles.
 * [OUTPUT]: Provides the system-font-first semantic typography contract consumed by SkillsGo UI and reusable components.
 * [POS]: Serves as the global typography layer beside SkillsColorTokens and SkillsComponentTokens in the SkillsGo design system.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

@immutable
class SkillsTypography extends ThemeExtension<SkillsTypography> {
  const SkillsTypography({
    required this.display,
    required this.pageTitle,
    required this.sectionTitle,
    required this.body,
    required this.bodySecondary,
    required this.label,
    required this.metadata,
    required this.caption,
    required this.code,
  });

  factory SkillsTypography.fromTheme(TextTheme textTheme, ColorScheme scheme) =>
      SkillsTypography(
        display: (textTheme.headlineLarge ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontSize: 30,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        pageTitle: (textTheme.headlineSmall ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -.1,
        ),
        sectionTitle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        body: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        bodySecondary: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        label: (textTheme.labelLarge ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        metadata: (textTheme.bodySmall ?? const TextStyle()).copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w400,
          letterSpacing: .05,
        ),
        caption: (textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w400,
          letterSpacing: .1,
        ),
        code: (textTheme.bodySmall ?? const TextStyle()).copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      );

  final TextStyle display;
  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle body;
  final TextStyle bodySecondary;
  final TextStyle label;
  final TextStyle metadata;
  final TextStyle caption;
  final TextStyle code;

  @override
  SkillsTypography copyWith({
    TextStyle? display,
    TextStyle? pageTitle,
    TextStyle? sectionTitle,
    TextStyle? body,
    TextStyle? bodySecondary,
    TextStyle? label,
    TextStyle? metadata,
    TextStyle? caption,
    TextStyle? code,
  }) => SkillsTypography(
    display: display ?? this.display,
    pageTitle: pageTitle ?? this.pageTitle,
    sectionTitle: sectionTitle ?? this.sectionTitle,
    body: body ?? this.body,
    bodySecondary: bodySecondary ?? this.bodySecondary,
    label: label ?? this.label,
    metadata: metadata ?? this.metadata,
    caption: caption ?? this.caption,
    code: code ?? this.code,
  );

  @override
  SkillsTypography lerp(covariant SkillsTypography? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return SkillsTypography(
      display: mix(display, other.display),
      pageTitle: mix(pageTitle, other.pageTitle),
      sectionTitle: mix(sectionTitle, other.sectionTitle),
      body: mix(body, other.body),
      bodySecondary: mix(bodySecondary, other.bodySecondary),
      label: mix(label, other.label),
      metadata: mix(metadata, other.metadata),
      caption: mix(caption, other.caption),
      code: mix(code, other.code),
    );
  }
}

extension SkillsTypographyTheme on BuildContext {
  SkillsTypography get skillsTypography =>
      Theme.of(this).extension<SkillsTypography>()!;
}
