/*
 * [INPUT]: Depends on Flutter Material cards, separators, progress, checkboxes, SkillsGo tokens, and semantic state.
 * [OUTPUT]: Provides card, separator, progress, and checkbox primitives.
 * [POS]: Serves as the structural and selection segment of the native component library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../native_components.dart';

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
      color: backgroundColor ?? context.skillsComponents.cardRest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.skillsComponents.cardBorder),
      ),
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
                      style: context.skillsTypography.label,
                      child: title!,
                    ),
                  if (description != null) ...[
                    if (title != null) const SizedBox(height: 5),
                    DefaultTextStyle.merge(
                      style: context.skillsTypography.bodySecondary,
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
    this.indeterminate = false,
    this.enabled = true,
    this.onChanged,
    this.label,
    this.sublabel,
  });
  final bool value;
  final bool indeterminate;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget? label;
  final Widget? sublabel;

  @override
  Widget build(BuildContext context) {
    final checkbox = Checkbox(
      value: indeterminate ? null : value,
      tristate: indeterminate,
      onChanged: enabled && onChanged != null
          ? (_) => onChanged!(indeterminate ? true : !value)
          : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      fillColor: WidgetStateProperty.resolveWith((states) {
        final components = context.skillsComponents;
        if (states.contains(WidgetState.disabled)) {
          return components.controlDisabled;
        }
        if (states.contains(WidgetState.selected)) {
          return components.primaryRest;
        }
        return components.controlRest;
      }),
      checkColor: context.skillsComponents.primaryForeground,
      side: BorderSide(color: context.skillsComponents.controlBorder),
    );
    if (label == null && sublabel == null) {
      return SizedBox.square(dimension: 24, child: Center(child: checkbox));
    }
    return InkWell(
      onTap: enabled && onChanged != null
          ? () => onChanged!(indeterminate ? true : !value)
          : null,
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
                    style: context.skillsTypography.bodySecondary,
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
