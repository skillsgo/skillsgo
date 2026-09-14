/*
 * [INPUT]: Depends on Bloom picker state, animated values, overlay target geometry, pointer/focus state, and Material surfaces.
 * [OUTPUT]: Provides the compact picker surface, pressed/hover treatment, morphing ring, hex pill, and open-content placement.
 * [POS]: Serves as the compact and expanding surface segment of the Bloom color picker; derived from Portal Labs under the repository MIT notice.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../bloom_color_picker.dart';

extension _BloomPickerSurface on _BloomColorPickerState {
  Widget _buildPicker(BuildContext context) {
    final double closedSize = widget.style.closedRadius * 2;

    final circleWidget = SizedBox(
      width: closedSize,
      height: closedSize,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: AnimatedScale(
          // Emil: press feedback should be subtle (0.95–0.97), not dramatic.
          scale: _isPressed && _state == BloomColorPickerState.closed
              ? 0.95
              : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTapDown: _handlePressDown,
            onTapUp: _handlePressUp,
            onTapCancel: _handlePressCancel,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentColor,
                border: Border.all(
                  color: Colors.white,
                  width: widget.style.closedBorderWidth,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final pillWidget = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // CRITICAL: Never collapse the pill's layout space during animation.
        // Shrinking the pill width shifts the Row, which moves the circle,
        // which moves the LayerLink anchor — causing the overlay to displace.
        // Visibility(maintainSize) fades the pill visually while keeping its
        // layout footprint fixed so the circle never changes position.
        if (!widget.style.showHexPill) {
          return const SizedBox.shrink();
        }
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 157.0,
            end: _isEditingText ? 200.0 : 157.0,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, editingWidth, innerChild) {
            return SizedBox(
              width: editingWidth,
              height: closedSize,
              child: Visibility(
                visible: _pillOpacity.value > 0.0,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: FadeTransition(
                  opacity: _pillOpacity,
                  child: OverflowBox(
                    minWidth: 0.0,
                    maxWidth: 250.0,
                    minHeight: 0.0,
                    maxHeight: closedSize,
                    alignment:
                        widget.style.alignment ==
                            BloomColorPickerAlignment.circleRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: innerChild,
                  ),
                ),
              ),
            );
          },
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.style.alignment == BloomColorPickerAlignment.circleLeft)
            const SizedBox(width: 16),
          Container(
            height: closedSize,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: widget.style.pillBackgroundColor,
              borderRadius: BorderRadius.circular(closedSize / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: _isEditingText ? 120 : 85,
                  child: TextField(
                    controller: _hexController,
                    focusNode: _hexFocusNode,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(7),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[#a-fA-F0-9]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style:
                        widget.style.textStyle ??
                        TextStyle(
                          color: widget.style.pillTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                    onChanged: _handleHexChanged,
                    onSubmitted: (_) => _hexFocusNode.unfocus(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, _) {
                            final double blur = (1.0 - animation.value) * 4.0;
                            if (blur <= 0.05) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            }
                            return FadeTransition(
                              opacity: animation,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blur,
                                  sigmaY: blur,
                                ),
                                child: child,
                              ),
                            );
                          },
                        );
                      },
                  child: _isEditingText
                      ? GestureDetector(
                          key: const ValueKey('check'),
                          onTap: () => _hexFocusNode.unfocus(),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1A1A1A),
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              size: 12,
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('edit'),
                          onTap: () => _hexFocusNode.requestFocus(),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedEdit02,
                            size: 16,
                            strokeWidth: widget.style.iconStrokeWidth,
                            color: widget.style.iconColor,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (widget.style.alignment == BloomColorPickerAlignment.circleRight)
            const SizedBox(width: 16),
        ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.style.alignment == BloomColorPickerAlignment.circleRight
          ? [pillWidget, circleWidget]
          : [circleWidget, pillWidget],
    );
  }
}
