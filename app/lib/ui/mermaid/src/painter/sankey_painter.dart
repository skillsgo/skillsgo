/*
 * [INPUT]: Depends on Flutter Canvas, lossless Sankey nodes/weighted links/configuration, and Mermaid semantic styles.
 * [OUTPUT]: Computes native weighted Sankey geometry and paints proportional nodes, ribbons, colors, values, and labels.
 * [POS]: Serves as the dedicated non-graph fallback renderer and size calculator for Mermaid Sankey diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sankey.dart';
import '../models/style.dart';

class SankeyChartLayout {
  const SankeyChartLayout();

  Size computeLayout(SankeyChartData data, Size availableSize) {
    if (!data.useMaxWidth || !availableSize.width.isFinite) {
      return Size(data.width, data.height);
    }
    final width = math.min(data.width, math.max(1.0, availableSize.width));
    return Size(width, data.height * width / data.width);
  }
}

class SankeyPainter extends CustomPainter {
  const SankeyPainter({required this.data, required this.style});

  final SankeyChartData data;
  final MermaidStyle style;

  // d3.schemeTableau10, assigned in first-seen node order.
  static const _palette = <Color>[
    Color(0xff4e79a7),
    Color(0xfff28e2c),
    Color(0xffe15759),
    Color(0xff76b7b2),
    Color(0xff59a14f),
    Color(0xffedc949),
    Color(0xffaf7aa1),
    Color(0xffff9da7),
    Color(0xff9c755f),
    Color(0xffbab0ab),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (data.nodes.isEmpty || data.links.isEmpty) return;
    final scale = data.useMaxWidth
        ? math.min(size.width / data.width, size.height / data.height)
        : 1.0;
    canvas.save();
    canvas.scale(scale, scale);
    final geometry = _layout();
    for (final positioned in geometry.nodes.values) {
      final color = _nodeColor(positioned.node);
      final rect = positioned.rect;
      canvas.drawRect(rect, Paint()..color = color);
      final value = geometry.values[positioned.node.id] ?? 0;
      final valueText = data.showValues
          ? ' ${data.prefix}${_format(value)}${data.suffix}'
          : '';
      final onLeft = data.labelStyle == SankeyLabelStyle.outlined
          ? positioned.layer < geometry.centralLayer
          : rect.left >= data.width / 2;
      _drawLabel(
        canvas,
        '${positioned.node.id}$valueText'.replaceAll(RegExp(r'\s+'), ' '),
        Offset(onLeft ? rect.left - 6 : rect.right + 6, rect.center.dy),
        alignRight: onLeft,
      );
    }
    // Mermaid appends its link group after nodes and labels in the SVG.
    for (final link in data.links) {
      final ribbon = geometry.links[link.index];
      if (ribbon == null) continue;
      final source = geometry.nodes[link.source]!;
      final target = geometry.nodes[link.target]!;
      final sourceColor = _nodeColor(source.node);
      final targetColor = _nodeColor(target.node);
      final path = _linkPath(ribbon);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, ribbon.width)
        ..color = _linkColor(sourceColor, targetColor).withValues(alpha: .5);
      if (data.linkColor == 'gradient') {
        paint.shader = LinearGradient(
          colors: [
            sourceColor.withValues(alpha: .5),
            targetColor.withValues(alpha: .5),
          ],
        ).createShader(Rect.fromLTRB(ribbon.x0, 0, ribbon.x1, data.height));
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  _SankeyGeometry _layout() =>
      _D3SankeyLayout(data, Size(data.width, data.height)).compute();

  Path _linkPath(_Ribbon ribbon) {
    final middle = (ribbon.x0 + ribbon.x1) / 2;
    return Path()
      ..moveTo(ribbon.x0, ribbon.y0)
      ..cubicTo(middle, ribbon.y0, middle, ribbon.y1, ribbon.x1, ribbon.y1);
  }

  Color _nodeColor(SankeyNodeData node) {
    return _parseColor(data.nodeColors[node.id]) ??
        _palette[node.index % _palette.length];
  }

  Color _linkColor(Color source, Color target) {
    if (data.linkColor == 'source') return source;
    if (data.linkColor == 'target') return target;
    return _parseColor(data.linkColor) ?? source;
  }

  Color? _parseColor(String? source) {
    if (source == null) return null;
    final value = source.trim().toLowerCase();
    final hex = RegExp(r'^#([0-9a-f]{3,8})$').firstMatch(value)?.group(1);
    if (hex != null && const {3, 4, 6, 8}.contains(hex.length)) {
      final expanded = hex.length <= 4
          ? hex.split('').map((digit) => '$digit$digit').join()
          : hex;
      final rgba = expanded.length == 6 ? '${expanded}ff' : expanded;
      return Color(
        int.parse('${rgba.substring(6, 8)}${rgba.substring(0, 6)}', radix: 16),
      );
    }
    final functional = _functionalColor(value);
    if (functional != null) return functional;
    return const {
      'red': Colors.red,
      'green': Colors.green,
      'blue': Colors.blue,
      'black': Colors.black,
      'white': Colors.white,
      'gray': Colors.grey,
      'grey': Colors.grey,
      'transparent': Color(0x00000000),
      'yellow': Color(0xffffff00),
      'orange': Color(0xffffa500),
      'purple': Color(0xff800080),
      'pink': Color(0xffffc0cb),
      'cyan': Color(0xff00ffff),
      'aqua': Color(0xff00ffff),
      'magenta': Color(0xffff00ff),
      'fuchsia': Color(0xffff00ff),
      'lime': Color(0xff00ff00),
      'navy': Color(0xff000080),
      'teal': Color(0xff008080),
      'olive': Color(0xff808000),
      'maroon': Color(0xff800000),
      'silver': Color(0xffc0c0c0),
    }[value.toLowerCase()];
  }

  Color? _functionalColor(String value) {
    final match = RegExp(r'^(rgba?|hsla?)\((.*)\)$').firstMatch(value);
    if (match == null) return null;
    final function = match.group(1)!;
    final raw = match.group(2)!.replaceAll(',', ' ');
    final slash = raw.split('/');
    final components = slash.first
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    String? alphaSource = slash.length == 2 ? slash[1].trim() : null;
    if (slash.length == 1 && components.length == 4) {
      alphaSource = components.removeLast();
    }
    if (components.length != 3) return null;
    final alpha = _cssChannel(alphaSource ?? '1', alpha: true);
    if (alpha == null) return null;
    if (function.startsWith('rgb')) {
      final channels = components
          .map((part) => _cssChannel(part))
          .toList(growable: false);
      if (channels.any((channel) => channel == null)) return null;
      return Color.fromARGB(alpha, channels[0]!, channels[1]!, channels[2]!);
    }
    final hue = _cssHue(components[0]);
    final saturation = _cssPercent(components[1]);
    final lightness = _cssPercent(components[2]);
    if (hue == null || saturation == null || lightness == null) return null;
    return HSLColor.fromAHSL(alpha / 255, hue, saturation, lightness).toColor();
  }

  int? _cssChannel(String source, {bool alpha = false}) {
    final value = source.trim();
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      return percent == null ? null : (percent.clamp(0, 100) * 2.55).round();
    }
    final number = double.tryParse(value);
    if (number == null) return null;
    return alpha
        ? (number.clamp(0, 1) * 255).round()
        : number.clamp(0, 255).round();
  }

  double? _cssHue(String source) {
    final match = RegExp(
      r'^(-?[\d.]+)(deg|grad|rad|turn)?$',
    ).firstMatch(source);
    final number = double.tryParse(match?.group(1) ?? '');
    if (number == null) return null;
    final degrees = switch (match?.group(2)) {
      'grad' => number * .9,
      'rad' => number * 180 / math.pi,
      'turn' => number * 360,
      _ => number,
    };
    return (degrees % 360 + 360) % 360;
  }

  double? _cssPercent(String source) {
    if (!source.endsWith('%')) return null;
    final number = double.tryParse(source.substring(0, source.length - 1));
    return number == null ? null : number.clamp(0, 100) / 100;
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset anchor, {
    required bool alignRight,
  }) {
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..color = Color(
        style.defaultNodeStyle.fillColor ?? style.backgroundColor,
      );
    final baseStyle = TextStyle(
      color: Color(
        style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
      ),
      fontSize: 14,
      fontFamily: style.fontFamily,
    );
    if (data.labelStyle == SankeyLabelStyle.outlined) {
      final outline = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(foreground: foreground),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      outline.paint(
        canvas,
        Offset(
          alignRight ? anchor.dx - outline.width : anchor.dx,
          anchor.dy - outline.height / 2,
        ),
      );
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        alignRight ? anchor.dx - painter.width : anchor.dx,
        anchor.dy - painter.height / 2,
      ),
    );
  }

  String _format(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }

  @override
  bool shouldRepaint(SankeyPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}

class _PositionedNode {
  const _PositionedNode(this.node, this.rect, this.layer);
  final SankeyNodeData node;
  final Rect rect;
  final int layer;
}

class _Ribbon {
  const _Ribbon(this.x0, this.x1, this.y0, this.y1, this.width);
  final double x0;
  final double x1;
  final double y0;
  final double y1;
  final double width;
}

class _SankeyGeometry {
  const _SankeyGeometry(this.nodes, this.links, this.values, this.centralLayer);
  final Map<String, _PositionedNode> nodes;
  final Map<int, _Ribbon> links;
  final Map<String, double> values;
  final int centralLayer;
}

/// A direct Dart port of the layout stages used by d3-sankey 0.12.3.
class _D3SankeyLayout {
  _D3SankeyLayout(this.data, this.size);

  final SankeyChartData data;
  final Size size;
  late final List<_D3Node> nodes = [
    for (final node in data.nodes) _D3Node(node),
  ];
  late final Map<String, _D3Node> nodeById = {
    for (final node in nodes) node.data.id: node,
  };
  late final List<_D3Link> links = [
    for (final link in data.links)
      _D3Link(link, nodeById[link.source]!, nodeById[link.target]!),
  ];
  double padding = 0;

  _SankeyGeometry compute() {
    for (final link in links) {
      link.source.sourceLinks.add(link);
      link.target.targetLinks.add(link);
    }
    for (final node in nodes) {
      node.value = math.max(
        node.sourceLinks.fold(0.0, (sum, link) => sum + link.data.value),
        node.targetLinks.fold(0.0, (sum, link) => sum + link.data.value),
      );
    }
    _computeDepths();
    _computeHeights();
    final columns = _computeLayers();
    final widestColumn = columns.fold<int>(0, (n, c) => math.max(n, c.length));
    padding = widestColumn <= 1
        ? data.nodePadding + (data.showValues ? 15 : 0)
        : math.min(
            data.nodePadding + (data.showValues ? 15 : 0),
            size.height / (widestColumn - 1),
          );
    _initializeBreadths(columns);
    for (var iteration = 0; iteration < 6; iteration++) {
      final alpha = math.pow(.99, iteration).toDouble();
      final beta = math.max(1 - alpha, (iteration + 1) / 6);
      _relaxRightToLeft(columns, alpha, beta);
      _relaxLeftToRight(columns, alpha, beta);
    }
    _computeLinkBreadths();

    final central = nodes.reduce((a, b) => a.value >= b.value ? a : b).layer;
    return _SankeyGeometry(
      {
        for (final node in nodes)
          node.data.id: _PositionedNode(
            node.data,
            Rect.fromLTRB(node.x0, node.y0, node.x1, node.y1),
            node.layer,
          ),
      },
      {
        for (final link in links)
          link.data.index: _Ribbon(
            link.source.x1,
            link.target.x0,
            link.y0,
            link.y1,
            link.width,
          ),
      },
      {for (final node in nodes) node.data.id: node.value},
      central,
    );
  }

  void _computeDepths() {
    var current = nodes.toSet();
    var depth = 0;
    while (current.isNotEmpty) {
      final next = <_D3Node>{};
      for (final node in current) {
        node.depth = depth;
        next.addAll(node.sourceLinks.map((link) => link.target));
      }
      depth++;
      if (depth > nodes.length) throw StateError('circular Sankey link');
      current = next;
    }
  }

  void _computeHeights() {
    var current = nodes.toSet();
    var height = 0;
    while (current.isNotEmpty) {
      final next = <_D3Node>{};
      for (final node in current) {
        node.height = height;
        next.addAll(node.targetLinks.map((link) => link.source));
      }
      height++;
      if (height > nodes.length) throw StateError('circular Sankey link');
      current = next;
    }
  }

  List<List<_D3Node>> _computeLayers() {
    final count = nodes.map((node) => node.depth).reduce(math.max) + 1;
    final columns = List.generate(count, (_) => <_D3Node>[]);
    final xScale = count == 1
        ? 0.0
        : (size.width - data.nodeWidth) / (count - 1);
    for (final node in nodes) {
      final aligned = switch (data.nodeAlignment) {
        SankeyNodeAlignment.left => node.depth,
        SankeyNodeAlignment.right => count - 1 - node.height,
        SankeyNodeAlignment.justify =>
          node.sourceLinks.isNotEmpty ? node.depth : count - 1,
        SankeyNodeAlignment.center =>
          node.targetLinks.isNotEmpty
              ? node.depth
              : node.sourceLinks.isNotEmpty
              ? node.sourceLinks
                        .map((link) => link.target.depth)
                        .reduce(math.min) -
                    1
              : 0,
      };
      node.layer = aligned.clamp(0, count - 1);
      node.x0 = node.layer * xScale;
      node.x1 = node.x0 + data.nodeWidth;
      columns[node.layer].add(node);
    }
    return columns;
  }

  void _initializeBreadths(List<List<_D3Node>> columns) {
    var scale = double.infinity;
    for (final column in columns) {
      final total = column.fold(0.0, (sum, node) => sum + node.value);
      if (total > 0) {
        scale = math.min(
          scale,
          (size.height - (column.length - 1) * padding) / total,
        );
      }
    }
    if (!scale.isFinite) scale = 0;
    for (final column in columns) {
      var y = 0.0;
      for (final node in column) {
        node.y0 = y;
        node.y1 = y + node.value * scale;
        y = node.y1 + padding;
        for (final link in node.sourceLinks) {
          link.width = link.data.value * scale;
        }
      }
      final gap = (size.height - y + padding) / (column.length + 1);
      for (var index = 0; index < column.length; index++) {
        column[index]
          ..y0 += gap * (index + 1)
          ..y1 += gap * (index + 1);
      }
      _reorderLinks(column);
    }
  }

  void _relaxLeftToRight(
    List<List<_D3Node>> columns,
    double alpha,
    double beta,
  ) {
    for (var index = 1; index < columns.length; index++) {
      final column = columns[index];
      for (final target in column) {
        var weightedY = 0.0;
        var weight = 0.0;
        for (final link in target.targetLinks) {
          final value = link.data.value * (target.layer - link.source.layer);
          weightedY += _targetTop(link.source, target) * value;
          weight += value;
        }
        if (weight <= 0) continue;
        final offset = (weightedY / weight - target.y0) * alpha;
        target
          ..y0 += offset
          ..y1 += offset;
        _reorderNodeLinks(target);
      }
      _sortNodes(column);
      _resolveCollisions(column, beta);
    }
  }

  void _relaxRightToLeft(
    List<List<_D3Node>> columns,
    double alpha,
    double beta,
  ) {
    for (var index = columns.length - 2; index >= 0; index--) {
      final column = columns[index];
      for (final source in column) {
        var weightedY = 0.0;
        var weight = 0.0;
        for (final link in source.sourceLinks) {
          final value = link.data.value * (link.target.layer - source.layer);
          weightedY += _sourceTop(source, link.target) * value;
          weight += value;
        }
        if (weight <= 0) continue;
        final offset = (weightedY / weight - source.y0) * alpha;
        source
          ..y0 += offset
          ..y1 += offset;
        _reorderNodeLinks(source);
      }
      _sortNodes(column);
      _resolveCollisions(column, beta);
    }
  }

  void _resolveCollisions(List<_D3Node> nodes, double alpha) {
    final middle = nodes.length >> 1;
    final subject = nodes[middle];
    _collideBottomToTop(nodes, subject.y0 - padding, middle - 1, alpha);
    _collideTopToBottom(nodes, subject.y1 + padding, middle + 1, alpha);
    _collideBottomToTop(nodes, size.height, nodes.length - 1, alpha);
    _collideTopToBottom(nodes, 0, 0, alpha);
  }

  void _collideTopToBottom(
    List<_D3Node> nodes,
    double y,
    int start,
    double alpha,
  ) {
    for (var index = start; index < nodes.length; index++) {
      final node = nodes[index];
      final offset = (y - node.y0) * alpha;
      if (offset > 1e-6) {
        node
          ..y0 += offset
          ..y1 += offset;
      }
      y = node.y1 + padding;
    }
  }

  void _collideBottomToTop(
    List<_D3Node> nodes,
    double y,
    int start,
    double alpha,
  ) {
    for (var index = start; index >= 0; index--) {
      final node = nodes[index];
      final offset = (node.y1 - y) * alpha;
      if (offset > 1e-6) {
        node
          ..y0 -= offset
          ..y1 -= offset;
      }
      y = node.y0 - padding;
    }
  }

  void _reorderNodeLinks(_D3Node node) {
    for (final link in node.targetLinks) {
      _sortSourceLinks(link.source.sourceLinks);
    }
    for (final link in node.sourceLinks) {
      _sortTargetLinks(link.target.targetLinks);
    }
  }

  void _reorderLinks(List<_D3Node> nodes) {
    for (final node in nodes) {
      _sortSourceLinks(node.sourceLinks);
      _sortTargetLinks(node.targetLinks);
    }
  }

  void _sortNodes(List<_D3Node> nodes) => nodes.sort(
    (a, b) => a.y0 == b.y0
        ? a.data.index.compareTo(b.data.index)
        : a.y0.compareTo(b.y0),
  );

  void _sortSourceLinks(List<_D3Link> links) => links.sort((a, b) {
    final order = a.target.y0.compareTo(b.target.y0);
    return order == 0 ? a.data.index.compareTo(b.data.index) : order;
  });

  void _sortTargetLinks(List<_D3Link> links) => links.sort((a, b) {
    final order = a.source.y0.compareTo(b.source.y0);
    return order == 0 ? a.data.index.compareTo(b.data.index) : order;
  });

  double _targetTop(_D3Node source, _D3Node target) {
    var y = source.y0 - (source.sourceLinks.length - 1) * padding / 2;
    for (final link in source.sourceLinks) {
      if (identical(link.target, target)) break;
      y += link.width + padding;
    }
    for (final link in target.targetLinks) {
      if (identical(link.source, source)) break;
      y -= link.width;
    }
    return y;
  }

  double _sourceTop(_D3Node source, _D3Node target) {
    var y = target.y0 - (target.targetLinks.length - 1) * padding / 2;
    for (final link in target.targetLinks) {
      if (identical(link.source, source)) break;
      y += link.width + padding;
    }
    for (final link in source.sourceLinks) {
      if (identical(link.target, target)) break;
      y -= link.width;
    }
    return y;
  }

  void _computeLinkBreadths() {
    for (final node in nodes) {
      var sourceY = node.y0;
      var targetY = node.y0;
      for (final link in node.sourceLinks) {
        link.y0 = sourceY + link.width / 2;
        sourceY += link.width;
      }
      for (final link in node.targetLinks) {
        link.y1 = targetY + link.width / 2;
        targetY += link.width;
      }
    }
  }
}

class _D3Node {
  _D3Node(this.data);

  final SankeyNodeData data;
  final List<_D3Link> sourceLinks = [];
  final List<_D3Link> targetLinks = [];
  double value = 0;
  int depth = 0;
  int height = 0;
  int layer = 0;
  double x0 = 0;
  double x1 = 0;
  double y0 = 0;
  double y1 = 0;
}

class _D3Link {
  _D3Link(this.data, this.source, this.target);

  final SankeyLinkData data;
  final _D3Node source;
  final _D3Node target;
  double width = 0;
  double y0 = 0;
  double y1 = 0;
}
