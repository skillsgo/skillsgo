/*
 * [INPUT]: Depends on the Bloom picker library, widget configuration, animation controller, overlay lifecycle, text editing, and color parsing.
 * [OUTPUT]: Provides the picker state owner, bloom animation setup, overlay lifecycle, hex editing, selection state, and root build delegation.
 * [POS]: Serves as the state-owning core of the Bloom color picker; derived from Portal Labs under the repository MIT notice.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../bloom_color_picker.dart';

class _BloomColorPickerState extends State<BloomColorPicker>
    with SingleTickerProviderStateMixin {
  void updateState(VoidCallback change) => setState(change);
  late Color _currentColor;
  BloomColorPickerState _state = BloomColorPickerState.closed;

  // Animation controller and curve for the bloom and scale effects.
  late AnimationController _controller;
  late Animation<double> _bloomProgress;
  late Animation<double> _contentOpacity;
  late Animation<double> _pillOpacity;

  // Layer link to position overlay relative to target
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Gesture state variables
  bool _isPressed = false;
  bool _isEditingText = false;
  bool _isDraggingSlider = false;
  String? _hoveredPresetName;
  Offset _hoveredPresetOffset = Offset.zero;

  double _lightness = 0.5; // 0.0 to 1.0

  late TextEditingController _hexController;
  late FocusNode _hexFocusNode;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
    _hexFocusNode = FocusNode();
    _hexFocusNode.addListener(_handleFocusChange);

    _controller =
        AnimationController(
          vsync: this,
          duration: widget.style.animationDuration,
          reverseDuration: widget.style.animationDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            _overlayEntry?.remove();
            _overlayEntry = null;
            setState(() {});
          } else if (status == AnimationStatus.completed) {
            setState(() {});
          }
        });

    _initAnimations();
  }

  void _initAnimations() {
    // Bloom progress: normalized 0.0 to 1.0 progress for concentric growth and peeling.
    // Employs a custom BloomOvershootCurve for an organic, liquid-burst expansion.
    _bloomProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: BloomOvershootCurve()),
        reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeInCubic),
      ),
    );

    // Stage 2: Content (dots + slider + center) fades in after bloom starts expanding.
    // Starts early at 0.10 and ends at 0.85 to open in unison with the bloom background.
    // On reverse (close), the content fades out in lock-step with the bloom between 1.0 and 0.15.
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.85, curve: Curves.easeOut),
        reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeInCubic),
      ),
    );

    // The hex pill fades out quickly during open, and only fades back in at the very end
    // of close (below t = 0.15) when the morphing ring has completely closed to prevent overlap.
    _pillOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
        reverseCurve: const Interval(0.85, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(BloomColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style.animationCurve != oldWidget.style.animationCurve ||
        widget.style.bloomRadius != oldWidget.style.bloomRadius ||
        widget.style.closedRadius != oldWidget.style.closedRadius) {
      _initAnimations();
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _hexFocusNode.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.dispose();
    super.dispose();
  }

  void _toggleState() {
    if (widget.style.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _state = switch (_state) {
        BloomColorPickerState.closed => BloomColorPickerState.open,
        BloomColorPickerState.open => BloomColorPickerState.closed,
      };
    });

    if (_state == BloomColorPickerState.open) {
      // Reset to the very start of the animation, then insert the overlay.
      // We must NOT call forward() yet — the CompositedTransformFollower needs
      // at least one frame to attach to the LayerLink and compute its position.
      // Calling forward() immediately causes the follower to start at (0,0)
      // then jump to the correct position mid-animation (the displacement bug).
      _controller.value = 0.0;
      _showOverlay();
      // Wait one frame for the overlay to lay out and anchor, then animate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _state == BloomColorPickerState.open) {
          _controller.forward();
        }
      });
    } else {
      _controller.reverse();
    }
  }

  void _setHoveredPreset(String? name, [Offset offset = Offset.zero]) {
    if (_hoveredPresetName == name && _hoveredPresetOffset == offset) return;
    _hoveredPresetName = name;
    _hoveredPresetOffset = offset;
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final OverlayState overlayState = Overlay.of(context);
    final double bloomSize = widget.style.bloomRadius * 2;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Tap outside detector — covers the full screen.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleState,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Follower stays ANCHORED to the circle's center at all times.
            // The bloom expands radially from that point.
            // Near screen edges the bloom will naturally clip — this is the
            // correct behavior for a radial bloom; shifting breaks the effect.
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.center,
              followerAnchor: Alignment.center,
              child: SizedBox(
                width: bloomSize * 2,
                height: bloomSize * 2,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Expanded Background (Bloom)
                    AnimatedBuilder(
                      animation: _bloomProgress,
                      builder: (context, child) {
                        final double progress = _bloomProgress.value;
                        final double progressClamped = progress.clamp(0.0, 1.0);
                        final double blurSigma =
                            progressClamped *
                            12.0; // Tighter, cleaner blur containment
                        final double bgOpacity =
                            progressClamped *
                            0.92; // 92% opaque base card to prevent bleed-through
                        final double tintOpacity =
                            progressClamped *
                            0.06; // Subtle color tint matching the selected color
                        final double scale = lerpDouble(0.3, 1.0, progress)!;

                        // Align background blur size to the outer ring size (radius 98.0)
                        // instead of the giant bloomSize (240.0). This makes the glow
                        // fade out perfectly right at the lightness slider.
                        final double targetOuterRadius =
                            widget.style.bloomRadius -
                            (widget.style.closedRadius - 2.0);
                        final double targetBgSize = targetOuterRadius * 2;

                        final surfaceColor = Theme.of(
                          context,
                        ).colorScheme.surface;

                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: targetBgSize,
                            height: targetBgSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: surfaceColor.withValues(alpha: bgOpacity),
                              boxShadow: [
                                BoxShadow(
                                  color: _currentColor.withValues(
                                    alpha: progressClamped * 0.15,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Inner color tint layer
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentColor.withValues(
                                      alpha: tintOpacity,
                                    ),
                                  ),
                                ),
                                if (blurSigma > 0.1)
                                  ClipOval(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: blurSigma,
                                        sigmaY: blurSigma,
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Morphing Ring — the core opening animation.
                    //
                    // Starts as a fully FILLED circle matching the closed button's visual properties
                    // (color, white border, and black drop shadow). As the animation progresses:
                    //   • The outer diameter grows from closedRadius → targetOuterRadius
                    //   • The inner hole peels open concentrically from the center (0.0 radius)
                    //     using Curves.easeInCubic, ensuring it starts as a filled disc and the fill
                    //     "peels" back to reveal a thin outer ring at progress=1.0.
                    //   • The white border and initial black shadow fade out within the first 50%
                    //     of the transition, while a colored glow fades out as the ring opens.
                    AnimatedBuilder(
                      animation: _bloomProgress,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(bloomSize, bloomSize),
                          painter: MorphingRingPainter(
                            progress: _bloomProgress.value,
                            color: _currentColor,
                            closedRadius: widget.style.closedRadius,
                            targetOuterRadius:
                                widget.style.bloomRadius -
                                (widget.style.closedRadius - 2.0),
                            endBorderWidth:
                                12.0, // Wider ring thickness for a cleaner solid presence
                          ),
                        );
                      },
                    ),

                    // Open State Content (Color Wheel + Slider).
                    FadeTransition(
                      opacity: _contentOpacity,
                      child: Builder(
                        builder: (context) {
                          final double sliderRadius =
                              widget.style.bloomRadius + 12.0;
                          final double sliderMaxHorizontal =
                              sliderRadius +
                              (widget.style.sliderWidth / 2) +
                              6.0;
                          final double w = sliderMaxHorizontal * 2;
                          final double h = bloomSize + 24.0;
                          return _buildOpenContent(w, h, bloomSize);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _handlePressDown(TapDownDetails details) {
    if (_state == BloomColorPickerState.closed) {
      setState(() => _isPressed = true);
    }
  }

  void _handlePressUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _toggleState();
    }
  }

  void _handlePressCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
  }

  Color? _parseHex(String text) {
    final cleanText = text.replaceAll('#', '').trim();
    if (cleanText.length == 6) {
      final intVal = int.tryParse(cleanText, radix: 16);
      if (intVal != null) {
        return Color(0xFF000000 | intVal);
      }
    } else if (cleanText.length == 3) {
      final r = cleanText[0];
      final g = cleanText[1];
      final b = cleanText[2];
      final intVal = int.tryParse('$r$r$g$g$b$b', radix: 16);
      if (intVal != null) {
        return Color(0xFF000000 | intVal);
      }
    }
    return null;
  }

  void _handleFocusChange() {
    setState(() {
      _isEditingText = _hexFocusNode.hasFocus;
    });
    if (!_hexFocusNode.hasFocus) {
      final parsed = _parseHex(_hexController.text);
      if (parsed == null) {
        setState(() {
          _hexController.text = _colorToHex(_currentColor);
        });
      } else {
        setState(() {
          _currentColor = parsed;
          _hexController.text = _colorToHex(parsed);
        });
        widget.onColorChanged(parsed);
      }
    }
  }

  void _handleHexChanged(String value) {
    final parsed = _parseHex(value);
    if (parsed != null) {
      setState(() {
        _currentColor = parsed;
      });
      widget.onColorChanged(parsed);
    }
  }

  void _updateHexController() {
    if (!_hexFocusNode.hasFocus) {
      _hexController.text = _colorToHex(_currentColor);
    }
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _selectColor(Color color, {bool shouldClose = true}) {
    if (widget.style.hapticFeedback) {
      HapticFeedback.selectionClick();
    }

    // Extract lightness from current color and apply to new color base
    final hsl = HSLColor.fromColor(color);
    _lightness = hsl.lightness;

    setState(() {
      _currentColor = color;
      _updateHexController();
    });
    widget.onColorChanged(color);
    if (shouldClose) {
      _toggleState();
    }
  }

  @override
  Widget build(BuildContext context) => _buildPicker(context);
}
