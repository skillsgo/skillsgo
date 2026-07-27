/*
 * [INPUT]: Depends on Mermaid Tree View hierarchy, annotations, descriptions, icons, and complete renderer configuration.
 * [OUTPUT]: Defines immutable lossless native Tree View nodes, metadata, spacing, line, and icon resolution configuration.
 * [POS]: Serves as the Tree View-specific hierarchy alongside the shared graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum TreeViewNodeKind { file, directory }

class TreeViewNodeData {
  const TreeViewNodeData({
    required this.index,
    required this.name,
    required this.kind,
    required this.indentation,
    required this.parentIndex,
    this.cssClass,
    this.icon,
    this.description,
  });
  final int index;
  final String name;
  final TreeViewNodeKind kind;
  final int indentation;
  final int? parentIndex;
  final String? cssClass;
  final String? icon;
  final String? description;
}

class TreeViewChartData {
  const TreeViewChartData({
    required this.nodes,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.rowIndent = 10,
    this.paddingX = 5,
    this.paddingY = 5,
    this.lineThickness = 1,
    this.showIcons = false,
    this.defaultIconPack = '',
    this.filenameIcons = const {},
    this.extensionIcons = const {},
  });
  final List<TreeViewNodeData> nodes;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double rowIndent;
  final double paddingX;
  final double paddingY;
  final double lineThickness;
  final bool showIcons;
  final String defaultIconPack;
  final Map<String, String> filenameIcons;
  final Map<String, String> extensionIcons;

  TreeViewChartData copyWith({
    String? title,
    double? rowIndent,
    double? paddingX,
    double? paddingY,
    double? lineThickness,
    bool? showIcons,
    String? defaultIconPack,
    Map<String, String>? filenameIcons,
    Map<String, String>? extensionIcons,
  }) {
    return TreeViewChartData(
      nodes: nodes,
      title: title ?? this.title,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      rowIndent: rowIndent ?? this.rowIndent,
      paddingX: paddingX ?? this.paddingX,
      paddingY: paddingY ?? this.paddingY,
      lineThickness: lineThickness ?? this.lineThickness,
      showIcons: showIcons ?? this.showIcons,
      defaultIconPack: defaultIconPack ?? this.defaultIconPack,
      filenameIcons: filenameIcons ?? this.filenameIcons,
      extensionIcons: extensionIcons ?? this.extensionIcons,
    );
  }

  String? iconFor(TreeViewNodeData node) {
    if (node.icon case final explicit?) return explicit;
    if (!showIcons) return null;
    final filename = filenameIcons[node.name];
    if (filename != null) return filename;
    final dot = node.name.lastIndexOf('.');
    if (dot >= 0) {
      final extension = node.name.substring(dot).toLowerCase();
      final mapped =
          extensionIcons[extension] ?? extensionIcons[extension.substring(1)];
      if (mapped != null) return mapped;
    }
    return node.kind == TreeViewNodeKind.directory ? 'folder' : 'file';
  }
}
