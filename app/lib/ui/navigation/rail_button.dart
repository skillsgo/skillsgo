/*
 * [INPUT]: Depends on the shared nested-navigation library, a localized label, optional HugeIcon or image identity, Unicode grapheme clusters for automatic multilingual abbreviation, optional exact counts, selection state, compact density, stable navigation-label typography, composited state coloring, and Flutter Material interaction primitives.
 * [OUTPUT]: Provides the public accessible SkillsNavigationButton with icon/image/fallback identity resolution, optical alignment, multilingual abbreviation, layout-stable selected coloring, and an optional inline count capsule used by SkillsSideRail and standalone navigation surfaces.
 * [POS]: Serves as the per-destination row presentation segment of nested navigation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../nested_navigation.dart';

class SkillsNavigationButton extends StatelessWidget {
  const SkillsNavigationButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.focusNode,
    this.compact = false,
    this.icon,
    this.image,
    this.count,
    this.countLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool compact;
  final List<List<dynamic>>? icon;
  final Widget? image;
  final int? count;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? context.skillsComponents.navigationSelectedForeground
        : scheme.onSurfaceVariant;
    const horizontalPadding = 14.0;
    const leadingGap = 10.0;
    return Semantics(
      selected: selected,
      button: true,
      label: countLabel == null ? label : '$label, $countLabel',
      child: TextButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              foregroundColor: foreground,
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              minimumSize: const Size.fromHeight(_railItemExtent),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: AlignmentDirectional.centerStart,
              textStyle: context.skillsTypography.navigationLabel,
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
            _identity(context, foreground),
            SizedBox(width: leadingGap),
            Expanded(
              child: Transform.translate(
                offset: Offset(
                  0,
                  icon == null
                      ? context.skillsComponents.navigationLabelOpticalOffsetY
                      : context
                            .skillsComponents
                            .navigationStrokeLabelOpticalOffsetY,
                ),
                child: ColorFiltered(
                  key: const Key('skills-navigation-label-color'),
                  colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                  child: Text(
                    label,
                    style: context.skillsTypography.navigationLabel.copyWith(
                      color: scheme.onSurface,
                    ),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            if (count case final count?) ...[
              SizedBox(width: compact ? 6 : 8),
              Tooltip(
                message: countLabel ?? '$count',
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

  Widget _identity(BuildContext context, Color foreground) {
    if (icon case final icon?) {
      return Transform.translate(
        offset: Offset(
          0,
          context.skillsComponents.navigationStrokeIconOpticalOffsetY,
        ),
        child: HugeIcon(
          icon: icon,
          size: 18,
          strokeWidth: 1.5,
          color: foreground,
        ),
      );
    }
    if (image case final image?) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox.square(dimension: 18, child: image),
      );
    }
    return Container(
      key: const Key('skills-navigation-fallback-identity'),
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: selected ? .16 : .08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: foreground.withValues(alpha: .18)),
      ),
      child: Text(
        skillsNavigationAbbreviation(label),
        maxLines: 1,
        style: context.skillsTypography.compactControlLabel.copyWith(
          color: foreground,
          fontSize: 7,
          height: 1,
        ),
      ),
    );
  }
}

String skillsNavigationAbbreviation(String label) {
  final words = label
      .trim()
      .split(RegExp(r'[\s\-_—–/\\·・、，。:：]+', unicode: true))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length > 1) {
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }
  return words.single.characters.take(2).toString().toUpperCase();
}
