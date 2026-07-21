/*
 * [INPUT]: Depends on the shared nested-navigation library, SkillsRailItem values and optional exact counts, selection state, compact density, and Flutter Material interaction primitives.
 * [OUTPUT]: Provides the private animated, accessible rail button with an optional inline count capsule used by SkillsSideRail.
 * [POS]: Serves as the per-destination row presentation segment of nested navigation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../nested_navigation.dart';

class _RailButton<T> extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
  });

  final SkillsRailItem<T> item;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? context.skillsComponents.navigationSelectedForeground
        : scheme.onSurfaceVariant;
    final horizontalPadding = item.compact ? 12.0 : 14.0;
    final leadingGap = item.compact ? 8.0 : 10.0;
    final itemExtent = item.compact
        ? _compactRailItemExtent
        : _standardRailItemExtent;
    return Semantics(
      selected: selected,
      button: true,
      label: item.countLabel == null
          ? item.label
          : '${item.label}, ${item.countLabel}',
      child: TextButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              foregroundColor: foreground,
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              minimumSize: Size.fromHeight(itemExtent),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: AlignmentDirectional.centerStart,
              textStyle: context.skillsTypography.bodySecondary,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return foreground.withValues(alpha: .12);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return foreground.withValues(alpha: .08);
                }
                return Colors.transparent;
              }),
            ),
        child: Row(
          children: [
            if (item.leading != null) ...[
              item.leading!,
              SizedBox(width: leadingGap),
            ] else if (item.icon != null) ...[
              HugeIcon(
                icon: item.icon!,
                size: 18,
                strokeWidth: 1.5,
                color: foreground,
              ),
              SizedBox(width: leadingGap),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            if (item.count case final count?) ...[
              SizedBox(width: item.compact ? 6 : 8),
              Tooltip(
                message: item.countLabel ?? '$count',
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: selected ? .14 : .08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: context.skillsTypography.caption.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
