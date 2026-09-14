/*
 * [INPUT]: Depends on Dart color arithmetic and immutable token grouping.
 * [OUTPUT]: Provides readable foreground selection, hex formatting, color roles, and role groups.
 * [POS]: Serves as the pure value and formatting segment of the development ColorScheme inspector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../color_scheme_inspector.dart';

Color _readableForeground(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _ColorRole {
  const _ColorRole(this.name, this.color, this.usage);

  final String name;
  final Color color;
  final String usage;
}

class _ColorGroup {
  const _ColorGroup({
    required this.name,
    required this.description,
    required this.roles,
  });

  final String name;
  final String description;
  final List<_ColorRole> roles;
}
