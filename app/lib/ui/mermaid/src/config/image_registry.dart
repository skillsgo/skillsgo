/*
 * [INPUT]: Depends on decoded Flutter dart:ui images supplied by the host application.
 * [OUTPUT]: Provides a process-local source-URL-to-native-image registry for Mermaid image nodes.
 * [POS]: Serves as the pure-Dart image resource seam used by flowchart Canvas rendering without WebView or SVG.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';

class MermaidImageRegistry {
  MermaidImageRegistry._();

  static final Map<String, Image> _images = {};

  static void register(String source, Image image) {
    final key = source.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(source, 'source', 'must not be empty');
    }
    _images[key] = image;
  }

  static Image? resolve(String source) => _images[source.trim()];

  static void unregister(String source) => _images.remove(source.trim());

  static void clear() => _images.clear();
}
