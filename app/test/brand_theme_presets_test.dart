/*
 * [INPUT]: Uses Flutter Material seeded color schemes and the curated brand theme preset catalog.
 * [OUTPUT]: Specifies preset identity, source traceability, color uniqueness, and readable light/dark seeded theme pairs.
 * [POS]: Serves as the focused contract suite for the App's static Simple Icons theme catalog.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/brand_theme_presets.dart';

void main() {
  test('brand theme presets are stable, unique, and source traceable', () {
    expect(simpleIconsRevision, hasLength(40));
    expect(brandThemePresets, hasLength(18));
    expect(
      brandThemePresets.map((preset) => preset.id).toSet(),
      hasLength(brandThemePresets.length),
    );
    expect(
      brandThemePresets.map((preset) => preset.color).toSet(),
      hasLength(brandThemePresets.length),
    );
    for (final preset in brandThemePresets) {
      expect(Uri.parse(preset.source).hasScheme, isTrue, reason: preset.name);
    }
  });

  for (final brightness in Brightness.values) {
    test('all $brightness presets generate readable Material roles', () {
      for (final preset in brandThemePresets) {
        final scheme = ColorScheme.fromSeed(
          seedColor: preset.color,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );
        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.name} primary on $brightness',
        );
        expect(
          _contrastRatio(scheme.surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.name} surface on $brightness',
        );
      }
    });
  }
}

double _contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
