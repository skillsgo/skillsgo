/*
 * [INPUT]: Depends on Flutter Material buttons, HugeIcons, progress, shape/state properties, and SkillsGo component tokens.
 * [OUTPUT]: Provides skeleton boxes, a compact pending-activity indicator that spins while statistics are being computed and settles into a determinate ring once work is measurable, plus fixed-height capsule buttons with control-specific label geometry, optional custom labels, trailing content, contextual semantic colors, and disabled colors, and outline, ghost, and destructive button primitives with consistent size and busy behavior.
 * [POS]: Serves as the action and cold-loading segment of the native component library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../native_components.dart';

class SkillsSkeletonBox extends StatelessWidget {
  const SkillsSkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.skillsComponents.cardHover,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(width: width, height: height),
    ),
  );
}

enum SkillsButtonSize { sm, regular }

enum _SkillsButtonVariant { primary, outline, ghost, destructive }

class PrimaryCapsuleButton extends StatelessWidget {
  const PrimaryCapsuleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.height = 44,
    this.horizontalPadding = 20,
    this.labelStyle,
    this.labelWidget,
    this.trailingIcon,
    this.trailingWidget,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.backgroundColor,
    this.foregroundColor,
    this.hoverBackgroundColor,
  }) : _compact = false;

  const PrimaryCapsuleButton.compact({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.labelWidget,
    this.trailingIcon,
    this.trailingWidget,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.backgroundColor,
    this.foregroundColor,
    this.hoverBackgroundColor,
  }) : height = 28,
       horizontalPadding = 9,
       labelStyle = null,
       _compact = true;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final double horizontalPadding;
  final TextStyle? labelStyle;
  final Widget? labelWidget;
  final List<List<dynamic>>? trailingIcon;
  final Widget? trailingWidget;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? hoverBackgroundColor;
  final bool _compact;

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final textGeometry =
        labelStyle ??
        (_compact
            ? context.skillsTypography.compactControlLabel
            : context.skillsTypography.label);
    final resolvedTextGeometry = _textGeometryOnly(
      textGeometry.copyWith(
        fontWeight: labelStyle?.fontWeight ?? textGeometry.fontWeight,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          _compact ? Size.zero : Size(0, height),
        ),
        alignment: Alignment.center,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledBackgroundColor ?? components.controlDisabled;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return hoverBackgroundColor ?? components.primaryHover;
          }
          return backgroundColor ?? components.primaryRest;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledForegroundColor ?? components.controlForegroundDisabled
              : foregroundColor ?? components.primaryForeground,
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(resolvedTextGeometry),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                labelWidget ??
                    Text(
                      label,
                      style: resolvedTextGeometry,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                    ),
                if (trailingWidget != null || trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  trailingWidget ??
                      HugeIcon(icon: trailingIcon!, size: 17, strokeWidth: 1.8),
                ],
              ],
            ),
    );
    return _compact ? SizedBox(height: height, child: button) : button;
  }
}

TextStyle _textGeometryOnly(TextStyle style) => TextStyle(
  inherit: style.inherit,
  fontFamily: style.fontFamily,
  fontFamilyFallback: style.fontFamilyFallback,
  fontSize: style.fontSize,
  fontWeight: style.fontWeight,
  fontStyle: style.fontStyle,
  letterSpacing: style.letterSpacing,
  wordSpacing: style.wordSpacing,
  textBaseline: style.textBaseline,
  height: style.height,
  leadingDistribution: style.leadingDistribution,
  locale: style.locale,
  fontFeatures: style.fontFeatures,
  fontVariations: style.fontVariations,
);

class SkillsButton extends StatelessWidget {
  const SkillsButton({
    super.key,
    this.child,
    this.onPressed,
    this.enabled = true,
    this.width,
    this.height,
    this.padding,
    this.size = SkillsButtonSize.regular,
    this.mainAxisAlignment,
    this.backgroundColor,
    this.leading,
  }) : _variant = _SkillsButtonVariant.primary;

  const SkillsButton.outline({
    super.key,
    this.child,
    this.onPressed,
    this.enabled = true,
    this.width,
    this.height,
    this.padding,
    this.size = SkillsButtonSize.regular,
    this.mainAxisAlignment,
    this.backgroundColor,
    this.leading,
  }) : _variant = _SkillsButtonVariant.outline;

  const SkillsButton.ghost({
    super.key,
    this.child,
    this.onPressed,
    this.enabled = true,
    this.width,
    this.height,
    this.padding,
    this.size = SkillsButtonSize.regular,
    this.mainAxisAlignment,
    this.backgroundColor,
    this.leading,
  }) : _variant = _SkillsButtonVariant.ghost;

  const SkillsButton.destructive({
    super.key,
    this.child,
    this.onPressed,
    this.enabled = true,
    this.width,
    this.height,
    this.padding,
    this.size = SkillsButtonSize.regular,
    this.mainAxisAlignment,
    this.backgroundColor,
    this.leading,
  }) : _variant = _SkillsButtonVariant.destructive;

  final Widget? child;
  final VoidCallback? onPressed;
  final bool enabled;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final SkillsButtonSize size;
  final MainAxisAlignment? mainAxisAlignment;
  final Color? backgroundColor;
  final Widget? leading;
  final _SkillsButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final callback = enabled ? onPressed : null;
    final compact = size == SkillsButtonSize.sm;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(0, height ?? (compact ? 30 : 36)),
      ),
      padding: WidgetStatePropertyAll(
        padding ?? EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return components.controlForegroundDisabled;
        }
        return _variant == _SkillsButtonVariant.primary
            ? components.primaryForeground
            : components.controlForeground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return components.controlDisabled;
        }
        if (backgroundColor != null) return backgroundColor;
        if (_variant == _SkillsButtonVariant.primary) {
          return states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)
              ? components.primaryHover
              : components.primaryRest;
        }
        if (_variant == _SkillsButtonVariant.outline ||
            _variant == _SkillsButtonVariant.ghost) {
          if (states.contains(WidgetState.pressed)) {
            return components.controlActive;
          }
          if (states.contains(WidgetState.hovered)) {
            return components.controlHover;
          }
          return Colors.transparent;
        }
        return null;
      }),
      side: _variant == _SkillsButtonVariant.outline
          ? WidgetStatePropertyAll(BorderSide(color: components.controlBorder))
          : null,
    );
    final rawContent = child ?? const SizedBox.shrink();
    final content = leading == null
        ? rawContent
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.center,
            children: [leading!, const SizedBox(width: 7), rawContent],
          );
    final themedStyle = backgroundColor == null
        ? style
        : style.copyWith(
            backgroundColor: WidgetStatePropertyAll(backgroundColor),
          );
    final button = switch (_variant) {
      _SkillsButtonVariant.primary => FilledButton(
        onPressed: callback,
        style: themedStyle,
        child: content,
      ),
      _SkillsButtonVariant.outline => OutlinedButton(
        onPressed: callback,
        style: themedStyle,
        child: content,
      ),
      _SkillsButtonVariant.ghost => TextButton(
        onPressed: callback,
        style: themedStyle,
        child: content,
      ),
      _SkillsButtonVariant.destructive => FilledButton(
        onPressed: callback,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? components.controlDisabled
                : components.statusDangerSolid,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? components.controlForegroundDisabled
                : components.statusDangerForeground,
          ),
        ),
        child: content,
      ),
    };
    return SizedBox(width: width, height: height, child: button);
  }
}

/// A compact activity indicator for statistics that are still being computed.
///
/// A known [fraction] renders a determinate ring so measurable archive work
/// reads as bounded progress; otherwise one HugeIcons arc rotates until the
/// observation completes, and holds still when the platform disables
/// animations. The caller owns the adjacent label, so the indicator keeps
/// itself out of the accessibility tree.
class SkillsPendingSpinner extends StatelessWidget {
  const SkillsPendingSpinner({
    super.key,
    this.size = 12,
    this.color,
    this.fraction,
  });

  final double size;
  final Color? color;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final fraction = this.fraction;
    if (fraction != null) {
      return ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CircularProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            strokeWidth: size <= 12 ? 1.6 : 2,
            color: resolvedColor,
            backgroundColor: resolvedColor.withValues(alpha: 0.14),
          ),
        ),
      );
    }
    return _PendingSpinnerGlyph(size: size, color: resolvedColor);
  }
}

class _PendingSpinnerGlyph extends StatefulWidget {
  const _PendingSpinnerGlyph({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_PendingSpinnerGlyph> createState() => _PendingSpinnerGlyphState();
}

class _PendingSpinnerGlyphState extends State<_PendingSpinnerGlyph>
    with SingleTickerProviderStateMixin {
  static const _turn = Duration(milliseconds: 900);

  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: _turn,
  );

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rotate =
        debugPendingIndicatorMotionEnabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (rotate && !_rotation.isAnimating) {
      _rotation.repeat();
    } else if (!rotate && _rotation.isAnimating) {
      _rotation.stop();
      _rotation.value = 0;
    }
    return ExcludeSemantics(
      child: RotationTransition(
        turns: _rotation,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedLoading03,
          size: widget.size,
          strokeWidth: 1.8,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Freezes the pending-indicator rotation so rendered suites can settle.
///
/// Rendered tests keep this `false`; production keeps `true` and the platform
/// reduced-motion setting remains the user-facing control.
@visibleForTesting
bool debugPendingIndicatorMotionEnabled = true;
