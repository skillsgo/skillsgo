/*
 * [INPUT]: Depends on Flutter Material primitives and SkillsGo brand colors.
 * [OUTPUT]: Provides reusable native desktop buttons including the primary capsule action, cards, dialogs, fields, alerts, progress, toggles, dividers, and tooltips.
 * [POS]: Serves as the Material-only component layer between product screens and Flutter widgets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, height),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: labelStyle ?? const TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }
}

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
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.error,
          ),
          foregroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.onError,
          ),
        ),
        child: content,
      ),
    };
    return SizedBox(width: width, height: height, child: button);
  }
}

class SkillsCard extends StatelessWidget {
  const SkillsCard({
    super.key,
    this.title,
    this.description,
    this.child,
    this.footer,
    this.leading,
    this.trailing,
    this.width,
    this.padding,
    this.backgroundColor,
  });

  final Widget? title;
  final Widget? description;
  final Widget? child;
  final Widget? footer;
  final Widget? leading;
  final Widget? trailing;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    DefaultTextStyle.merge(
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      child: title!,
                    ),
                  if (description != null) ...[
                    if (title != null) const SizedBox(height: 5),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      child: description!,
                    ),
                  ],
                  ?child,
                  if (footer != null) ...[const SizedBox(height: 14), footer!],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    ),
  );
}

class SkillsSeparator extends StatelessWidget {
  const SkillsSeparator.horizontal({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => Divider(height: 1, color: color);
}

class SkillsProgress extends StatelessWidget {
  const SkillsProgress({
    super.key,
    this.value,
    this.minHeight,
    this.semanticsLabel,
  });
  final double? value;
  final double? minHeight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: minHeight,
    semanticsLabel: semanticsLabel,
    borderRadius: BorderRadius.circular(999),
  );
}

class SkillsCheckbox extends StatelessWidget {
  const SkillsCheckbox({
    super.key,
    required this.value,
    this.enabled = true,
    this.onChanged,
    this.label,
    this.sublabel,
  });
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget? label;
  final Widget? sublabel;

  @override
  Widget build(BuildContext context) {
    final checkbox = Checkbox(
      value: value,
      onChanged: enabled && onChanged != null
          ? (next) => onChanged!(next ?? false)
          : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (label == null && sublabel == null) {
      return SizedBox.square(dimension: 24, child: Center(child: checkbox));
    }
    return InkWell(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          checkbox,
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?label,
                if (sublabel != null) ...[
                  const SizedBox(height: 3),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: sublabel!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SkillsAlertVariant { normal, destructive }

class SkillsAlert extends StatelessWidget {
  const SkillsAlert({super.key, this.icon, this.title, this.description})
    : _variant = _SkillsAlertVariant.normal;

  const SkillsAlert.destructive({
    super.key,
    this.icon,
    this.title,
    this.description,
  }) : _variant = _SkillsAlertVariant.destructive;

  final Widget? icon;
  final Widget? title;
  final Widget? description;
  final _SkillsAlertVariant _variant;

  @override
  Widget build(BuildContext context) {
    final destructive = _variant == _SkillsAlertVariant.destructive;
    final scheme = Theme.of(context).colorScheme;
    final accent = destructive ? scheme.error : scheme.primary;
    return Material(
      color: accent.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: accent),
                child: icon!,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                      child: title!,
                    ),
                  if (description != null) ...[
                    if (title != null) const SizedBox(height: 4),
                    description!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkillsInput extends StatelessWidget {
  const SkillsInput({
    super.key,
    this.initialValue,
    this.placeholder,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.placeholderStyle,
    this.enabled = true,
  });
  final String? initialValue;
  final Widget? placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final TextStyle? placeholderStyle;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: controller == null ? initialValue : null,
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    enabled: enabled,
    decoration: InputDecoration(
      hintText: placeholder is Text ? (placeholder as Text).data : null,
      hintStyle: placeholderStyle,
      prefixIcon: leading,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class SkillsSwitch extends StatelessWidget {
  const SkillsSwitch({
    super.key,
    required this.value,
    this.enabled = true,
    this.onChanged,
    this.label,
    this.sublabel,
  });
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget? label;
  final Widget? sublabel;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
    borderRadius: BorderRadius.circular(10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?label,
              if (sublabel != null) ...[
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: sublabel!,
                ),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: enabled ? onChanged : null),
      ],
    ),
  );
}

class SkillsTooltip extends StatelessWidget {
  const SkillsTooltip({super.key, required this.builder, required this.child});
  final WidgetBuilder builder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = builder(context);
    return Tooltip(
      message: value is Text ? value.data ?? '' : '',
      child: child,
    );
  }
}

Future<T?> showSkillsDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: builder,
);

class SkillsDialog extends StatelessWidget {
  const SkillsDialog({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.constraints,
  });
  final Widget? title;
  final Widget? description;
  final Widget? child;
  final List<Widget> actions;
  final Widget? closeIcon;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: constraints ?? const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          child: title!,
                        ),
                      if (description != null) ...[
                        const SizedBox(height: 5),
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          child: description!,
                        ),
                      ],
                    ],
                  ),
                ),
                ?closeIcon,
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 18),
              Flexible(child: child!),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 10, runSpacing: 10, children: actions),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
