/*
 * [INPUT]: Depends on Flutter Material animation, HugeIcons, overlay, pointer, text-editing, and rendering primitives plus the local Bloom style model.
 * [OUTPUT]: Provides the vendored Bloom color-picker library and its public preset, state, style, and picker interfaces.
 * [POS]: Serves as the product-specific theme picker in the App UI module; derived from Portal Labs under the MIT license recorded in THIRD_PARTY_NOTICES.md.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'models/bloom_color_picker_style.dart';

export 'models/bloom_color_picker_style.dart';

part 'bloom_picker/picker_state.dart';
part 'bloom_picker/picker_surface.dart';
part 'bloom_picker/open_content.dart';
part 'bloom_picker/lightness_slider.dart';
part 'bloom_picker/painters_and_curves.dart';

@immutable
class BloomColorPreset {
  const BloomColorPreset({required this.name, required this.color});

  final String name;
  final Color color;
}

/// The internal states of the Bloom Color Picker.
enum BloomColorPickerState {
  /// The compact state showing only the selected color and hex pill.
  closed,

  /// The fully open state showing the color wheel and lightness slider.
  open,
}

/// A premium color picker with a "Bloom" expansion effect and physics-based interactions.
class BloomColorPicker extends StatefulWidget {
  /// Creates a new `BloomColorPicker`.
  const BloomColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    required this.presets,
    this.style = const BloomColorPickerStyle(),
  });

  /// The initially selected color.
  final Color initialColor;

  /// Callback fired when the selected color changes.
  final ValueChanged<Color> onColorChanged;

  /// The visual styling and layout properties.
  final BloomColorPickerStyle style;

  /// The 18 named colors rendered directly across the outer and inner rings.
  final List<BloomColorPreset> presets;

  @override
  State<BloomColorPicker> createState() => _BloomColorPickerState();
}
