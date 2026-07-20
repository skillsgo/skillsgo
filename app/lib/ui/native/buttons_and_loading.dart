/*
 * [INPUT]: Depends on Flutter Material buttons, progress, shape/state properties, SkillsGo component tokens, and reduced-motion semantics.
 * [OUTPUT]: Provides skeleton boxes plus primary, outline, ghost, and destructive button primitives with consistent size and busy behavior.
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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final double horizontalPadding;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final textGeometry = labelStyle ?? context.skillsTypography.label;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return components.controlDisabled;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return components.primaryHover;
          }
          return components.primaryRest;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? components.controlForegroundDisabled
              : components.primaryForeground,
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          _textGeometryOnly(
            textGeometry.copyWith(
              fontWeight: labelStyle?.fontWeight ?? FontWeight.w600,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
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
