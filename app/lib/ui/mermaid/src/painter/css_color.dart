/*
 * [INPUT]: Depends on Flutter Color and HSLColor primitives plus Mermaid CSS style strings.
 * [OUTPUT]: Provides shared native parsing for CSS named, hexadecimal, RGB(A), and HSL(A) colors.
 * [POS]: Serves as the painter-level CSS color compatibility utility for native Mermaid renderers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

Color? parseMermaidCssColor(String? source) {
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
    r'^rgba?\(\s*([\d.]+)(%)?\s*[, ]\s*([\d.]+)(%)?\s*[, ]\s*([\d.]+)(%)?(?:\s*[,/]\s*([\d.]+)(%)?)?\s*\)$',
  ).firstMatch(value);
  if (rgb != null) {
    int channel(int valueGroup, int percentGroup) {
      final parsed = double.parse(rgb.group(valueGroup)!);
      return (rgb.group(percentGroup) == null ? parsed : parsed * 2.55)
          .round()
          .clamp(0, 255);
    }

    final alphaValue = rgb.group(7);
    final alpha = alphaValue == null
        ? 255
        : (double.parse(alphaValue) * (rgb.group(8) == null ? 255 : 2.55))
              .round()
              .clamp(0, 255);
    return Color.fromARGB(alpha, channel(1, 2), channel(3, 4), channel(5, 6));
  }
  final hsl = RegExp(
    r'^hsla?\(\s*([-\d.]+)(?:deg)?\s*[, ]\s*([\d.]+)%\s*[, ]\s*([\d.]+)%(?:\s*[,/]\s*([\d.]+)(%)?)?\s*\)$',
  ).firstMatch(value);
  if (hsl == null) return null;
  final alphaValue = hsl.group(4);
  final alpha = alphaValue == null
      ? 1.0
      : (double.parse(alphaValue) / (hsl.group(5) == null ? 1 : 100))
            .clamp(0, 1)
            .toDouble();
  var hue = double.parse(hsl.group(1)!) % 360;
  if (hue < 0) hue += 360;
  return HSLColor.fromAHSL(
    alpha,
    hue,
    (double.parse(hsl.group(2)!) / 100).clamp(0, 1),
    (double.parse(hsl.group(3)!) / 100).clamp(0, 1),
  ).toColor();
}
