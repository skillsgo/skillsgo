/*
 * [INPUT]: Depends on responsive configuration and native Mermaid diagram, node, style, and specialized chart models.
 * [OUTPUT]: Provides shared layout measurement plus flowchart, sequence, timeline, kanban, radar, XY, packet, quadrant, treemap, Venn, Block, C4, Architecture, Event Modeling, Ishikawa, Railroad, and Wardley layout engines.
 * [POS]: Serves as the native geometry layer between parsed Mermaid models and Flutter painters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;
import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/architecture.dart';
import '../models/block.dart';
import '../models/c4.dart';
import '../models/cynefin.dart';
import '../models/diagram.dart';
import '../models/event_modeling.dart';
import '../models/ishikawa.dart';
import '../models/railroad.dart';
import '../models/wardley.dart';
import '../models/kanban.dart';
import '../models/node.dart';
import '../models/packet.dart';
import '../models/quadrant.dart';
import '../models/radar.dart';
import '../models/timeline.dart';
import '../models/treemap.dart';
import '../models/venn.dart';
import '../models/style.dart';
import '../models/swimlane.dart';
import '../models/xy_chart.dart';

/// Abstract base class for layout engines
abstract class LayoutEngine {
  /// Creates a layout engine
  const LayoutEngine();

  /// Computes layout for the given diagram
  ///
  /// Returns the total size required to render the diagram
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  );

  /// Measures the size of a node
  Size measureNode(MermaidNode node, MermaidStyle style) {
    final nodeStyle = style.getNodeStyle(node.className);

    // Calculate text size
    final fontSize = nodeStyle.fontSize;
    final textWidth = node.label.length * fontSize * 0.6;
    final textHeight = fontSize * 1.4;

    // Add padding based on shape
    double horizontalPadding = 24.0;
    double verticalPadding = 16.0;

    switch (node.shape) {
      case NodeShape.circle:
      case NodeShape.doubleCircle:
        // Circle needs equal dimensions
        final diameter = math.max(textWidth, textHeight) + 32;
        return Size(diameter, diameter);

      case NodeShape.diamond:
      case NodeShape.hexagon:
        // These shapes need more horizontal space
        horizontalPadding = 40.0;
        verticalPadding = 24.0;
        break;

      case NodeShape.stadium:
        // Stadium is wider
        horizontalPadding = 32.0;
        break;

      case NodeShape.cylinder:
        // Cylinder needs extra height for the 3D effect
        verticalPadding = 28.0;
        break;

      default:
        break;
    }

    return Size(textWidth + horizontalPadding, textHeight + verticalPadding);
  }
}

class PacketChartLayout {
  const PacketChartLayout();

  Size computeLayout(
    PacketChartData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    final rows = (data.bitLength / data.bitsPerRow).ceil();
    final totalRowHeight = data.rowHeight + data.effectivePaddingY;
    final intrinsicWidth = data.bitsPerRow * data.bitWidth + 2;
    return Size(
      data.useMaxWidth
          ? math.max(intrinsicWidth, availableSize.width)
          : intrinsicWidth,
      totalRowHeight * (rows + 1) - (data.title == null ? data.rowHeight : 0),
    );
  }
}

class QuadrantChartLayout {
  const QuadrantChartLayout();

  Size computeLayout(
    QuadrantChartData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    final width = data.useMaxWidth
        ? math.max(data.chartWidth, availableSize.width)
        : data.chartWidth;
    return Size(width, data.chartHeight);
  }
}

class TreemapChartLayout {
  const TreemapChartLayout();

  Size computeLayout(TreemapChartData data, Size availableSize) {
    final configuredWidth = data.nodeWidth * 10;
    final configuredHeight =
        data.nodeHeight * 10 + (data.title == null ? 0 : 30);
    if (!data.useMaxWidth ||
        !availableSize.width.isFinite ||
        availableSize.width >= configuredWidth) {
      return Size(configuredWidth, configuredHeight);
    }
    final width = math.max(1.0, availableSize.width);
    return Size(width, configuredHeight * width / configuredWidth);
  }
}

class VennChartLayout {
  const VennChartLayout();

  Size computeLayout(VennChartData data, Size availableSize) {
    if (!data.useMaxWidth || !availableSize.width.isFinite) {
      return Size(data.width, data.height);
    }
    final width = math.min(data.width, math.max(1.0, availableSize.width));
    return Size(width, data.height * width / data.width);
  }
}

class BlockChartLayout {
  const BlockChartLayout();

  Size computeLayout(
    MermaidDiagramData diagram,
    BlockChartData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    final columns = math.max(1, data.columns);
    final intrinsicWidth =
        data.padding * 2 + columns * 150 + math.max(0, columns - 1) * 18;
    final width = data.useMaxWidth && availableSize.width.isFinite
        ? math.max(intrinsicWidth, availableSize.width)
        : intrinsicWidth;
    final titleHeight = data.title == null ? 0.0 : 42.0;
    final contentHeight = _containerHeight(data, null, columns);
    final nodes = {for (final node in diagram.nodes) node.id: node};
    _layoutContainer(
      data,
      nodes,
      null,
      columns,
      Rect.fromLTWH(
        data.padding,
        data.padding + titleHeight,
        width - data.padding * 2,
        contentHeight,
      ),
    );
    return Size(
      width,
      math.max(100, contentHeight + data.padding * 2 + titleHeight),
    );
  }

  double _containerHeight(BlockChartData data, String? parent, int columns) {
    final items = data.placements
        .where((item) => item.parent == parent)
        .toList();
    if (items.isEmpty) return 64;
    final rowHeights = <double>[];
    var row = 0;
    var column = 0;
    for (final item in items) {
      final span = item.span.clamp(1, columns);
      if (column + span > columns) {
        row++;
        column = 0;
      }
      while (rowHeights.length <= row) {
        rowHeights.add(0);
      }
      final height = item.groupId == null
          ? 64.0
          : _groupHeight(data, item.groupId!);
      rowHeights[row] = math.max(rowHeights[row], height);
      column += span;
      if (column >= columns) {
        row++;
        column = 0;
      }
    }
    return rowHeights.fold<double>(0, (sum, value) => sum + value) +
        math.max(0, rowHeights.length - 1) * 18;
  }

  double _groupHeight(BlockChartData data, String id) {
    final group = data.groups.firstWhere((item) => item.id == id);
    final children = data.placements.where((item) => item.parent == id).length;
    final columns = group.columns > 0
        ? group.columns
        : math.max(1, math.min(4, children));
    return 34 + data.padding * 2 + _containerHeight(data, id, columns);
  }

  void _layoutContainer(
    BlockChartData data,
    Map<String, MermaidNode> nodes,
    String? parent,
    int columns,
    Rect bounds,
  ) {
    final items = data.placements
        .where((item) => item.parent == parent)
        .toList();
    if (items.isEmpty) return;
    final rows = <int, List<(BlockPlacement, int, int)>>{};
    final rowHeights = <int, double>{};
    var row = 0;
    var column = 0;
    for (final item in items) {
      final span = item.span.clamp(1, columns);
      if (column + span > columns) {
        row++;
        column = 0;
      }
      rows.putIfAbsent(row, () => []).add((item, column, span));
      rowHeights[row] = math.max(
        rowHeights[row] ?? 0,
        item.groupId == null ? 64 : _groupHeight(data, item.groupId!),
      );
      column += span;
      if (column >= columns) {
        row++;
        column = 0;
      }
    }
    const gap = 18.0;
    final cellWidth = (bounds.width - math.max(0, columns - 1) * gap) / columns;
    var y = bounds.top;
    for (final entry in rows.entries) {
      final rowHeight = rowHeights[entry.key]!;
      for (final record in entry.value) {
        final item = record.$1;
        final itemBounds = Rect.fromLTWH(
          bounds.left + record.$2 * (cellWidth + gap),
          y,
          cellWidth * record.$3 + gap * (record.$3 - 1),
          rowHeight,
        );
        if (item.nodeId case final id?) {
          final node = nodes[id];
          if (node != null) {
            node
              ..width = math.max(1, itemBounds.width - data.padding * 2)
              ..height = math.max(36, itemBounds.height - data.padding * 2)
              ..x = itemBounds.center.dx
              ..y = itemBounds.center.dy;
          }
        } else if (item.groupId case final groupId?) {
          final group = data.groups.firstWhere((value) => value.id == groupId);
          final childCount = data.placements
              .where((value) => value.parent == groupId)
              .length;
          final childColumns = group.columns > 0
              ? group.columns
              : math.max(1, math.min(4, childCount));
          _layoutContainer(
            data,
            nodes,
            groupId,
            childColumns,
            Rect.fromLTRB(
              itemBounds.left + data.padding,
              itemBounds.top + 30 + data.padding,
              itemBounds.right - data.padding,
              itemBounds.bottom - data.padding,
            ),
          );
        }
      }
      y += rowHeight + gap;
    }
  }
}

class SwimlaneChartLayout {
  const SwimlaneChartLayout();

  Size computeLayout(
    MermaidDiagramData diagram,
    SwimlaneData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    final config = diagram.flowchartConfig;
    final padding = config?.diagramPadding ?? style.padding;
    final rankGap = config?.rankSpacing ?? style.nodeSpacingX;
    final laneGap = config?.nodeSpacing ?? style.nodeSpacingY;
    final titleOffset = diagram.title == null ? 0.0 : 38.0;
    const nodeWidth = 142.0;
    const nodeHeight = 58.0;
    final nodeLane = <String, String>{};
    for (final lane in diagram.subgraphs) {
      for (final id in lane.nodeIds) {
        nodeLane[id] = lane.id;
      }
    }
    var lanes = diagram.subgraphs.isEmpty
        ? [
            Subgraph(
              id: '__default_swimlane__',
              label: '',
              nodeIds: diagram.nodes.map((node) => node.id).toList(),
            ),
          ]
        : [...diagram.subgraphs];
    if (data.automaticLaneOrdering && lanes.length > 1) {
      final score = <String, double>{for (final lane in lanes) lane.id: 0};
      for (final edge in diagram.edges) {
        final fromLane = nodeLane[edge.from];
        final toLane = nodeLane[edge.to];
        if (fromLane != null && toLane != null && fromLane != toLane) {
          score[fromLane] =
              score[fromLane]! + lanes.indexWhere((l) => l.id == toLane);
          score[toLane] =
              score[toLane]! + lanes.indexWhere((l) => l.id == fromLane);
        }
      }
      lanes.sort((a, b) {
        final compared = score[a.id]!.compareTo(score[b.id]!);
        return compared == 0
            ? data.laneIds.indexOf(a.id).compareTo(data.laneIds.indexOf(b.id))
            : compared;
      });
    }
    final ranks = <String, int>{for (final node in diagram.nodes) node.id: 0};
    for (var pass = 0; pass < diagram.nodes.length; pass++) {
      var changed = false;
      for (final edge in diagram.edges) {
        if (data.ignoreCrossLaneEdges &&
            nodeLane[edge.from] != nodeLane[edge.to]) {
          continue;
        }
        final next = (ranks[edge.from] ?? 0) + 1;
        if (next > (ranks[edge.to] ?? 0) && next <= diagram.nodes.length) {
          ranks[edge.to] = next;
          changed = true;
        }
      }
      if (!changed) break;
    }
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    var maxRank = 0;
    for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++) {
      final lane = lanes[laneIndex];
      var members = lane.nodeIds
          .map((id) => diagram.getNode(id))
          .whereType<MermaidNode>()
          .toList();
      if (data.optimizeRanksByCrossings) {
        members.sort((a, b) {
          final rank = (ranks[a.id] ?? 0).compareTo(ranks[b.id] ?? 0);
          if (rank != 0) return rank;
          double barycenter(MermaidNode node) {
            final peers = diagram.edges
                .where((edge) => edge.from == node.id || edge.to == node.id)
                .map((edge) => edge.from == node.id ? edge.to : edge.from)
                .map((id) => ranks[id]?.toDouble())
                .whereType<double>()
                .toList();
            return peers.isEmpty
                ? diagram.nodes.indexOf(node).toDouble()
                : peers.reduce((a, b) => a + b) / peers.length;
          }

          return barycenter(a).compareTo(barycenter(b));
        });
      }
      for (var localIndex = 0; localIndex < members.length; localIndex++) {
        final node = members[localIndex];
        final rank = data.ignoreCrossLaneEdges
            ? localIndex
            : (ranks[node.id] ?? localIndex);
        maxRank = math.max(maxRank, rank);
        final process =
            padding + 52 + rank * (nodeWidth + rankGap) + nodeWidth / 2;
        final laneCenter =
            padding +
            titleOffset +
            laneIndex * (nodeHeight + laneGap + 48) +
            44 +
            nodeHeight / 2;
        node
          ..width = nodeWidth
          ..height = nodeHeight
          ..x = horizontal ? process : laneCenter
          ..y = horizontal ? laneCenter : process;
      }
    }
    final processExtent =
        padding * 2 + 52 + (maxRank + 1) * nodeWidth + maxRank * rankGap;
    final laneExtent =
        padding * 2 + titleOffset + lanes.length * (nodeHeight + laneGap + 48);
    final width = horizontal ? processExtent : laneExtent;
    final height = horizontal ? laneExtent : processExtent;
    if (diagram.direction == DiagramDirection.rightToLeft) {
      for (final node in diagram.nodes) {
        node.x = width - node.x;
      }
    } else if (diagram.direction == DiagramDirection.bottomToTop) {
      for (final node in diagram.nodes) {
        node.y = height - node.y;
      }
    }
    return Size(
      data.useMaxWidth ? math.max(availableSize.width, width) : width,
      math.max(160, height),
    );
  }
}

class C4ChartLayout {
  const C4ChartLayout();

  Size computeLayout(
    MermaidDiagramData diagram,
    C4ChartData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    final columns = math.max(1, data.shapesPerRow);
    double setting(String key, double fallback) {
      final value = data.setting(key);
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      return parsed != null && parsed >= 0 ? parsed : fallback;
    }

    final marginX = setting('diagramMarginX', 50);
    final marginY = setting('diagramMarginY', 10);
    final shapeMargin = setting('c4ShapeMargin', 50);
    final shapePadding = setting('c4ShapePadding', 20);
    final configuredWidth = setting('width', 216);
    final configuredHeight = setting('height', 60);
    final nextLinePaddingX = setting('nextLinePaddingX', 0);
    final useMaxWidth = data.setting('useMaxWidth') as bool? ?? true;
    final cellWidth = math.max(80.0, configuredWidth + shapePadding * 2);
    final nodeHeight = math.max(40.0, configuredHeight + shapePadding * 2);
    final rowHeight = nodeHeight + shapeMargin * 2;
    final horizontal = data.direction == 'LR' || data.direction == 'RL';
    for (var index = 0; index < diagram.nodes.length; index++) {
      final node = diagram.nodes[index];
      final row = index ~/ columns;
      final column = index % columns;
      final logicalX =
          marginX +
          column * (cellWidth + shapeMargin * 2) +
          cellWidth / 2 +
          (row > 0 ? nextLinePaddingX : 0);
      final logicalY =
          marginY +
          (diagram.title == null ? 0 : 36) +
          row * rowHeight +
          nodeHeight / 2;
      node
        ..width = cellWidth
        ..height = nodeHeight
        ..x = horizontal ? logicalY : logicalX
        ..y = horizontal ? logicalX : logicalY;
    }
    final roots = data.boundaries
        .where((boundary) => boundary.parentBoundaryId == null)
        .toList();
    final subgraphs = {for (final group in diagram.subgraphs) group.id: group};
    final boundaryColumns = math.max(1, data.boundariesPerRow);
    final boundaryCellWidth =
        columns * (cellWidth + shapeMargin * 2) + marginX * 2;
    final boundaryCellHeight =
        math.max(1, (diagram.nodes.length / columns).ceil()) * rowHeight +
        marginY * 2;
    for (var index = 0; index < roots.length; index++) {
      final members =
          subgraphs[roots[index].id]?.nodeIds
              .map((id) => diagram.getNode(id))
              .whereType<MermaidNode>()
              .toList() ??
          const <MermaidNode>[];
      if (members.isEmpty) continue;
      final left = members
          .map((node) => node.x - node.width / 2)
          .reduce(math.min);
      final top = members
          .map((node) => node.y - node.height / 2)
          .reduce(math.min);
      final targetLeft =
          marginX + (index % boundaryColumns) * boundaryCellWidth;
      final targetTop =
          marginY +
          (diagram.title == null ? 0 : 36) +
          (index ~/ boundaryColumns) * boundaryCellHeight;
      for (final node in members) {
        node
          ..x += targetLeft - left
          ..y += targetTop - top;
      }
    }
    if (data.direction == 'BT' && diagram.nodes.isNotEmpty) {
      final maxY = diagram.nodes.map((node) => node.y).reduce(math.max);
      final minY = diagram.nodes.map((node) => node.y).reduce(math.min);
      for (final node in diagram.nodes) {
        node.y = maxY + minY - node.y;
      }
    }
    if (data.direction == 'RL' && diagram.nodes.isNotEmpty) {
      final maxX = diagram.nodes.map((node) => node.x).reduce(math.max);
      final minX = diagram.nodes.map((node) => node.x).reduce(math.min);
      for (final node in diagram.nodes) {
        node.x = maxX + minX - node.x;
      }
    }
    final rows = (diagram.nodes.length / columns).ceil();
    final right = diagram.nodes.fold<double>(
      marginX,
      (value, node) => math.max(value, node.x + node.width / 2),
    );
    final bottom = diagram.nodes.fold<double>(
      marginY,
      (value, node) => math.max(value, node.y + node.height / 2),
    );
    final contentWidth = right + marginX;
    return Size(
      useMaxWidth ? math.max(availableSize.width, contentWidth) : contentWidth,
      math.max(140, bottom + marginY + (rows == 0 ? rowHeight : 0)),
    );
  }
}

class ArchitectureChartLayout {
  const ArchitectureChartLayout();

  Size computeLayout(
    MermaidDiagramData diagram,
    ArchitectureChartData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    final iconSize = data.iconSize;
    final nodeWidth = math.max(iconSize, data.fontSize * 6.5).toDouble();
    final nodeHeight = iconSize + data.fontSize * 1.45;
    final gap = math.max(data.nodeSeparation, 8.0).toDouble();
    final titleOffset = diagram.title == null ? 0.0 : 38.0;
    final nodes = {for (final node in diagram.nodes) node.id: node};
    final items = {for (final item in data.items) item.id: item};
    final groupOrder = <String, int>{
      for (var index = 0; index < data.groups.length; index++)
        data.groups[index].id: index,
    };
    final random = math.Random(
      data.seed == 0 ? DateTime.now().microsecondsSinceEpoch : data.seed,
    );
    final columns = math.max(1, math.sqrt(math.max(1, nodes.length)).ceil());
    for (var index = 0; index < diagram.nodes.length; index++) {
      final node = diagram.nodes[index];
      final isJunction = items[node.id]?.isJunction ?? false;
      final parent = items[node.id]?.parentId;
      final cluster = parent == null ? 0 : (groupOrder[parent] ?? 0) + 1;
      final jitter = data.randomize ? gap * .7 : gap * .08;
      node
        ..width = isJunction ? math.max(12, iconSize * .22) : nodeWidth
        ..height = isJunction ? math.max(12, iconSize * .22) : nodeHeight
        ..x =
            data.padding +
            (index % columns) * (nodeWidth + gap) +
            nodeWidth / 2 +
            cluster * gap * .18 +
            (random.nextDouble() - .5) * jitter
        ..y =
            data.padding +
            titleOffset +
            (index ~/ columns) * (nodeHeight + gap) +
            nodeHeight / 2 +
            cluster * gap * .18 +
            (random.nextDouble() - .5) * jitter;
    }

    final iterations = math.min(data.numIter, 5000);
    final idealSameGroup = iconSize * data.idealEdgeLengthMultiplier;
    for (var iteration = 0; iteration < iterations; iteration++) {
      final cooling = 1 - iteration / math.max(1, iterations);
      for (var left = 0; left < diagram.nodes.length; left++) {
        final a = diagram.nodes[left];
        for (var right = left + 1; right < diagram.nodes.length; right++) {
          final b = diagram.nodes[right];
          var dx = b.x - a.x;
          var dy = b.y - a.y;
          var distance = math.sqrt(dx * dx + dy * dy);
          if (distance < .01) {
            dx = .01;
            dy = .01;
            distance = .014;
          }
          final minimum = (a.width + b.width) / 2 + gap;
          if (distance < minimum) {
            final push = (minimum - distance) * .035 * cooling;
            final px = dx / distance * push;
            final py = dy / distance * push;
            a
              ..x -= px
              ..y -= py;
            b
              ..x += px
              ..y += py;
          }
        }
      }
      for (final edge in data.edges) {
        final from = nodes[edge.from];
        final to = nodes[edge.to];
        if (from == null || to == null) continue;
        final sameGroup =
            items[edge.from]?.parentId == items[edge.to]?.parentId;
        final ideal = sameGroup ? idealSameGroup : iconSize * .5;
        final elasticity = sameGroup ? data.edgeElasticity : .001;
        final horizontal =
            edge.fromPort == ArchitecturePort.left ||
            edge.fromPort == ArchitecturePort.right;
        final sign =
            edge.fromPort == ArchitecturePort.left ||
                edge.fromPort == ArchitecturePort.top
            ? -1.0
            : 1.0;
        final current = horizontal ? to.x - from.x : to.y - from.y;
        final correction = (sign * ideal - current) * elasticity * .025;
        if (horizontal) {
          from.x -= correction / 2;
          to.x += correction / 2;
        } else {
          from.y -= correction / 2;
          to.y += correction / 2;
        }
      }
      _enforceArchitectureAlignments(data, nodes, nodeWidth, nodeHeight, gap);
    }

    _enforceArchitectureAlignments(data, nodes, nodeWidth, nodeHeight, gap);
    if (diagram.nodes.isNotEmpty) {
      final left = diagram.nodes
          .map((node) => node.x - node.width / 2)
          .reduce(math.min);
      final top = diagram.nodes
          .map((node) => node.y - node.height / 2)
          .reduce(math.min);
      final dx = data.padding - left;
      final dy = data.padding + titleOffset - top;
      for (final node in diagram.nodes) {
        node
          ..x += dx
          ..y += dy;
      }
    }
    final right = diagram.nodes.fold<double>(
      0,
      (value, node) => math.max(value, node.x + node.width / 2),
    );
    final bottom = diagram.nodes.fold<double>(
      0,
      (value, node) => math.max(value, node.y + node.height / 2),
    );
    return Size(
      data.useMaxWidth
          ? math.max(availableSize.width, right + data.padding)
          : math.max(data.padding * 2 + 120, right + data.padding),
      math.max(160, bottom + data.padding),
    );
  }

  void _enforceArchitectureAlignments(
    ArchitectureChartData data,
    Map<String, MermaidNode> nodes,
    double nodeWidth,
    double nodeHeight,
    double gap,
  ) {
    for (final alignment in data.alignments) {
      final aligned = alignment.members.map((id) => nodes[id]!).toList();
      if (alignment.axis == ArchitectureAlignmentAxis.row) {
        final y =
            aligned.map((node) => node.y).reduce((a, b) => a + b) /
            aligned.length;
        final startX = aligned.map((node) => node.x).reduce(math.min);
        for (var index = 0; index < aligned.length; index++) {
          aligned[index]
            ..x = startX + index * (nodeWidth + gap)
            ..y = y;
        }
      } else {
        final x =
            aligned.map((node) => node.x).reduce((a, b) => a + b) /
            aligned.length;
        final startY = aligned.map((node) => node.y).reduce(math.min);
        for (var index = 0; index < aligned.length; index++) {
          aligned[index]
            ..x = x
            ..y = startY + index * (nodeHeight + gap);
        }
      }
    }
  }
}

class EventModelingChartLayout {
  const EventModelingChartLayout();

  Size computeLayout(
    MermaidDiagramData diagram,
    EventModelingChartData data,
    MermaidStyle style,
    Size availableSize,
  ) {
    const labelWidth = 160.0;
    const frameWidth = 132.0;
    final frameHeight = math.max(52.0, data.rowHeight);
    final laneHeight = math.max(data.rowHeight, frameHeight + data.padding * 2);
    const frameStep = 112.0;
    final top = data.padding + (data.title == null ? 0.0 : 34.0);
    final lanes = {
      for (var index = 0; index < data.lanes.length; index++)
        data.lanes[index].id: index,
    };
    final nodes = {for (final node in diagram.nodes) node.id: node};
    for (var index = 0; index < data.frames.length; index++) {
      final frame = data.frames[index];
      final node = nodes[frame.id]!;
      node
        ..width = frameWidth
        ..height = frameHeight
        ..x = data.padding + labelWidth + index * frameStep + frameWidth / 2
        ..y = top + lanes[frame.laneId]! * laneHeight + laneHeight / 2;
    }
    final intrinsicWidth =
        data.padding * 2 + labelWidth + data.frames.length * frameStep + 40;
    return Size(
      data.useMaxWidth && availableSize.width.isFinite
          ? math.max(availableSize.width, intrinsicWidth)
          : intrinsicWidth,
      math.max(160, top + data.lanes.length * laneHeight + data.padding),
    );
  }
}

class IshikawaChartLayout {
  const IshikawaChartLayout();

  Size computeLayout(IshikawaChartData data, Size availableSize) {
    final causes = math.max(1, data.effect.children.length);
    final pairs = (causes / 2).ceil();
    final depth = data.effect.depth;
    final intrinsicWidth =
        math.max(620, pairs * 230.0 + 190) + data.diagramPadding * 2;
    final intrinsicHeight =
        math.max(360, 300.0 + math.max(0, depth - 3) * 62) +
        data.diagramPadding * 2;
    return Size(
      data.useMaxWidth
          ? math.max(intrinsicWidth, availableSize.width)
          : intrinsicWidth,
      intrinsicHeight,
    );
  }
}

class RailroadChartLayout {
  const RailroadChartLayout();

  Size computeLayout(RailroadChartData data, Size availableSize) {
    final scale = data.fontSize / 14;
    final contentWidth = data.rules.fold<double>(
      0,
      (width, rule) => math.max(
        width,
        rule.definition.estimatedWidth * scale + data.padding * 2,
      ),
    );
    final contentHeight = data.rules.fold<double>(
      0,
      (height, rule) =>
          height +
          rule.definition.estimatedHeight * scale +
          data.verticalSeparation +
          (data.compactMode ? 25 : 46),
    );
    final intrinsicWidth =
        contentWidth + data.padding * 2 + (data.compactMode ? 140 : 200);
    final intrinsicHeight =
        contentHeight + data.padding * 2 + (data.title == null ? 30 : 60);
    return Size(
      data.useMaxWidth
          ? math.max(availableSize.width, intrinsicWidth)
          : intrinsicWidth,
      math.max(140, intrinsicHeight),
    );
  }
}

class WardleyChartLayout {
  const WardleyChartLayout();

  Size computeLayout(WardleyChartData data, Size availableSize) {
    if (!data.useMaxWidth || !availableSize.width.isFinite) {
      return Size(data.width, data.height);
    }
    final width = math.min(data.width, math.max(1.0, availableSize.width));
    return Size(width, data.height * width / data.width);
  }
}

class CynefinChartLayout {
  const CynefinChartLayout();

  Size computeLayout(CynefinChartData data, Size availableSize) {
    final configuredWidth = data.width + data.padding * 2;
    final configuredHeight = data.height + data.padding * 2;
    return Size(
      data.useMaxWidth
          ? math.max(availableSize.width, configuredWidth)
          : configuredWidth,
      configuredHeight,
    );
  }
}

/// Simple layout engine that arranges nodes in a grid-like pattern
///
/// This is a basic fallback layout when more sophisticated algorithms
/// aren't needed or available.
class SimpleLayoutEngine extends LayoutEngine {
  /// Creates a simple layout engine
  const SimpleLayoutEngine();

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    // Measure all nodes first
    for (final node in diagram.nodes) {
      final size = measureNode(node, style);
      node.width = size.width;
      node.height = size.height;
    }

    final isHorizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;

    // Simple row/column layout
    double x = style.padding;
    double y = style.padding;
    double maxRowHeight = 0;
    double maxWidth = 0;
    double maxHeight = 0;

    final nodesPerRow = isHorizontal
        ? diagram.nodes.length
        : math.sqrt(diagram.nodes.length).ceil();

    for (var i = 0; i < diagram.nodes.length; i++) {
      final node = diagram.nodes[i];

      if (!isHorizontal && i > 0 && i % nodesPerRow == 0) {
        // Move to next row
        x = style.padding;
        y += maxRowHeight + style.nodeSpacingY;
        maxRowHeight = 0;
      }

      node.x = x;
      node.y = y;

      x += node.width + style.nodeSpacingX;
      maxRowHeight = math.max(maxRowHeight, node.height);
      maxWidth = math.max(maxWidth, x);
      maxHeight = math.max(maxHeight, y + node.height);
    }

    return Size(maxWidth + style.padding, maxHeight + style.padding);
  }
}

/// Layout engine for timeline diagrams
class TimelineChartLayout {
  /// Creates a timeline chart layout engine
  const TimelineChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes the layout size for a timeline chart
  Size computeLayout(
    TimelineChartData timelineData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (timelineData.sections.isEmpty) return Size.zero;
    final tasks = timelineData.allEvents;
    final titleHeight = timelineData.title == null ? 0.0 : 44.0;
    final maxEventCount = tasks.fold<int>(
      0,
      (value, task) => math.max(value, task.periods.length),
    );
    final eventHeight = deviceConfig?.deviceType == DeviceType.mobile
        ? 42.0
        : math.max(46.0, timelineData.height.toDouble());
    final horizontal = timelineData.direction == TimelineDirection.leftToRight;
    final intrinsicWidth = horizontal
        ? timelineData.diagramMarginX * 2 +
              timelineData.leftMargin +
              math.max(1, tasks.length) * timelineData.width
        : timelineData.diagramMarginX * 2 +
              timelineData.leftMargin +
              timelineData.width * 2 +
              timelineData.noteMargin;
    final intrinsicHeight = horizontal
        ? timelineData.diagramMarginY * 2 +
              timelineData.padding * 2 +
              titleHeight +
              timelineData.height * 2 +
              timelineData.taskMargin +
              maxEventCount * (eventHeight + timelineData.messageMargin) +
              timelineData.bottomMarginAdj
        : timelineData.diagramMarginY * 2 +
              timelineData.padding * 2 +
              titleHeight +
              timelineData.sections.length * timelineData.height +
              math.max(1, tasks.length) *
                  (eventHeight + timelineData.taskMargin) +
              timelineData.bottomMarginAdj;
    return Size(
      timelineData.useMaxWidth
          ? math.max(availableSize.width, intrinsicWidth)
          : intrinsicWidth,
      intrinsicHeight,
    );
  }
}

/// Layout engine for Kanban diagrams
class KanbanChartLayout {
  /// Creates a Kanban chart layout engine
  const KanbanChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes layout size for Kanban chart
  Size computeLayout(
    KanbanChartData kanbanData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (kanbanData.columns.isEmpty) return Size.zero;

    final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
    // Responsive constants
    final padding = kanbanData.padding;
    final titleHeight = kanbanData.title != null ? 60.0 : 20.0;
    final columnHeaderHeight = isMobile ? 50.0 : 60.0;
    final columnSpacing = isMobile ? 12.0 : 16.0;
    final cardHeight = isMobile ? 90.0 : 110.0; // Base card height
    final cardSpacing = isMobile ? 8.0 : 12.0;

    // Calculate column width strategy
    final totalColumns = kanbanData.columns.length;
    final columnWidth = kanbanData.sectionWidth;

    // Calculate maximum cards in any column
    var maxCards = 0;
    for (final column in kanbanData.columns) {
      if (column.tasks.length > maxCards) {
        maxCards = column.tasks.length;
      }
    }

    // Calculate total height
    final cardsAreaHeight =
        (maxCards * cardHeight) + ((maxCards + 1) * cardSpacing);

    final totalHeight =
        padding + titleHeight + columnHeaderHeight + cardsAreaHeight + padding;

    // Calculate total width
    final requiredWidth =
        columnWidth * totalColumns +
        columnSpacing * math.max(0, totalColumns - 1) +
        padding * 2;
    final totalWidth = kanbanData.useMaxWidth
        ? math.max(requiredWidth, availableSize.width)
        : requiredWidth;

    return Size(totalWidth, totalHeight);
  }
}

/// Layout engine for Radar charts
class RadarChartLayout {
  /// Creates a Radar chart layout engine
  const RadarChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes layout size for Radar chart
  Size computeLayout(
    RadarChartData radarData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (radarData.axes.isEmpty) return Size.zero;

    final intrinsicWidth =
        radarData.width + radarData.marginLeft + radarData.marginRight;
    final intrinsicHeight =
        radarData.height + radarData.marginTop + radarData.marginBottom;
    return Size(
      radarData.useMaxWidth
          ? math.max(intrinsicWidth, availableSize.width)
          : intrinsicWidth,
      intrinsicHeight,
    );
  }
}

/// Layout engine for XY charts
class XYChartLayout {
  /// Creates an XY chart layout engine
  const XYChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes layout size for XY chart
  Size computeLayout(
    XYChartData xyData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (xyData.series.isEmpty) return Size.zero;

    if (!availableSize.width.isFinite || availableSize.width >= xyData.width) {
      return Size(xyData.width, xyData.height);
    }
    final width = math.max(1.0, availableSize.width);
    return Size(width, xyData.height * width / xyData.width);
  }
}
