/*
 * [INPUT]: Depends on Flutter Canvas, configured weighted Treemap hierarchy, resolved class styles, d3 color scales/value formatting, and Mermaid semantic colors.
 * [OUTPUT]: Paints rounded d3-squarify geometry, section headers, adaptive leaf labels/values, class styles, and responsive output.
 * [POS]: Serves as the dedicated native painter for Mermaid Treemap diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/style.dart';
import '../models/treemap.dart';

class TreemapPainter extends CustomPainter {
  const TreemapPainter({required this.data, required this.style});

  final TreemapChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final titleHeight = data.title == null ? 0.0 : 30.0;
    final logicalWidth = data.nodeWidth * 10;
    final logicalHeight = data.nodeHeight * 10 + titleHeight;
    final scale = math.min(
      size.width / logicalWidth,
      size.height / logicalHeight,
    );
    canvas
      ..save()
      ..scale(scale, scale);
    if (data.title case final title?) {
      _text(
        canvas,
        title,
        Offset(logicalWidth / 2, 15),
        14,
        FontWeight.normal,
        logicalWidth,
        _color(data.theme.titleColor),
        TextAlign.center,
      );
    }
    final layout = _TreemapLayout(
      data.roots,
      Size(logicalWidth, data.nodeHeight * 10),
      data.padding,
    ).compute();
    final colors = _TreemapColors(data, style, layout);
    canvas.save();
    canvas.translate(0, titleHeight);
    for (final item in layout.where((item) => item.children.isNotEmpty)) {
      if (item.depth == 0) continue;
      _paintBranch(canvas, item, colors);
    }
    for (final item in layout.where((item) => item.children.isEmpty)) {
      if (item.depth == 0) continue;
      _paintLeaf(canvas, item, colors);
    }
    canvas
      ..restore()
      ..restore();
  }

  void _paintBranch(Canvas canvas, _TreemapBox item, _TreemapColors colors) {
    final node = item.node!;
    final rect = item.rect;
    if (rect.isEmpty) return;
    final fill = _color(node.fillColor) ?? colors.fill(node.label);
    final stroke = _color(node.strokeColor) ?? colors.peer(node.label);
    canvas
      ..drawRect(rect, Paint()..color = fill.withValues(alpha: .6))
      ..drawRect(
        rect,
        Paint()
          ..color = stroke.withValues(alpha: .4)
          ..strokeWidth = node.strokeWidth ?? data.borderWidth
          ..style = PaintingStyle.stroke,
      );
    final labelColor = _color(node.textColor) ?? colors.label(node.label);
    _text(
      canvas,
      node.label,
      rect.topLeft + const Offset(6, 5.5),
      data.labelFontSize,
      FontWeight.bold,
      math.max(1, rect.width - (data.showValues ? 56 : 12)),
      labelColor,
    );
    if (data.showValues && item.value > 0) {
      _text(
        canvas,
        _number(item.value, data.valueFormat),
        Offset(rect.right - 10, rect.top + 6),
        data.valueFontSize,
        FontWeight.normal,
        math.max(1, rect.width - 12),
        labelColor,
        TextAlign.right,
        FontStyle.italic,
      );
    }
  }

  void _paintLeaf(Canvas canvas, _TreemapBox item, _TreemapColors colors) {
    final node = item.node!;
    final rect = item.rect;
    if (rect.width <= 0 || rect.height <= 0) return;
    final inheritedKey = item.parent?.node?.label ?? node.label;
    final fill = _color(node.fillColor) ?? colors.fill(inheritedKey);
    final stroke = _color(node.strokeColor) ?? fill;
    canvas
      ..drawRect(rect, Paint()..color = fill.withValues(alpha: .3))
      ..drawRect(
        rect,
        Paint()
          ..color = stroke
          ..strokeWidth = node.strokeWidth ?? data.borderWidth
          ..style = PaintingStyle.stroke,
      );
    final complex = colors.leafCount > 20;
    final padding = complex ? 2.0 : 4.0;
    final availableWidth = rect.width - padding * 2;
    final availableHeight = rect.height - padding * 2;
    if (availableWidth < (complex ? 8 : 10) ||
        availableHeight < (complex ? 8 : 10)) {
      return;
    }
    final labelColor = _color(node.textColor) ?? colors.label(node.label);
    var labelSize = complex
        ? math.min(16.0, data.labelFontSize)
        : data.labelFontSize;
    final minLabel = complex ? 4.0 : 8.0;
    final minValue = complex ? 4.0 : 6.0;
    final maxValue = complex
        ? math.min(14.0, data.valueFontSize)
        : data.valueFontSize;
    final spacing = complex ? 1.0 : 2.0;
    while (labelSize > minLabel &&
        _measure(node.label, labelSize) > availableWidth) {
      labelSize--;
    }
    var valueSize = math.max(
      minValue,
      math.min(maxValue, (labelSize * .6).roundToDouble()),
    );
    while (labelSize > minLabel &&
        labelSize + spacing + valueSize > availableHeight) {
      labelSize--;
      valueSize = math.max(
        minValue,
        math.min(maxValue, (labelSize * .6).roundToDouble()),
      );
    }
    if ((!complex && _measure(node.label, labelSize) > availableWidth) ||
        availableHeight < labelSize) {
      return;
    }
    final center = rect.center;
    _text(
      canvas,
      node.label,
      Offset(center.dx, center.dy - labelSize / 2),
      labelSize,
      FontWeight.normal,
      availableWidth,
      labelColor,
      TextAlign.center,
    );
    if (data.showValues && node.value != null && node.value! > 0) {
      final value = _number(node.value!, data.valueFormat);
      if (_measure(value, valueSize) <= availableWidth &&
          center.dy + labelSize / 2 + spacing + valueSize <= rect.bottom - 4) {
        _text(
          canvas,
          value,
          Offset(center.dx, center.dy + labelSize / 2 + spacing),
          valueSize,
          FontWeight.normal,
          availableWidth,
          labelColor,
          TextAlign.center,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    FontWeight weight, [
    double maxWidth = 300,
    Color? color,
    TextAlign align = TextAlign.left,
    FontStyle fontStyle = FontStyle.normal,
  ]) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
          fontSize: size,
          fontWeight: weight,
          fontStyle: fontStyle,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth.clamp(1, 300));
    painter.paint(
      canvas,
      Offset(switch (align) {
        TextAlign.center => offset.dx - painter.width / 2,
        TextAlign.right || TextAlign.end => offset.dx - painter.width,
        _ => offset.dx,
      }, offset.dy),
    );
  }

  double _measure(String text, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontFamily: style.fontFamily),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  String _number(double value, String format) {
    return formatTreemapValue(value, format);
  }

  Color? _color(String? value) => parseTreemapColor(value);

  @override
  bool shouldRepaint(TreemapPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}

class _TreemapLayout {
  _TreemapLayout(this.roots, this.size, this.innerPadding);

  final List<TreemapNode> roots;
  final Size size;
  final double innerPadding;
  var _order = 0;

  List<_TreemapBox> compute() {
    final root = _TreemapBox(null, null, 0, _order++);
    root.children.addAll(roots.map((node) => _build(node, root, 1)));
    _sumAndSort(root);
    root
      ..x0 = 0
      ..y0 = 0
      ..x1 = size.width
      ..y1 = size.height;
    final output = <_TreemapBox>[];
    _position(root, <double>[0], output);
    for (final item in output) {
      item
        ..x0 = item.x0.roundToDouble()
        ..y0 = item.y0.roundToDouble()
        ..x1 = item.x1.roundToDouble()
        ..y1 = item.y1.roundToDouble();
    }
    return output;
  }

  _TreemapBox _build(TreemapNode node, _TreemapBox parent, int depth) {
    final box = _TreemapBox(node, parent, depth, _order++);
    box.children.addAll(
      node.children.map((child) => _build(child, box, depth + 1)),
    );
    return box;
  }

  double _sumAndSort(_TreemapBox node) {
    node.value =
        node.node?.value ??
        node.children.fold(0.0, (sum, child) => sum + _sumAndSort(child));
    if (node.node?.value != null) {
      for (final child in node.children) {
        _sumAndSort(child);
      }
    }
    node.children.sort((a, b) {
      final valueOrder = b.value.compareTo(a.value);
      return valueOrder == 0 ? a.order.compareTo(b.order) : valueOrder;
    });
    return node.value;
  }

  void _position(
    _TreemapBox node,
    List<double> paddingStack,
    List<_TreemapBox> output,
  ) {
    final inherited = paddingStack[node.depth];
    node
      ..x0 += inherited
      ..y0 += inherited
      ..x1 -= inherited
      ..y1 -= inherited;
    if (node.x1 < node.x0) node.x0 = node.x1 = (node.x0 + node.x1) / 2;
    if (node.y1 < node.y0) node.y0 = node.y1 = (node.y0 + node.y1) / 2;
    output.add(node);
    if (node.children.isEmpty) return;
    final halfInner = innerPadding / 2;
    if (paddingStack.length <= node.depth + 1) {
      paddingStack.add(halfInner);
    } else {
      paddingStack[node.depth + 1] = halfInner;
    }
    var x0 = node.x0 + 10 - halfInner;
    var y0 = node.y0 + 35 - halfInner;
    var x1 = node.x1 - 10 + halfInner;
    var y1 = node.y1 - 10 + halfInner;
    if (x1 < x0) x0 = x1 = (x0 + x1) / 2;
    if (y1 < y0) y0 = y1 = (y0 + y1) / 2;
    _squarify(node, x0, y0, x1, y1);
    for (final child in node.children) {
      _position(child, paddingStack, output);
    }
  }

  void _squarify(
    _TreemapBox parent,
    double x0,
    double y0,
    double x1,
    double y1,
  ) {
    if (parent.value <= 0) {
      for (final child in parent.children) {
        child
          ..x0 = x0
          ..x1 = x0
          ..y0 = y0
          ..y1 = y0;
      }
      return;
    }
    const ratio = 1.618033988749895;
    var index = 0;
    var remaining = parent.value;
    while (index < parent.children.length) {
      final dx = x1 - x0;
      final dy = y1 - y0;
      if (dx <= 0 || dy <= 0 || remaining <= 0) {
        for (final child in parent.children.skip(index)) {
          child
            ..x0 = x0
            ..x1 = x0
            ..y0 = y0
            ..y1 = y0;
        }
        return;
      }
      final start = index;
      var sum = parent.children[index++].value;
      while (sum == 0 && index < parent.children.length) {
        sum = parent.children[index++].value;
      }
      var minimum = sum;
      var maximum = sum;
      final alpha = math.max(dy / dx, dx / dy) / (remaining * ratio);
      var beta = sum * sum * alpha;
      var best = math.max(maximum / beta, beta / minimum);
      while (index < parent.children.length) {
        final value = parent.children[index].value;
        sum += value;
        minimum = math.min(minimum, value);
        maximum = math.max(maximum, value);
        beta = sum * sum * alpha;
        final candidate = math.max(maximum / beta, beta / minimum);
        if (candidate > best) {
          sum -= value;
          break;
        }
        best = candidate;
        index++;
      }
      final row = parent.children.sublist(start, index);
      if (dx < dy) {
        final nextY = y0 + dy * sum / remaining;
        _dice(row, x0, y0, x1, nextY, sum);
        y0 = nextY;
      } else {
        final nextX = x0 + dx * sum / remaining;
        _slice(row, x0, y0, nextX, y1, sum);
        x0 = nextX;
      }
      remaining -= sum;
    }
  }

  void _dice(
    List<_TreemapBox> nodes,
    double x0,
    double y0,
    double x1,
    double y1,
    double value,
  ) {
    final scale = value == 0 ? 0 : (x1 - x0) / value;
    for (final node in nodes) {
      node
        ..x0 = x0
        ..x1 = x0 += node.value * scale
        ..y0 = y0
        ..y1 = y1;
    }
  }

  void _slice(
    List<_TreemapBox> nodes,
    double x0,
    double y0,
    double x1,
    double y1,
    double value,
  ) {
    final scale = value == 0 ? 0 : (y1 - y0) / value;
    for (final node in nodes) {
      node
        ..x0 = x0
        ..x1 = x1
        ..y0 = y0
        ..y1 = y0 += node.value * scale;
    }
  }
}

class _TreemapBox {
  _TreemapBox(this.node, this.parent, this.depth, this.order);

  final TreemapNode? node;
  final _TreemapBox? parent;
  final int depth;
  final int order;
  final List<_TreemapBox> children = [];
  double value = 0;
  double x0 = 0;
  double y0 = 0;
  double x1 = 0;
  double y1 = 0;

  Rect get rect => Rect.fromLTRB(x0, y0, x1, y1);
}

class _TreemapColors {
  _TreemapColors(this.data, this.style, this.items) {
    _fillDomain[''] = 0;
    _labelDomain[''] = 0;
    for (final item in items) {
      if (item.depth > 0 && item.children.isNotEmpty) {
        _fillDomain.putIfAbsent(item.node!.label, () => _fillDomain.length);
        _labelDomain.putIfAbsent(item.node!.label, () => _labelDomain.length);
      }
    }
    for (final item in items) {
      if (item.depth > 0 && item.children.isEmpty) {
        _labelDomain.putIfAbsent(item.node!.label, () => _labelDomain.length);
      }
    }
  }

  final TreemapChartData data;
  final MermaidStyle style;
  final List<_TreemapBox> items;
  final Map<String, int> _fillDomain = {};
  final Map<String, int> _labelDomain = {};

  int get leafCount => items.where((item) => item.children.isEmpty).length;

  Color fill(String key) {
    final index = _fillDomain.putIfAbsent(key, () => _fillDomain.length);
    if (index == 0) return Colors.transparent;
    return _themeColor(data.theme.colors, index - 1) ??
        Color.lerp(
          Color(style.defaultNodeStyle.fillColor ?? 0xffe3f2fd),
          Color(style.defaultNodeStyle.strokeColor ?? 0xff1976d2),
          ((index - 1) % 6) / 8,
        )!;
  }

  Color peer(String key) {
    final index = _fillDomain.putIfAbsent(key, () => _fillDomain.length);
    if (index == 0) return Colors.transparent;
    return _themeColor(data.theme.peerColors, index - 1) ??
        Color(style.defaultNodeStyle.strokeColor ?? 0xff1976d2);
  }

  Color label(String key) {
    final index = _labelDomain.putIfAbsent(key, () => _labelDomain.length);
    return _themeColor(data.theme.labelColors, index) ??
        Color(style.defaultNodeStyle.textColor ?? 0xff212121);
  }

  Color? _themeColor(List<String?> values, int index) {
    if (index < 0 || index >= values.length) return null;
    return parseTreemapColor(values[index]);
  }
}

/// Formats a Treemap value with Mermaid's currency special cases and the D3
/// numeric format grammar used by Mermaid 11.16.0.
String formatTreemapValue(double value, String format) {
  try {
    final source = format.isEmpty ? ',' : format;
    if (source == r'$0,0') return '\$${_D3NumberFormat(',').format(value)}';
    if (source.startsWith(r'$') && source.contains(',')) {
      final precision = RegExp(r'\.\d+').firstMatch(source)?.group(0) ?? '';
      return '\$${_D3NumberFormat(',$precision').format(value)}';
    }
    if (source.startsWith(r'$')) {
      return '\$${_D3NumberFormat(source.substring(1)).format(value)}';
    }
    return _D3NumberFormat(source).format(value);
  } on FormatException {
    return _D3NumberFormat(',').format(value);
  }
}

class _D3NumberFormat {
  _D3NumberFormat(String source) {
    final match = RegExp(
      r'^(?:(.)?([<>=^]))?([+\-( ])?([$#])?(0)?(\d+)?(,)?(?:\.(\d+))?(~)?([a-zA-Z%])?$',
    ).firstMatch(source);
    if (match == null) throw FormatException('Invalid D3 format: $source');
    fill = match.group(1) ?? ' ';
    align = match.group(2) ?? '>';
    sign = match.group(3) ?? '-';
    symbol = match.group(4) ?? '';
    zero = match.group(5) != null;
    width = int.tryParse(match.group(6) ?? '');
    comma = match.group(7) != null;
    precision = int.tryParse(match.group(8) ?? '');
    trim = match.group(9) != null;
    type = match.group(10) ?? '';
    if (type == 'n') {
      type = 'g';
      comma = true;
    }
    if (!'bcdDeEfFgGoprsxX%'.contains(type) && type.isNotEmpty) {
      throw FormatException('Unsupported D3 format type: $type');
    }
    if (zero) {
      fill = '0';
      align = '=';
    }
  }

  late String fill;
  late String align;
  late String sign;
  late String symbol;
  late bool zero;
  late int? width;
  late bool comma;
  late int? precision;
  late bool trim;
  late String type;

  String format(double input) {
    if (input.isNaN) return 'NaN';
    if (input.isInfinite) return input.isNegative ? '-Infinity' : 'Infinity';
    final negative = input.isNegative && input != 0;
    final value = input.abs();
    var suffix = '';
    var body = switch (type) {
      'b' => value.round().toRadixString(2),
      'c' => String.fromCharCode(value.round()),
      'd' => value.round().toString(),
      'e' => value.toStringAsExponential(precision ?? 6),
      'E' => value.toStringAsExponential(precision ?? 6).toUpperCase(),
      'f' || 'F' => value.toStringAsFixed(precision ?? 6),
      'g' => value.toStringAsPrecision((precision ?? 6).clamp(1, 21)),
      'G' =>
        value.toStringAsPrecision((precision ?? 6).clamp(1, 21)).toUpperCase(),
      'o' => value.round().toRadixString(8),
      'p' => (value * 100).toStringAsPrecision((precision ?? 6).clamp(1, 21)),
      'r' => value.toStringAsPrecision((precision ?? 6).clamp(1, 21)),
      's' => _si(value, precision ?? 6),
      'x' => value.round().toRadixString(16),
      'X' => value.round().toRadixString(16).toUpperCase(),
      '%' => (value * 100).toStringAsFixed(precision ?? 6),
      _ =>
        value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsPrecision((precision ?? 12).clamp(1, 21)),
    };
    if (type == 'p' || type == '%') suffix = '%';
    if (trim || type.isEmpty || type == 'g' || type == 'G' || type == 'r') {
      body = _trimTreemapZeros(body);
    }
    if (comma && !const {'c', 'b', 'o', 'x', 'X'}.contains(type)) {
      body = _groupTreemapNumber(body);
    }
    var prefix = switch (sign) {
      '+' => negative ? '-' : '+',
      ' ' => negative ? '-' : ' ',
      '(' => negative ? '(' : '',
      _ => negative ? '-' : '',
    };
    if (symbol == r'$') prefix += r'$';
    if (symbol == '#') {
      prefix += switch (type) {
        'b' => '0b',
        'o' => '0o',
        'x' => '0x',
        'X' => '0X',
        _ => '',
      };
    }
    if (sign == '(' && negative) suffix += ')';
    final raw = '$prefix$body$suffix';
    final target = width;
    if (target == null || raw.length >= target) return raw;
    final padding = List.filled(target - raw.length, fill).join();
    return switch (align) {
      '<' => '$raw$padding',
      '^' =>
        '${padding.substring(0, padding.length ~/ 2)}$raw${padding.substring(padding.length ~/ 2)}',
      '=' => '$prefix$padding$body$suffix',
      _ => '$padding$raw',
    };
  }

  String _si(double value, int requestedPrecision) {
    if (value == 0) return '0';
    const symbols = [
      'y',
      'z',
      'a',
      'f',
      'p',
      'n',
      'µ',
      'm',
      '',
      'k',
      'M',
      'G',
      'T',
      'P',
      'E',
      'Z',
      'Y',
    ];
    final exponent = (math.log(value) / math.ln10 / 3).floor().clamp(-8, 8);
    final scaled = value / math.pow(1000, exponent);
    final rendered = scaled.toStringAsPrecision(
      requestedPrecision.clamp(1, 21),
    );
    return '${_trimTreemapZeros(rendered)}${symbols[exponent + 8]}';
  }
}

String _trimTreemapZeros(String value) {
  final exponentIndex = value.indexOf(RegExp('[eE]'));
  final mantissa = exponentIndex < 0
      ? value
      : value.substring(0, exponentIndex);
  final exponent = exponentIndex < 0 ? '' : value.substring(exponentIndex);
  if (!mantissa.contains('.')) return value;
  final trimmed = mantissa
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$trimmed$exponent';
}

String _groupTreemapNumber(String value) {
  final exponentIndex = value.indexOf(RegExp('[eE]'));
  final exponent = exponentIndex < 0 ? '' : value.substring(exponentIndex);
  final number = exponentIndex < 0 ? value : value.substring(0, exponentIndex);
  final parts = number.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final decimal = parts.length > 1 ? '.${parts[1]}' : '';
  return '$grouped$decimal$exponent';
}

/// Parses CSS colors accepted by Mermaid class and theme styles.
Color? parseTreemapColor(String? source) {
  if (source == null) return null;
  final value = source.trim().toLowerCase();
  const named = <String, int>{
    'black': 0xff000000,
    'silver': 0xffc0c0c0,
    'gray': 0xff808080,
    'grey': 0xff808080,
    'white': 0xffffffff,
    'maroon': 0xff800000,
    'red': 0xffff0000,
    'purple': 0xff800080,
    'fuchsia': 0xffff00ff,
    'green': 0xff008000,
    'lime': 0xff00ff00,
    'olive': 0xff808000,
    'yellow': 0xffffff00,
    'navy': 0xff000080,
    'blue': 0xff0000ff,
    'teal': 0xff008080,
    'aqua': 0xff00ffff,
    'orange': 0xffffa500,
    'transparent': 0x00000000,
  };
  if (named[value] case final color?) return Color(color);
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (hex.length == 3 || hex.length == 4) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex)) return null;
    if (hex.length == 6) return Color(0xff000000 | int.parse(hex, radix: 16));
    if (hex.length == 8) {
      final rgba = int.parse(hex, radix: 16);
      return Color(((rgba & 0xff) << 24) | (rgba >> 8));
    }
    return null;
  }
  final rgb = RegExp(
    r'^rgba?\(\s*([\d.]+)%?\s*[, ]\s*([\d.]+)%?\s*[, ]\s*([\d.]+)%?(?:\s*[,/]\s*([\d.]+)%?)?\s*\)$',
  ).firstMatch(value);
  if (rgb != null) {
    final channelsArePercent = rgb
        .group(0)!
        .split(RegExp(r'[, /]'))
        .take(3)
        .join()
        .contains('%');
    int channel(int index) {
      final parsed = double.parse(rgb.group(index)!);
      return (channelsArePercent ? parsed * 2.55 : parsed).round().clamp(
        0,
        255,
      );
    }

    final alphaSource = rgb.group(4);
    final alphaIsPercent =
        alphaSource != null && rgb.group(0)!.contains('$alphaSource%');
    final alpha = alphaSource == null
        ? 255
        : (double.parse(alphaSource) * (alphaIsPercent ? 2.55 : 255))
              .round()
              .clamp(0, 255);
    return Color.fromARGB(alpha, channel(1), channel(2), channel(3));
  }
  final hsl = RegExp(
    r'^hsla?\(\s*([-\d.]+)(?:deg)?\s*[, ]\s*([\d.]+)%\s*[, ]\s*([\d.]+)%(?:\s*[,/]\s*([\d.]+)%?)?\s*\)$',
  ).firstMatch(value);
  if (hsl == null) return null;
  final alphaSource = hsl.group(4);
  final alphaIsPercent =
      alphaSource != null && hsl.group(0)!.contains('$alphaSource%');
  final alpha = alphaSource == null
      ? 1.0
      : (double.parse(alphaSource) / (alphaIsPercent ? 100 : 1))
            .clamp(0, 1)
            .toDouble();
  return HSLColor.fromAHSL(
    alpha,
    double.parse(hsl.group(1)!) % 360,
    (double.parse(hsl.group(2)!) / 100).clamp(0, 1),
    (double.parse(hsl.group(3)!) / 100).clamp(0, 1),
  ).toColor();
}
