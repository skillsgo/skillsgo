/*
 * [INPUT]: Depends on package:yaml for Mermaid-compatible YAML frontmatter decoding.
 * [OUTPUT]: Provides lossless supported frontmatter metadata and safe typed configuration lookup.
 * [POS]: Serves as the shared configuration boundary between source preprocessing and native diagram consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:yaml/yaml.dart';

/// Mermaid metadata admitted from the leading YAML frontmatter block.
class MermaidFrontmatter {
  /// Creates immutable frontmatter metadata.
  const MermaidFrontmatter({
    this.title,
    this.displayMode,
    this.config = const <String, Object?>{},
  });

  /// The empty metadata value used when no frontmatter is present.
  static const empty = MermaidFrontmatter();

  /// Optional diagram title.
  final String? title;

  /// Optional diagram-specific display mode, currently used by Gantt.
  final String? displayMode;

  /// Complete configuration tree. Unknown keys are preserved for later support.
  final Map<String, Object?> config;

  /// Whether any supported frontmatter metadata was declared.
  bool get isEmpty => title == null && displayMode == null && config.isEmpty;

  /// Looks up a nested configuration value without throwing on type mismatch.
  Object? valueAt(Iterable<String> path) {
    Object? value = config;
    for (final segment in path) {
      if (value is! Map<String, Object?>) return null;
      value = value[segment];
    }
    return value;
  }

  /// Returns a nested string value, coercing scalar values like Mermaid does.
  String? stringAt(Iterable<String> path) {
    final value = valueAt(path);
    if (value == null || value is Map || value is List) return null;
    return value.toString();
  }

  /// Returns a nested finite numeric value.
  num? numberAt(Iterable<String> path) {
    final value = valueAt(path);
    if (value is num && value.isFinite) return value;
    return value is String ? num.tryParse(value) : null;
  }

  /// Returns a nested boolean value.
  bool? boolAt(Iterable<String> path) {
    final value = valueAt(path);
    if (value is bool) return value;
    if (value is String && value.toLowerCase() == 'true') return true;
    if (value is String && value.toLowerCase() == 'false') return false;
    return null;
  }
}

/// Source text after frontmatter extraction plus supported metadata.
class MermaidPreprocessedSource {
  /// Creates a preprocessing result.
  const MermaidPreprocessedSource({
    required this.source,
    required this.metadata,
  });

  /// Source with a valid leading frontmatter block removed.
  final String source;

  /// Extracted supported metadata.
  final MermaidFrontmatter metadata;
}

/// Extracts Mermaid 11.16-compatible leading YAML frontmatter.
class MermaidFrontmatterParser {
  /// Creates a frontmatter parser.
  const MermaidFrontmatterParser();

  /// Returns null when a matched frontmatter block contains invalid YAML.
  MermaidPreprocessedSource? parse(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    if (lines.isEmpty) {
      return const MermaidPreprocessedSource(
        source: '',
        metadata: MermaidFrontmatter.empty,
      );
    }

    final opening = RegExp(r'^(\s*)---\s*$').firstMatch(lines.first);
    if (opening == null) {
      return MermaidPreprocessedSource(
        source: normalized,
        metadata: MermaidFrontmatter.empty,
      );
    }
    final indent = opening.group(1)!;
    var closingIndex = -1;
    for (var index = 1; index < lines.length; index++) {
      if (lines[index] == '$indent---') {
        closingIndex = index;
        break;
      }
    }
    if (closingIndex < 0) {
      return MermaidPreprocessedSource(
        source: normalized,
        metadata: MermaidFrontmatter.empty,
      );
    }

    final body = lines
        .sublist(1, closingIndex)
        .map((line) {
          return indent.isNotEmpty && line.startsWith(indent)
              ? line.substring(indent.length)
              : line;
        })
        .join('\n');
    Object? decoded;
    try {
      decoded = loadYaml(body);
    } on YamlException {
      return null;
    }
    final root = _toStringMap(decoded);
    final rawConfig = root?['config'];
    final config = _toStringMap(rawConfig) ?? const <String, Object?>{};
    final title = _scalarString(root?['title']);
    final displayMode = _scalarString(root?['displayMode']);
    return MermaidPreprocessedSource(
      source: lines.sublist(closingIndex + 1).join('\n'),
      metadata: MermaidFrontmatter(
        title: title,
        displayMode: displayMode,
        config: config,
      ),
    );
  }

  static String? _scalarString(Object? value) {
    if (value == null || value is Map || value is List) return null;
    return value.toString();
  }

  static Map<String, Object?>? _toStringMap(Object? value) {
    if (value is! Map) return null;
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _toDartValue(entry.value),
    };
  }

  static Object? _toDartValue(Object? value) {
    if (value is Map) return _toStringMap(value);
    if (value is List) return value.map(_toDartValue).toList(growable: false);
    return value;
  }
}
