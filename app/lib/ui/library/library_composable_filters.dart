/*
 * [INPUT]: Depends on Library management/usage filter state, localized labels, Material menus, HugeIcons, and semantic theme roles.
 * [OUTPUT]: Provides a clearly named compact Library filter trigger, active-condition count, and a dense desktop popover whose default choices stay neutral while active management and usage conditions receive emphasis.
 * [POS]: Serves as the query-filter control for the unified Library journey, replacing the legacy mixed-purpose scope dropdown.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _LibraryFilterControl extends StatelessWidget {
  const _LibraryFilterControl({
    required this.managementFilter,
    required this.usageFilter,
    required this.onManagementChanged,
    required this.onUsageChanged,
  });

  final _LibraryManagementFilter managementFilter;
  final _LibraryUsageFilter usageFilter;
  final ValueChanged<_LibraryManagementFilter> onManagementChanged;
  final ValueChanged<_LibraryUsageFilter> onUsageChanged;

  int get activeCount =>
      (managementFilter == _LibraryManagementFilter.all ? 0 : 1) +
      (usageFilter == _LibraryUsageFilter.all ? 0 : 1);

  String _managementLabel(BuildContext context) => switch (managementFilter) {
    _LibraryManagementFilter.all => context.l10n.all,
    _LibraryManagementFilter.managed => context.l10n.libraryImportedSkills,
    _LibraryManagementFilter.otherInstallation =>
      context.l10n.libraryLocalSkills,
  };

  String _usageLabel(BuildContext context) => switch (usageFilter) {
    _LibraryUsageFilter.all => context.l10n.libraryAnyUsage,
    _LibraryUsageFilter.unused45Days => context.l10n.libraryUnused45Days,
    _LibraryUsageFilter.unused90Days => context.l10n.libraryUnused90Days,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          scheme.shadow.withValues(alpha: 0.18),
        ),
        elevation: const WidgetStatePropertyAll(10),
        minimumSize: const WidgetStatePropertyAll(Size(196, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.borderMuted),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 7),
        ),
      ),
      menuChildren: [
        _LibraryFilterSectionLabel(label: context.l10n.libraryManagementStatus),
        _LibraryManagementFilterItem(
          label: context.l10n.all,
          value: _LibraryManagementFilter.all,
          selected: managementFilter == _LibraryManagementFilter.all,
          onSelected: onManagementChanged,
        ),
        _LibraryManagementFilterItem(
          label: context.l10n.libraryImportedSkills,
          value: _LibraryManagementFilter.managed,
          selected: managementFilter == _LibraryManagementFilter.managed,
          onSelected: onManagementChanged,
        ),
        _LibraryManagementFilterItem(
          label: context.l10n.libraryLocalSkills,
          value: _LibraryManagementFilter.otherInstallation,
          selected:
              managementFilter == _LibraryManagementFilter.otherInstallation,
          onSelected: onManagementChanged,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Divider(height: 1),
        ),
        _LibraryFilterSectionLabel(label: context.l10n.libraryUsageStatus),
        _LibraryUsageFilterItem(
          label: context.l10n.libraryAnyUsage,
          value: _LibraryUsageFilter.all,
          selected: usageFilter == _LibraryUsageFilter.all,
          onSelected: onUsageChanged,
        ),
        _LibraryUsageFilterItem(
          label: context.l10n.libraryUnused45Days,
          value: _LibraryUsageFilter.unused45Days,
          selected: usageFilter == _LibraryUsageFilter.unused45Days,
          onSelected: onUsageChanged,
        ),
        _LibraryUsageFilterItem(
          label: context.l10n.libraryUnused90Days,
          value: _LibraryUsageFilter.unused90Days,
          selected: usageFilter == _LibraryUsageFilter.unused90Days,
          onSelected: onUsageChanged,
        ),
      ],
      builder: (context, controller, child) => Semantics(
        key: const Key('library-filter'),
        label:
            '${context.l10n.libraryManagementStatus}: ${_managementLabel(context)}, '
            '${context.l10n.libraryUsageStatus}: ${_usageLabel(context)}',
        value: '$activeCount',
        button: true,
        child: AnimatedContainer(
          width: activeCount > 0 ? 122 : 104,
          height: 36,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: OutlinedButton(
            key: const Key('library-filter-trigger'),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: colors.surfaceMuted,
              side: BorderSide(color: colors.borderMuted),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedFilterHorizontal,
                  size: 16,
                  strokeWidth: 1.8,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    context.l10n.libraryFilter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeCount > 0) ...[
                  const SizedBox(width: 6),
                  _LibraryFilterCountBadge(count: activeCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryFilterCountBadge extends StatelessWidget {
  const _LibraryFilterCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _LibraryFilterSectionLabel extends StatelessWidget {
  const _LibraryFilterSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 3),
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _LibraryManagementFilterItem extends StatelessWidget {
  const _LibraryManagementFilterItem({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final _LibraryManagementFilter value;
  final bool selected;
  final ValueChanged<_LibraryManagementFilter> onSelected;

  @override
  Widget build(BuildContext context) => _LibraryFilterMenuItem(
    key: ValueKey('library-management-filter-${value.name}'),
    label: label,
    selected: selected,
    emphasized: selected && value != _LibraryManagementFilter.all,
    onPressed: () => onSelected(value),
  );
}

class _LibraryUsageFilterItem extends StatelessWidget {
  const _LibraryUsageFilterItem({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final _LibraryUsageFilter value;
  final bool selected;
  final ValueChanged<_LibraryUsageFilter> onSelected;

  @override
  Widget build(BuildContext context) => _LibraryFilterMenuItem(
    key: ValueKey('library-usage-filter-${value.name}'),
    label: label,
    selected: selected,
    emphasized: selected && value != _LibraryUsageFilter.all,
    onPressed: () => onSelected(value),
  );
}

class _LibraryFilterMenuItem extends StatelessWidget {
  const _LibraryFilterMenuItem({
    super.key,
    required this.label,
    required this.selected,
    required this.emphasized,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool emphasized;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: MenuItemButton(
          onPressed: onPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(184, 34)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            foregroundColor: WidgetStatePropertyAll(
              emphasized ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return scheme.surfaceContainerHighest;
              }
              return emphasized
                  ? scheme.primaryContainer.withValues(alpha: 0.58)
                  : Colors.transparent;
            }),
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontSize: 13,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          leadingIcon: SizedBox.square(
            dimension: 16,
            child: selected
                ? HugeIcon(
                    icon: HugeIcons.strokeRoundedTick01,
                    size: 15,
                    strokeWidth: 2,
                    color: emphasized
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  )
                : null,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
