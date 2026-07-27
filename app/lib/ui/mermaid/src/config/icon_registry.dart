/*
 * [INPUT]: Depends on Flutter IconData/TextPainter and caller-supplied native vector painter callbacks.
 * [OUTPUT]: Provides a process-local Mermaid icon-pack registry with built-in Material glyphs, IconData packs, and arbitrary Canvas vector packs.
 * [POS]: Serves as the pure-Dart equivalent of Mermaid registerIconPacks for Kanban, Tree View, Architecture, and future icon-bearing diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

typedef MermaidIconPainter =
    void Function(Canvas canvas, Rect bounds, Color color);

class MermaidIconGlyph {
  const MermaidIconGlyph(this.paint);
  final MermaidIconPainter paint;

  factory MermaidIconGlyph.iconData(IconData icon) =>
      MermaidIconGlyph((canvas, bounds, color) {
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              inherit: false,
              color: color,
              fontSize: bounds.shortestSide,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(
            bounds.center.dx - painter.width / 2,
            bounds.center.dy - painter.height / 2,
          ),
        );
      });
}

class MermaidIconRegistry {
  MermaidIconRegistry._();

  static final Map<String, MermaidIconGlyph> _glyphs = {
    'folder': MermaidIconGlyph.iconData(Icons.folder_outlined),
    'file': MermaidIconGlyph.iconData(Icons.insert_drive_file_outlined),
    'database': MermaidIconGlyph.iconData(Icons.storage_outlined),
    'server': MermaidIconGlyph.iconData(Icons.dns_outlined),
    'cloud': MermaidIconGlyph.iconData(Icons.cloud_outlined),
    'internet': MermaidIconGlyph.iconData(Icons.public_outlined),
    'user': MermaidIconGlyph.iconData(Icons.person_outline),
    'check': MermaidIconGlyph.iconData(Icons.check_circle_outline),
    'bug': MermaidIconGlyph.iconData(Icons.bug_report_outlined),
  };

  static void registerIcon(String identity, MermaidIconGlyph glyph) {
    final normalized = identity.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(identity, 'identity', 'must not be empty');
    }
    _glyphs[normalized] = glyph;
  }

  static void registerIconData(String identity, IconData icon) {
    registerIcon(identity, MermaidIconGlyph.iconData(icon));
  }

  static void registerPack(String prefix, Map<String, MermaidIconGlyph> icons) {
    final normalized = prefix.trim().toLowerCase();
    if (normalized.isEmpty || normalized.contains(':')) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'must be a non-empty pack name',
      );
    }
    for (final entry in icons.entries) {
      registerIcon('$normalized:${entry.key}', entry.value);
    }
  }

  static MermaidIconGlyph? resolve(String identity, {String? defaultPack}) {
    final normalized = identity.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'none') return null;
    final direct = _glyphs[normalized];
    if (direct != null) return direct;
    if (!normalized.contains(':') &&
        defaultPack != null &&
        defaultPack.isNotEmpty) {
      return _glyphs['${defaultPack.toLowerCase()}:$normalized'];
    }
    return null;
  }

  static bool contains(String identity, {String? defaultPack}) =>
      resolve(identity, defaultPack: defaultPack) != null;
}
