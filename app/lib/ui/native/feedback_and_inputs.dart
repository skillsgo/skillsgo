/*
 * [INPUT]: Depends on Flutter Material alerts, text fields, switches, tooltips, dialogs, HugeIcons, and SkillsGo semantic tokens.
 * [OUTPUT]: Provides alert, input, switch, tooltip, and dialog primitives with localized semantics and consistent states.
 * [POS]: Serves as the feedback, form, and overlay segment of the native component library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../native_components.dart';

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
    final foreground = destructive
        ? context.skillsComponents.statusDanger
        : context.skillsComponents.statusAccent;
    final container = destructive
        ? context.skillsComponents.statusDangerContainer
        : context.skillsComponents.statusAccentContainer;
    return Material(
      color: container,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: foreground),
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
                      style: context.skillsTypography.label.copyWith(
                        color: foreground,
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
      filled: true,
      fillColor: context.skillsComponents.controlRest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.skillsComponents.controlBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: context.skillsComponents.focusRing,
          width: context.skillsComponents.focusRingWidth,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.skillsComponents.controlDisabled),
      ),
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
                  style: context.skillsTypography.bodySecondary,
                  child: sublabel!,
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeTrackColor: context.skillsComponents.primaryRest,
          inactiveTrackColor: context.skillsComponents.controlRest,
          trackOutlineColor: WidgetStatePropertyAll(
            context.skillsComponents.controlBorder,
          ),
        ),
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
  barrierColor: context.skillsComponents.overlayBackdrop,
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
    backgroundColor: context.skillsComponents.overlay,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.skillsComponents.overlayBorder),
    ),
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
                          style: context.skillsTypography.pageTitle,
                          child: title!,
                        ),
                      if (description != null) ...[
                        const SizedBox(height: 5),
                        DefaultTextStyle.merge(
                          style: context.skillsTypography.bodySecondary,
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
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(spacing: 10, runSpacing: 10, children: actions),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
