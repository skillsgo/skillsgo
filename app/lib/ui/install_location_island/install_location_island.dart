/*
 * Derived from Portal Labs Todo List Interaction, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter Material, physics, semantics, a caller-provided scope selector, optional row-leading identities, and an isolated inner scroll position.
 * [OUTPUT]: Provides a controlled installation-location Island with a composable header, compact identified rows, collapsible groups, animated rows, clipped rounded corners, and Portal Labs visual structure.
 * [POS]: Serves as the vendored Portal Labs interaction adapted from Todo semantics to SkillsGo installation targets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

@immutable
class InstallLocationIslandItem {
  const InstallLocationIslandItem({
    required this.id,
    required this.label,
    required this.selected,
    required this.enabled,
    this.leading,
    this.supportingText,
  });

  final String id;
  final String label;
  final bool selected;
  final bool enabled;
  final Widget? leading;
  final String? supportingText;
}

@immutable
class InstallLocationIslandGroup {
  const InstallLocationIslandGroup({
    required this.id,
    required this.label,
    required this.items,
    this.trailing,
    this.showHeader = true,
    this.collapsible = true,
    this.prominentHeader = false,
    this.itemLeftPadding = 16,
    this.selectionControlWidth = 40,
  });

  final String id;
  final String label;
  final List<InstallLocationIslandItem> items;
  final Widget? trailing;
  final bool showHeader;
  final bool collapsible;
  final bool prominentHeader;
  final double itemLeftPadding;
  final double selectionControlWidth;
}

@immutable
class InstallLocationIslandStyle {
  const InstallLocationIslandStyle({
    required this.outerBackgroundColor,
    required this.cardBackgroundColor,
    required this.tabTrackColor,
    required this.tabIndicatorColor,
    required this.tabIndicatorTextColor,
    required this.selectedColor,
    required this.checkboxBorderColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.shadowColor,
    this.outerBorderRadius = 28,
    this.cardBorderRadius = 22,
    this.springStiffness = 220,
    this.springDamping = 20,
  });

  final Color outerBackgroundColor;
  final Color cardBackgroundColor;
  final Color tabTrackColor;
  final Color tabIndicatorColor;
  final Color tabIndicatorTextColor;
  final Color selectedColor;
  final Color checkboxBorderColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color shadowColor;
  final double outerBorderRadius;
  final double cardBorderRadius;
  final double springStiffness;
  final double springDamping;
}

class InstallLocationIsland extends StatelessWidget {
  const InstallLocationIsland({
    super.key,
    required this.header,
    required this.groups,
    required this.style,
    required this.onItemChanged,
    required this.footer,
    this.contentKey,
  });

  final Widget header;
  final List<InstallLocationIslandGroup> groups;
  final InstallLocationIslandStyle style;
  final void Function(String groupId, String itemId, bool selected)
  onItemChanged;
  final Widget footer;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      decoration: BoxDecoration(
        color: style.cardBackgroundColor,
        borderRadius: BorderRadius.circular(style.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: style.shadowColor.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: contentKey,
              primary: false,
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: header,
                  ),
                  const SizedBox(height: 9),
                  for (final group in groups)
                    _IslandGroup(
                      key: ValueKey(group.id),
                      group: group,
                      style: style,
                      onItemChanged: onItemChanged,
                    ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: style.cardBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: style.secondaryTextColor.withValues(alpha: .10),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: footer,
            ),
          ),
        ],
      ),
    ),
  );
}

class _IslandGroup extends StatefulWidget {
  const _IslandGroup({
    super.key,
    required this.group,
    required this.style,
    required this.onItemChanged,
  });

  final InstallLocationIslandGroup group;
  final InstallLocationIslandStyle style;
  final void Function(String groupId, String itemId, bool selected)
  onItemChanged;

  @override
  State<_IslandGroup> createState() => _IslandGroupState();
}

class _IslandGroupState extends State<_IslandGroup>
    with SingleTickerProviderStateMixin {
  bool expanded = true;
  late final AnimationController rotation;

  @override
  void initState() {
    super.initState();
    rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1,
    );
  }

  @override
  void dispose() {
    rotation.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() => expanded = !expanded);
    expanded ? rotation.forward() : rotation.reverse();
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 650),
    curve: _IslandSpringCurve(
      stiffness: widget.style.springStiffness,
      damping: widget.style.springDamping,
    ),
    alignment: Alignment.topCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.group.showHeader)
          InkWell(
            onTap: widget.group.collapsible ? toggle : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.group.prominentHeader ? 16 : 15,
                vertical: 6,
              ),
              child: Row(
                children: [
                  if (widget.group.collapsible) ...[
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: .25).animate(
                        CurvedAnimation(
                          parent: rotation,
                          curve: _IslandSpringCurve(
                            stiffness: widget.style.springStiffness,
                            damping: widget.style.springDamping * .75,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_right_rounded,
                        size: 22,
                        color: widget.style.textColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Expanded(
                    child: Text(
                      widget.group.label,
                      style: TextStyle(
                        color: widget.style.textColor,
                        fontSize: widget.group.prominentHeader ? 15 : 13.5,
                        fontWeight: widget.group.prominentHeader
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.group.trailing != null) widget.group.trailing!,
                ],
              ),
            ),
          ),
        ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            heightFactor: expanded ? 1 : 0,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: expanded ? 1 : 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in widget.group.items)
                    _IslandItem(
                      item: item,
                      style: widget.style,
                      leftPadding: widget.group.itemLeftPadding,
                      selectionControlWidth: widget.group.selectionControlWidth,
                      onChanged: (selected) => widget.onItemChanged(
                        widget.group.id,
                        item.id,
                        selected,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _IslandItem extends StatelessWidget {
  const _IslandItem({
    required this.item,
    required this.style,
    required this.leftPadding,
    required this.selectionControlWidth,
    required this.onChanged,
  });

  final InstallLocationIslandItem item;
  final InstallLocationIslandStyle style;
  final double leftPadding;
  final double selectionControlWidth;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: item.enabled,
    checked: item.selected,
    label: item.label,
    child: InkWell(
      onTap: item.enabled ? () => onChanged(!item.selected) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(leftPadding, 6, 18, 6),
        child: Row(
          children: [
            SizedBox(
              width: selectionControlWidth,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: item.selected
                        ? style.selectedColor
                        : Colors.transparent,
                    border: Border.all(
                      color: item.selected
                          ? style.selectedColor
                          : style.checkboxBorderColor,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: item.selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 12,
                          color:
                              ThemeData.estimateBrightnessForColor(
                                    style.selectedColor,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (item.leading != null) ...[
              SizedBox.square(dimension: 20, child: item.leading),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.enabled
                          ? style.textColor
                          : style.secondaryTextColor.withValues(alpha: .55),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (item.supportingText != null)
                    Text(
                      item.supportingText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: style.secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IslandSpringCurve extends Curve {
  _IslandSpringCurve({required double stiffness, required double damping})
    : simulation = SpringSimulation(
        SpringDescription(mass: 1, stiffness: stiffness, damping: damping),
        0,
        1,
        0,
      );

  final SpringSimulation simulation;

  @override
  double transformInternal(double t) => simulation.x(t).clamp(-.2, 1.2);
}
