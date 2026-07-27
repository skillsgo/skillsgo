/*
 * [INPUT]: Depends on Flutter Canvas, the executable GitGraph DAG/configuration, and Mermaid semantic styles.
 * [OUTPUT]: Computes and paints native branch rails, parent edges, typed commits, tags, labels, titles, and three orientations.
 * [POS]: Serves as the dedicated layout and renderer for Mermaid GitGraph diagrams instead of generic graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/git_graph.dart';
import '../models/style.dart';
import 'css_color.dart';

class GitGraphChartLayout {
  const GitGraphChartLayout();

  Size computeLayout(GitGraphChartData data, Size availableSize) {
    final tracks = data.showBranches ? math.max(1, data.branches.length) : 1;
    final mainLength = math.max(220.0, data.commits.length * 50.0 + 90);
    final trackSpacing = data.rotateCommitLabel ? 90.0 : 50.0;
    final crossLength = math.max(
      140.0,
      tracks * trackSpacing + data.nodeLabelHeight,
    );
    final horizontal = data.direction == GitGraphDirection.leftToRight;
    final calculated = Size(
      horizontal ? mainLength : crossLength,
      horizontal ? crossLength : mainLength,
    );
    final intrinsicWidth = calculated.width + data.diagramPadding * 2;
    return Size(
      data.useMaxWidth
          ? math.max(availableSize.width, intrinsicWidth)
          : intrinsicWidth,
      calculated.height + data.diagramPadding * 2 + data.titleTopMargin,
    );
  }
}

class GitGraphPainter extends CustomPainter {
  const GitGraphPainter({required this.data, required this.style});

  final GitGraphChartData data;
  final MermaidStyle style;

  static const _branchColors = <Color>[
    Color(0xff4e79a7),
    Color(0xffe15759),
    Color(0xff59a14f),
    Color(0xfff28e2b),
    Color(0xffaf7aa1),
    Color(0xff76b7b2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final branches = [...data.branches]
      ..sort((a, b) {
        final aOrder = a.order ?? a.creationIndex;
        final bOrder = b.order ?? b.creationIndex;
        final order = aOrder.compareTo(bOrder);
        return order != 0 ? order : a.creationIndex.compareTo(b.creationIndex);
      });
    final trackIndex = <String, int>{
      for (var index = 0; index < branches.length; index++)
        branches[index].name: data.showBranches ? index : 0,
    };
    final titleOffset = data.title == null ? 0.0 : 30.0;
    final origin = data.diagramPadding + data.titleTopMargin + titleOffset;
    const sequenceSpacing = 50.0;
    final trackSpacing = data.rotateCommitLabel ? 90.0 : 50.0;
    final positions = <String, Offset>{};
    for (final commit in data.commits) {
      final sequence = data.parallelCommits
          ? _generation(commit, {
              for (final item in data.commits) item.id: item,
            })
          : commit.sequence;
      final main = origin + 36 + sequence * sequenceSpacing;
      final cross =
          data.diagramPadding + 42 + trackIndex[commit.branch]! * trackSpacing;
      positions[commit.id] = _orient(main, cross, size);
    }

    if (data.title case final title?) {
      _text(
        canvas,
        title,
        Offset(size.width / 2, data.titleTopMargin.toDouble()),
        centered: true,
        bold: true,
        color: parseMermaidCssColor(data.theme.titleColor),
      );
    }

    if (data.showBranches) {
      for (var index = 0; index < branches.length; index++) {
        final color = _branchColor(branches[index].name, branches);
        final commits = data.commits.where(
          (commit) => commit.branch == branches[index].name,
        );
        if (commits.isEmpty) continue;
        final points = commits.map((commit) => positions[commit.id]!).toList();
        final paint = Paint()
          ..color =
              parseMermaidCssColor(data.theme.lineColor) ??
              color.withValues(alpha: .55)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        final startMain = positions.values.isEmpty
            ? points.first
            : _railPoint(points.first, origin + 36, size);
        final endMain = positions.values.isEmpty
            ? points.last
            : _railPoint(
                points.last,
                origin +
                    36 +
                    math.max(0, data.commits.length - 1) * sequenceSpacing,
                size,
              );
        canvas.drawLine(startMain, endMain, paint);
        final labelAnchor = _branchLabelAnchor(points.first);
        _drawBranchLabel(
          canvas,
          branches[index].name,
          labelAnchor,
          color,
          _branchLabelColor(index),
        );
      }
    }

    final commitById = {for (final commit in data.commits) commit.id: commit};
    for (final commit in data.commits) {
      final target = positions[commit.id]!;
      for (final parentId in commit.parents) {
        final source = positions[parentId];
        if (source == null) continue;
        final sourceCommit = commitById[parentId]!;
        _drawParentEdge(
          canvas,
          source,
          target,
          _branchColor(sourceCommit.branch, branches),
        );
      }
    }

    for (final commit in data.commits) {
      final position = positions[commit.id]!;
      final color = _branchColor(commit.branch, branches);
      _drawCommit(canvas, position, commit, color);
      if (data.showCommitLabel &&
          commit.kind != GitCommitKind.cherryPick &&
          (commit.kind != GitCommitKind.merge || commit.customId)) {
        _drawCommitLabel(canvas, position, commit);
      }
      if (commit.tags.isNotEmpty) _drawTags(canvas, position, commit.tags);
    }
  }

  int _generation(GitCommitData commit, Map<String, GitCommitData> commits) {
    var generation = 0;
    var frontier = [...commit.parents];
    final visited = <String>{};
    while (frontier.isNotEmpty) {
      generation++;
      frontier = [
        for (final id in frontier)
          if (visited.add(id)) ...?commits[id]?.parents,
      ];
    }
    return generation;
  }

  Offset _orient(double main, double cross, Size size) =>
      switch (data.direction) {
        GitGraphDirection.leftToRight => Offset(main, cross),
        GitGraphDirection.topToBottom => Offset(cross, main),
        GitGraphDirection.bottomToTop => Offset(cross, size.height - main),
      };

  Offset _branchLabelAnchor(Offset point) => switch (data.direction) {
    GitGraphDirection.leftToRight => point.translate(-34, -25),
    GitGraphDirection.topToBottom => point.translate(14, -30),
    GitGraphDirection.bottomToTop => point.translate(14, 16),
  };

  Offset _railPoint(Offset branchPoint, double main, Size size) =>
      switch (data.direction) {
        GitGraphDirection.leftToRight => Offset(main, branchPoint.dy),
        GitGraphDirection.topToBottom => Offset(branchPoint.dx, main),
        GitGraphDirection.bottomToTop => Offset(
          branchPoint.dx,
          size.height - main,
        ),
      };

  void _drawParentEdge(
    Canvas canvas,
    Offset source,
    Offset target,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(source.dx, source.dy);
    if (data.direction == GitGraphDirection.leftToRight) {
      final middle = (source.dx + target.dx) / 2;
      path.cubicTo(middle, source.dy, middle, target.dy, target.dx, target.dy);
    } else {
      final middle = (source.dy + target.dy) / 2;
      path.cubicTo(source.dx, middle, target.dx, middle, target.dx, target.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawCommit(
    Canvas canvas,
    Offset center,
    GitCommitData commit,
    Color color,
  ) {
    final effective = commit.customKind ?? commit.kind;
    final branchIndex = _branchIndex(commit.branch);
    final inverse = _inverseColor(branchIndex, color);
    final mergeColor = parseMermaidCssColor(data.theme.mergeColor) ?? color;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    switch (effective) {
      case GitCommitKind.highlight:
        canvas
          ..drawRect(
            Rect.fromCenter(center: center, width: 20, height: 20),
            Paint()..color = inverse,
          )
          ..drawRect(
            Rect.fromCenter(center: center, width: 12, height: 12),
            Paint()..color = mergeColor,
          );
        break;
      case GitCommitKind.merge:
        canvas
          ..drawCircle(center, 10, Paint()..color = color)
          ..drawCircle(center, 6, Paint()..color = mergeColor);
        break;
      case GitCommitKind.reverse:
        canvas
          ..drawCircle(center, 10, Paint()..color = color)
          ..drawLine(
            center - const Offset(5, 5),
            center + const Offset(5, 5),
            stroke,
          )
          ..drawLine(
            center + const Offset(-5, 5),
            center + const Offset(5, -5),
            stroke,
          );
        break;
      case GitCommitKind.cherryPick:
        canvas.drawCircle(center, 10, Paint()..color = color);
        final glyph = Paint()
          ..color = Color(style.backgroundColor)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas
          ..drawCircle(center + const Offset(-3, 2), 2.75, glyph)
          ..drawCircle(center + const Offset(3, 2), 2.75, glyph)
          ..drawLine(
            center + const Offset(-3, 1),
            center + const Offset(0, -5),
            glyph,
          )
          ..drawLine(
            center + const Offset(3, 1),
            center + const Offset(0, -5),
            glyph,
          );
        break;
      case GitCommitKind.normal:
        canvas.drawCircle(center, 10, Paint()..color = color);
        break;
    }
  }

  void _drawCommitLabel(Canvas canvas, Offset center, GitCommitData commit) {
    final label = commit.id;
    final fontSize = data.theme.commitLabelFontSize ?? 10;
    final painter = _textPainter(
      label,
      fontSize,
      color: parseMermaidCssColor(data.theme.commitLabelColor),
    );
    painter.layout(maxWidth: data.nodeLabelWidth);
    canvas.save();
    final offset = center.translate(data.nodeLabelX, data.nodeLabelY + 17);
    canvas.translate(offset.dx, offset.dy);
    if (data.rotateCommitLabel) canvas.rotate(-math.pi / 4);
    final background = parseMermaidCssColor(data.theme.commitLabelBackground);
    if (background != null) {
      canvas.drawRect(
        Rect.fromLTWH(-2, -2, painter.width + 4, painter.height + 4),
        Paint()..color = background.withValues(alpha: .5),
      );
    }
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawTags(Canvas canvas, Offset center, List<String> tags) {
    final text = tags.join(', ');
    final painter = _textPainter(
      text,
      data.theme.tagLabelFontSize ?? 10,
      color: parseMermaidCssColor(data.theme.tagLabelColor),
    )..layout();
    final rect = Rect.fromLTWH(
      center.dx - painter.width / 2 - 4,
      center.dy - 30,
      painter.width + 8,
      17,
    );
    final background =
        parseMermaidCssColor(data.theme.tagLabelBackground) ??
        const Color(0xffffecb3);
    final border = parseMermaidCssColor(data.theme.tagLabelBorder);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = background,
    );
    if (border != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke,
      );
    }
    painter.paint(canvas, Offset(rect.left + 4, rect.top + 2));
  }

  Color _branchColor(String name, List<GitBranchData> branches) {
    final index = math.max(
      0,
      branches.indexWhere((branch) => branch.name == name),
    );
    return parseMermaidCssColor(
          index < data.theme.branchColors.length
              ? data.theme.branchColors[index]
              : null,
        ) ??
        _branchColors[index % _branchColors.length];
  }

  int _branchIndex(String name) => math.max(
    0,
    ([...data.branches]..sort((a, b) {
          final left = a.order ?? a.creationIndex;
          final right = b.order ?? b.creationIndex;
          return left == right
              ? a.creationIndex.compareTo(b.creationIndex)
              : left.compareTo(right);
        }))
        .indexWhere((branch) => branch.name == name),
  );

  Color _inverseColor(int index, Color fallback) {
    final themed = parseMermaidCssColor(
      index < data.theme.inverseColors.length
          ? data.theme.inverseColors[index]
          : null,
    );
    if (themed != null) return themed;
    final value = fallback.toARGB32();
    return Color((value & 0xff000000) | (~value & 0x00ffffff));
  }

  Color _branchLabelColor(int index) =>
      parseMermaidCssColor(
        index < data.theme.branchLabelColors.length
            ? data.theme.branchLabelColors[index]
            : null,
      ) ??
      Color(style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor);

  void _drawBranchLabel(
    Canvas canvas,
    String value,
    Offset anchor,
    Color background,
    Color foreground,
  ) {
    final painter = _textPainter(value, 12, bold: true, color: foreground)
      ..layout();
    final rect = Rect.fromLTWH(
      anchor.dx - 6,
      anchor.dy - 3,
      painter.width + 12,
      painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = background,
    );
    painter.paint(canvas, Offset(rect.left + 6, rect.top + 3));
  }

  void _text(
    Canvas canvas,
    String value,
    Offset anchor, {
    bool centered = false,
    bool bold = false,
    Color? color,
  }) {
    final painter = _textPainter(value, 12, bold: bold, color: color)..layout();
    painter.paint(
      canvas,
      centered ? anchor.translate(-painter.width / 2, 0) : anchor,
    );
  }

  TextPainter _textPainter(
    String value,
    double size, {
    bool bold = false,
    Color? color,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color:
            color ??
            Color(
              style.defaultNodeStyle.textColor ??
                  MermaidColors.defaultTextColor,
            ),
        fontSize: size,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        fontFamily: style.fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  );

  @override
  bool shouldRepaint(GitGraphPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
