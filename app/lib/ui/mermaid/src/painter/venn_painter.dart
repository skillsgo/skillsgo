/*
 * [INPUT]: Depends on Flutter Canvas, configured Venn subset/annotation data, target styles, and Mermaid semantic colors.
 * [OUTPUT]: Paints optimized area-proportional multi-set circles, exact intersection fills, configured target styles/theme colors, region-aware labels/annotations, and optional debug layout markers.
 * [POS]: Serves as the dedicated native painter for Mermaid Venn diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/style.dart';
import '../models/venn.dart';
import 'css_color.dart';

class VennPainter extends CustomPainter {
  const VennPainter({required this.data, required this.style});

  final VennChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final titleHeight = data.title == null ? 0.0 : 32.0;
    final area = Rect.fromLTWH(
      0,
      titleHeight,
      size.width,
      size.height - titleHeight,
    );
    if (data.title case final title?) {
      _text(
        canvas,
        title,
        Offset(size.width / 2, data.padding),
        32 * size.width / 1600,
        FontWeight.normal,
        _color(data.theme.titleTextColor),
        TextAlign.center,
      );
    }
    final sets = data.individualSets;
    final circles = _VennLayout(data.subsets).compute(area, data.padding);
    final colors = [
      0xFF3B82F6,
      0xFFEF4444,
      0xFF22C55E,
      0xFFF59E0B,
      0xFFA855F7,
      0xFF06B6D4,
    ];

    for (var index = 0; index < sets.length; index++) {
      final subset = sets[index];
      final circle = circles[subset.sets.single];
      if (circle == null) continue;
      final center = circle.center;
      final radius = circle.radius;
      final color =
          _color(
            index < data.theme.colors.length ? data.theme.colors[index] : null,
          ) ??
          Color(colors[index % colors.length]);
      final custom = data.styleForSets(subset.sets);
      final fill = _color(custom['fill']) ?? color;
      final stroke = _color(custom['stroke']) ?? color;
      final opacity =
          double.tryParse(custom['fill-opacity'] ?? custom['opacity'] ?? '') ??
          .1;
      final strokeWidth = double.tryParse(
        (custom['stroke-width'] ?? '').replaceFirst(RegExp(r'px$'), ''),
      );
      if (data.handDrawn) {
        _roughCircle(
          canvas,
          center,
          radius,
          fill,
          stroke,
          strokeWidth ?? 1.5,
          index,
        );
      } else {
        canvas
          ..drawCircle(
            center,
            radius,
            Paint()..color = fill.withValues(alpha: opacity.clamp(0, 1)),
          )
          ..drawCircle(
            center,
            radius,
            Paint()
              ..color = stroke.withValues(alpha: .8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth ?? 1.5,
          );
      }
      final labelCenter = _regionCenter(subset.sets, circles);
      _centerText(
        canvas,
        subset.label ?? subset.sets.single,
        labelCenter,
        48 * size.width / 1600,
        _color(custom['color']) ?? _color(data.theme.setTextColor),
      );
      if (data.useDebugLayout) {
        canvas.drawCircle(center, 3, Paint()..color = Colors.black);
      }
    }

    for (final subset in data.subsets.where(
      (subset) => subset.sets.length > 1,
    )) {
      final custom = data.styleForSets(subset.sets);
      if (_color(custom['fill']) case final fill?) {
        final path = _intersectionPath(subset.sets, circles);
        if (path != null) {
          if (data.handDrawn) {
            _crossHatch(canvas, path, fill, size);
          } else {
            canvas.drawPath(path, Paint()..color = fill);
          }
        }
      }
      _centerText(
        canvas,
        subset.label ?? subset.size.toString(),
        _regionCenter(subset.sets, circles),
        48 * size.width / 1600,
        _color(custom['color']) ?? _color(data.theme.setTextColor),
      );
    }
    final annotationGroups = <String, List<VennAnnotation>>{};
    for (final annotation in data.annotations) {
      annotationGroups
          .putIfAbsent(
            (List<String>.of(annotation.sets)..sort()).join('|'),
            () => [],
          )
          .add(annotation);
    }
    final annotationSize = 40 * size.width / 1600;
    for (final annotations in annotationGroups.values) {
      final center = _regionCenter(annotations.first.sets, circles);
      final columns = math.max(1, math.sqrt(annotations.length).ceil());
      final rows = (annotations.length / columns).ceil();
      final columnWidth = math.max(56.0, annotationSize * 4.5);
      final rowHeight = math.max(20.0, annotationSize * 1.6);
      for (var index = 0; index < annotations.length; index++) {
        final annotation = annotations[index];
        final column = index % columns;
        final row = index ~/ columns;
        _centerText(
          canvas,
          annotation.label ?? annotation.id,
          center +
              Offset(
                (column - (columns - 1) / 2) * columnWidth,
                (row - (rows - 1) / 2) * rowHeight,
              ),
          annotationSize,
          _color(data.styleForAnnotation(annotation.id)['color']) ??
              _color(data.theme.setTextColor),
        );
      }
    }
  }

  void _centerText(
    Canvas canvas,
    String text,
    Offset center,
    double size, [
    Color? color,
  ]) {
    final painter = _painter(text, size, FontWeight.w500, color)
      ..layout(maxWidth: 140);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    FontWeight weight, [
    Color? color,
    TextAlign align = TextAlign.left,
  ]) {
    final painter = _painter(text, size, weight, color)..layout(maxWidth: 240);
    painter.paint(
      canvas,
      align == TextAlign.center
          ? offset - Offset(painter.width / 2, 0)
          : offset,
    );
  }

  Path? _intersectionPath(List<String> ids, Map<String, _VennCircle> circles) {
    Path? path;
    for (final id in ids) {
      final circle = circles[id];
      if (circle == null) return null;
      final oval = Path()
        ..addOval(
          Rect.fromCircle(center: circle.center, radius: circle.radius),
        );
      path = path == null
          ? oval
          : Path.combine(PathOperation.intersect, path, oval);
    }
    return path;
  }

  void _roughCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color fill,
    Color stroke,
    double strokeWidth,
    int salt,
  ) {
    Path outline(int pass) {
      final path = Path();
      const points = 72;
      for (var index = 0; index <= points; index++) {
        final angle = index * math.pi * 2 / points;
        final jitter =
            (_random(data.handDrawnSeed + salt * 997 + pass * 131 + index) -
                .5) *
            math.max(1.0, radius * .018);
        final point =
            center +
            Offset(math.cos(angle), math.sin(angle)) * (radius + jitter);
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path..close();
    }

    final clip = outline(0);
    canvas
      ..drawPath(clip, Paint()..color = fill.withValues(alpha: .3))
      ..save()
      ..clipPath(clip);
    final hatch = Paint()
      ..color = fill.withValues(alpha: .48)
      ..strokeWidth = 1;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final gap = math.max(5.0, radius / 16);
    for (var x = bounds.left - bounds.height; x < bounds.right; x += gap) {
      canvas.drawLine(
        Offset(x, bounds.bottom),
        Offset(x + bounds.width + bounds.height, bounds.top),
        hatch,
      );
    }
    canvas.restore();
    for (var pass = 0; pass < 2; pass++) {
      canvas.drawPath(
        outline(pass + 1),
        Paint()
          ..color = stroke.withValues(alpha: pass == 0 ? .9 : .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = pass == 0
              ? strokeWidth
              : math.max(.5, strokeWidth * .55),
      );
    }
  }

  void _crossHatch(Canvas canvas, Path path, Color color, Size size) {
    canvas
      ..save()
      ..clipPath(path);
    final paint = Paint()
      ..color = color.withValues(alpha: .7)
      ..strokeWidth = 1.2;
    const gap = 7.0;
    for (var offset = -size.height; offset < size.width; offset += gap) {
      canvas
        ..drawLine(
          Offset(offset, size.height),
          Offset(offset + size.height, 0),
          paint,
        )
        ..drawLine(
          Offset(offset, 0),
          Offset(offset + size.height, size.height),
          paint,
        );
    }
    canvas.restore();
  }

  double _random(int seed) {
    var value = (seed + 0x6D2B79F5).toSigned(32);
    value = (value ^ (value >>> 15)) * (value | 1);
    value ^= value + ((value ^ (value >>> 7)) * (value | 61));
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  }

  Offset _regionCenter(
    List<String> selected,
    Map<String, _VennCircle> circles,
  ) {
    final included = selected
        .map((id) => circles[id])
        .whereType<_VennCircle>()
        .toList();
    if (included.isEmpty) return Offset.zero;
    final excluded = circles.entries
        .where((entry) => !selected.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    var best =
        included.fold<Offset>(
          Offset.zero,
          (sum, circle) => sum + circle.center,
        ) /
        included.length.toDouble();
    var bestMargin = -double.infinity;
    final left = included
        .map((circle) => circle.center.dx - circle.radius)
        .reduce(math.max);
    final right = included
        .map((circle) => circle.center.dx + circle.radius)
        .reduce(math.min);
    final top = included
        .map((circle) => circle.center.dy - circle.radius)
        .reduce(math.max);
    final bottom = included
        .map((circle) => circle.center.dy + circle.radius)
        .reduce(math.min);
    for (var yIndex = 0; yIndex <= 24; yIndex++) {
      for (var xIndex = 0; xIndex <= 32; xIndex++) {
        final point = Offset(
          left + (right - left) * xIndex / 32,
          top + (bottom - top) * yIndex / 24,
        );
        var margin = double.infinity;
        for (final circle in included) {
          margin = math.min(
            margin,
            circle.radius - (point - circle.center).distance,
          );
        }
        for (final circle in excluded) {
          margin = math.min(
            margin,
            (point - circle.center).distance - circle.radius,
          );
        }
        if (margin > bestMargin) {
          bestMargin = margin;
          best = point;
        }
      }
    }
    return best;
  }

  TextPainter _painter(
    String text,
    double size,
    FontWeight weight, [
    Color? color,
  ]) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color ?? Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
        fontSize: size,
        fontWeight: weight,
        fontFamily: style.fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    textAlign: TextAlign.center,
    ellipsis: '…',
  );

  Color? _color(String? value) => parseMermaidCssColor(value);

  @override
  bool shouldRepaint(VennPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}

class _VennCircle {
  _VennCircle({required this.center, required this.radius, required this.size});

  Offset center;
  double radius;
  final double size;
}

class _VennLayout {
  _VennLayout(this.source);

  final List<VennSubset> source;

  Map<String, _VennCircle> compute(Rect bounds, double padding) {
    final circles = <String, _VennCircle>{
      for (final subset in source.where((subset) => subset.sets.length == 1))
        subset.sets.single: _VennCircle(
          center: const Offset(1e10, 1e10),
          radius: math.sqrt(subset.size / math.pi),
          size: subset.size,
        ),
    };
    if (circles.isEmpty) return circles;
    final pairs = _pairwise(circles);
    final overlaps = <String, List<({String other, double size})>>{
      for (final id in circles.keys) id: [],
    };
    for (final pair in pairs) {
      overlaps[pair.sets[0]]!.add((other: pair.sets[1], size: pair.size));
      overlaps[pair.sets[1]]!.add((other: pair.sets[0], size: pair.size));
    }
    final order = circles.keys.toList()
      ..sort((a, b) {
        final aTotal = overlaps[a]!.fold<double>(
          0,
          (sum, item) => sum + item.size,
        );
        final bTotal = overlaps[b]!.fold<double>(
          0,
          (sum, item) => sum + item.size,
        );
        final compared = bTotal.compareTo(aTotal);
        return compared == 0 ? a.compareTo(b) : compared;
      });
    final positioned = <String>{order.first};
    circles[order.first]!.center = Offset.zero;
    for (final id in order.skip(1)) {
      final circle = circles[id]!;
      final relevant =
          overlaps[id]!
              .where((item) => positioned.contains(item.other))
              .toList()
            ..sort((a, b) => b.size.compareTo(a.size));
      final candidates = <Offset>[];
      for (var index = 0; index < relevant.length; index++) {
        final first = circles[relevant[index].other]!;
        final firstDistance = _distanceForArea(
          circle.radius,
          first.radius,
          relevant[index].size,
        );
        candidates.addAll([
          first.center + Offset(firstDistance, 0),
          first.center - Offset(firstDistance, 0),
          first.center + Offset(0, firstDistance),
          first.center - Offset(0, firstDistance),
        ]);
        for (
          var otherIndex = index + 1;
          otherIndex < relevant.length;
          otherIndex++
        ) {
          final second = circles[relevant[otherIndex].other]!;
          final secondDistance = _distanceForArea(
            circle.radius,
            second.radius,
            relevant[otherIndex].size,
          );
          candidates.addAll(
            _circleIntersections(
              first.center,
              firstDistance,
              second.center,
              secondDistance,
            ),
          );
        }
      }
      if (candidates.isEmpty) {
        candidates.add(Offset(order.indexOf(id).toDouble(), 0));
      }
      var best = candidates.first;
      var bestLoss = double.infinity;
      for (final candidate in candidates) {
        circle.center = candidate;
        final loss = _pairLoss(circles, pairs);
        if (loss < bestLoss) {
          bestLoss = loss;
          best = candidate;
        }
      }
      circle.center = best;
      positioned.add(id);
    }
    _refine(circles, pairs, order);
    _fit(circles.values.toList(), bounds, padding);
    return circles;
  }

  void _refine(
    Map<String, _VennCircle> circles,
    List<VennSubset> pairs,
    List<String> order,
  ) {
    var step =
        circles.values.map((circle) => circle.radius).reduce(math.max) / 3;
    var bestLoss = _loss(circles, pairs);
    const directions = [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
      Offset(.70710678118, .70710678118),
      Offset(-.70710678118, .70710678118),
      Offset(.70710678118, -.70710678118),
      Offset(-.70710678118, -.70710678118),
    ];
    for (var iteration = 0; iteration < 36 && step > 1e-5; iteration++) {
      var improved = false;
      for (final id in order.skip(1)) {
        final circle = circles[id]!;
        final original = circle.center;
        var localBest = original;
        for (final direction in directions) {
          circle.center = original + direction * step;
          final candidate = _loss(circles, pairs);
          if (candidate + 1e-12 < bestLoss) {
            bestLoss = candidate;
            localBest = circle.center;
            improved = true;
          }
        }
        circle.center = localBest;
      }
      if (!improved) step *= .5;
    }
  }

  List<VennSubset> _pairwise(Map<String, _VennCircle> circles) {
    final pairs = <String, VennSubset>{};
    for (final subset in source.where((subset) => subset.sets.length == 2)) {
      final ids = List<String>.of(subset.sets)..sort();
      pairs[ids.join('|')] = VennSubset(sets: ids, size: subset.size);
    }
    for (final subset in source.where((subset) => subset.sets.length >= 3)) {
      final ids = List<String>.of(subset.sets)..sort();
      for (var left = 0; left < ids.length - 1; left++) {
        for (var right = left + 1; right < ids.length; right++) {
          final pair = [ids[left], ids[right]];
          pairs.putIfAbsent(
            pair.join('|'),
            () => VennSubset(
              sets: pair,
              size:
                  math.min(circles[pair[0]]!.size, circles[pair[1]]!.size) / 4,
            ),
          );
        }
      }
    }
    final ids = circles.keys.toList()..sort();
    for (var left = 0; left < ids.length - 1; left++) {
      for (var right = left + 1; right < ids.length; right++) {
        final pair = [ids[left], ids[right]];
        pairs.putIfAbsent(
          pair.join('|'),
          () => VennSubset(sets: pair, size: 0),
        );
      }
    }
    return pairs.values.toList();
  }

  double _pairLoss(Map<String, _VennCircle> circles, List<VennSubset> pairs) {
    var loss = 0.0;
    for (final pair in pairs) {
      final left = circles[pair.sets[0]]!;
      final right = circles[pair.sets[1]]!;
      final actual = _overlapArea(
        left.radius,
        right.radius,
        (left.center - right.center).distance,
      );
      final delta = actual - pair.size;
      loss += delta * delta;
    }
    return loss;
  }

  double _loss(Map<String, _VennCircle> circles, List<VennSubset> pairs) {
    var loss = _pairLoss(circles, pairs);
    for (final subset in source.where((subset) => subset.sets.length > 2)) {
      final selected = subset.sets
          .map((id) => circles[id])
          .whereType<_VennCircle>()
          .toList();
      if (selected.length != subset.sets.length) continue;
      final delta = _multiCircleArea(selected) - subset.size;
      loss += delta * delta;
    }
    return loss;
  }

  void _fit(List<_VennCircle> circles, Rect bounds, double padding) {
    final left = circles
        .map((circle) => circle.center.dx - circle.radius)
        .reduce(math.min);
    final right = circles
        .map((circle) => circle.center.dx + circle.radius)
        .reduce(math.max);
    final top = circles
        .map((circle) => circle.center.dy - circle.radius)
        .reduce(math.min);
    final bottom = circles
        .map((circle) => circle.center.dy + circle.radius)
        .reduce(math.max);
    final sourceWidth = math.max(1e-9, right - left);
    final sourceHeight = math.max(1e-9, bottom - top);
    final target = bounds.deflate(
      math.min(padding, math.min(bounds.width, bounds.height) / 4),
    );
    final scale = math.min(
      target.width / sourceWidth,
      target.height / sourceHeight,
    );
    final renderedWidth = sourceWidth * scale;
    final renderedHeight = sourceHeight * scale;
    final origin = Offset(
      target.center.dx - renderedWidth / 2,
      target.center.dy - renderedHeight / 2,
    );
    for (final circle in circles) {
      circle
        ..center =
            origin +
            Offset(
              (circle.center.dx - left) * scale,
              (circle.center.dy - top) * scale,
            )
        ..radius *= scale;
    }
  }
}

double _distanceForArea(double firstRadius, double secondRadius, double area) {
  final contained = math.pi * math.pow(math.min(firstRadius, secondRadius), 2);
  if (area >= contained - 1e-10) return (firstRadius - secondRadius).abs();
  if (area <= 1e-10) return firstRadius + secondRadius;
  var low = 0.0;
  var high = firstRadius + secondRadius;
  for (var iteration = 0; iteration < 60; iteration++) {
    final middle = (low + high) / 2;
    if (_overlapArea(firstRadius, secondRadius, middle) > area) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return (low + high) / 2;
}

double _overlapArea(double firstRadius, double secondRadius, double distance) {
  if (distance >= firstRadius + secondRadius) return 0;
  if (distance <= (firstRadius - secondRadius).abs()) {
    return math.pi * math.pow(math.min(firstRadius, secondRadius), 2);
  }
  final first = math.acos(
    ((distance * distance +
                firstRadius * firstRadius -
                secondRadius * secondRadius) /
            (2 * distance * firstRadius))
        .clamp(-1, 1),
  );
  final second = math.acos(
    ((distance * distance +
                secondRadius * secondRadius -
                firstRadius * firstRadius) /
            (2 * distance * secondRadius))
        .clamp(-1, 1),
  );
  final triangle =
      .5 *
      math.sqrt(
        math.max(
          0,
          (-distance + firstRadius + secondRadius) *
              (distance + firstRadius - secondRadius) *
              (distance - firstRadius + secondRadius) *
              (distance + firstRadius + secondRadius),
        ),
      );
  return firstRadius * firstRadius * first +
      secondRadius * secondRadius * second -
      triangle;
}

double _multiCircleArea(List<_VennCircle> circles) {
  final left = circles
      .map((circle) => circle.center.dx - circle.radius)
      .reduce(math.max);
  final right = circles
      .map((circle) => circle.center.dx + circle.radius)
      .reduce(math.min);
  if (right <= left) return 0;
  const slices = 64;
  final width = (right - left) / slices;
  double heightAt(double x) {
    var top = -double.infinity;
    var bottom = double.infinity;
    for (final circle in circles) {
      final dx = x - circle.center.dx;
      if (dx.abs() >= circle.radius) return 0;
      final dy = math.sqrt(
        math.max(0, circle.radius * circle.radius - dx * dx),
      );
      top = math.max(top, circle.center.dy - dy);
      bottom = math.min(bottom, circle.center.dy + dy);
    }
    return math.max(0, bottom - top);
  }

  var sum = heightAt(left) + heightAt(right);
  for (var index = 1; index < slices; index++) {
    sum += heightAt(left + width * index) * (index.isOdd ? 4 : 2);
  }
  return sum * width / 3;
}

List<Offset> _circleIntersections(
  Offset first,
  double firstRadius,
  Offset second,
  double secondRadius,
) {
  final distance = (second - first).distance;
  if (distance == 0 ||
      distance >= firstRadius + secondRadius ||
      distance <= (firstRadius - secondRadius).abs()) {
    return const [];
  }
  final along =
      (firstRadius * firstRadius -
          secondRadius * secondRadius +
          distance * distance) /
      (2 * distance);
  final height = math.sqrt(
    math.max(0, firstRadius * firstRadius - along * along),
  );
  final direction = (second - first) / distance;
  final midpoint = first + direction * along;
  final perpendicular = Offset(-direction.dy, direction.dx) * height;
  return [midpoint + perpendicular, midpoint - perpendicular];
}
