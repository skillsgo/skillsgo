/*
 * [INPUT]: Depends only on Flutter Color values and the vendored Radix Colors 3.0.0 Sand palette.
 * [OUTPUT]: Provides source-pinned immutable Sand scales and Blue, Green, Amber, Orange, and Red status tones for SkillsGo theme construction.
 * [POS]: Serves as the primitive color layer of the SkillsGo design system and is not consumed directly by product widgets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

const radixColorsVersion = '3.0.0';
const radixColorsIntegrity =
    'sha512-FUOsGBkHrYJwCSEtWRCIfQbZG7q1e6DgxCIOe1SUQzDe/'
    '7rXXeA47s8yCn6fuTNQAj1Zq4oTFi9Yjp3wzElcxg==';
const radixSandSource =
    'https://www.npmjs.com/package/@radix-ui/colors/v/3.0.0';

abstract final class SkillsRadixSand {
  /// Exact sRGB values from `sand.css` in `@radix-ui/colors@3.0.0`.
  static const light = <Color>[
    Color(0xFFFDFDFC),
    Color(0xFFF9F9F8),
    Color(0xFFF1F0EF),
    Color(0xFFE9E8E6),
    Color(0xFFE2E1DE),
    Color(0xFFDAD9D6),
    Color(0xFFCFCECA),
    Color(0xFFBCBBB5),
    Color(0xFF8D8D86),
    Color(0xFF82827C),
    Color(0xFF63635E),
    Color(0xFF21201C),
  ];

  /// Exact sRGB values from `sand-dark.css` in
  /// `@radix-ui/colors@3.0.0`.
  static const dark = <Color>[
    Color(0xFF111110),
    Color(0xFF191918),
    Color(0xFF222221),
    Color(0xFF2A2A28),
    Color(0xFF31312E),
    Color(0xFF3B3A37),
    Color(0xFF494844),
    Color(0xFF62605B),
    Color(0xFF6F6D66),
    Color(0xFF7C7B74),
    Color(0xFFB5B3AD),
    Color(0xFFEEEEEC),
  ];
}

@immutable
class SkillsRadixTone {
  const SkillsRadixTone({
    required this.container,
    required this.solid,
    required this.foreground,
  });

  final Color container;
  final Color solid;
  final Color foreground;
}

@immutable
class SkillsRadixStatus {
  const SkillsRadixStatus({
    required this.accent,
    required this.success,
    required this.attention,
    required this.severe,
    required this.danger,
  });

  final SkillsRadixTone accent;
  final SkillsRadixTone success;
  final SkillsRadixTone attention;
  final SkillsRadixTone severe;
  final SkillsRadixTone danger;

  /// Exact steps 3, 11, and 12 sRGB values from the official Blue, Green,
  /// Amber, Orange, and Red scales in `@radix-ui/colors@3.0.0`.
  static const light = SkillsRadixStatus(
    accent: SkillsRadixTone(
      container: Color(0xFFE6F4FE),
      solid: Color(0xFF0D74CE),
      foreground: Color(0xFF113264),
    ),
    success: SkillsRadixTone(
      container: Color(0xFFE6F6EB),
      solid: Color(0xFF218358),
      foreground: Color(0xFF193B2D),
    ),
    attention: SkillsRadixTone(
      container: Color(0xFFFFF7C2),
      solid: Color(0xFFAB6400),
      foreground: Color(0xFF4F3422),
    ),
    severe: SkillsRadixTone(
      container: Color(0xFFFFEFD6),
      solid: Color(0xFFCC4E00),
      foreground: Color(0xFF582D1D),
    ),
    danger: SkillsRadixTone(
      container: Color(0xFFFEEBEC),
      solid: Color(0xFFCE2C31),
      foreground: Color(0xFF641723),
    ),
  );

  /// Exact steps 3, 11, and 12 sRGB values from the official Blue, Green,
  /// Amber, Orange, and Red dark scales in `@radix-ui/colors@3.0.0`.
  static const dark = SkillsRadixStatus(
    accent: SkillsRadixTone(
      container: Color(0xFF0D2847),
      solid: Color(0xFF70B8FF),
      foreground: Color(0xFFC2E6FF),
    ),
    success: SkillsRadixTone(
      container: Color(0xFF132D21),
      solid: Color(0xFF3DD68C),
      foreground: Color(0xFFB1F1CB),
    ),
    attention: SkillsRadixTone(
      container: Color(0xFF302008),
      solid: Color(0xFFFFCA16),
      foreground: Color(0xFFFFE7B3),
    ),
    severe: SkillsRadixTone(
      container: Color(0xFF331E0B),
      solid: Color(0xFFFFA057),
      foreground: Color(0xFFFFE0C2),
    ),
    danger: SkillsRadixTone(
      container: Color(0xFF3B1219),
      solid: Color(0xFFFF9592),
      foreground: Color(0xFFFFD1D9),
    ),
  );
}
