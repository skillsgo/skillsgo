/*
 * [INPUT]: Depends on Installed Agent catalogs, multi-dropdown control, logos, localized filter copy, and Library loading geometry.
 * [OUTPUT]: Provides the Added Project action, combinable Agent filter, filter summaries/options, logo strip, and Library skeleton.
 * [POS]: Serves as the filter and loading presentation segment of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _LibraryAgentMultiFilter extends StatefulWidget {
  const _LibraryAgentMultiFilter({
    super.key,
    required this.agents,
    required this.selectedAgents,
    required this.agentLabel,
    required this.onChanged,
  });

  final List<String> agents;
  final Set<String> selectedAgents;
  final String Function(String) agentLabel;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_LibraryAgentMultiFilter> createState() =>
      _LibraryAgentMultiFilterState();
}

class _LibraryAgentMultiFilterState extends State<_LibraryAgentMultiFilter> {
  final controller = MultiSelectController<String>();
  bool syncing = false;

  List<DropdownItem<String>> get items => [
    for (final agent in widget.agents)
      DropdownItem(
        label: widget.agentLabel(agent),
        value: agent,
        selected: widget.selectedAgents.contains(agent),
      ),
  ];

  @override
  void didUpdateWidget(covariant _LibraryAgentMultiFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.agents, widget.agents) ||
        !setEquals(oldWidget.selectedAgents, widget.selectedAgents)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.isDisposed) return;
        syncing = true;
        controller.setItems(items);
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _showAllAgents() {
    controller
      ..clearAll()
      ..closeDropdown();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    final labelStyle = const TextStyle(fontSize: 14);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final widestLabel = items.fold<double>(0, (width, item) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: labelStyle),
        textScaler: textScaler,
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      return math.max(width, painter.width);
    });
    final dropdownWidth = (widestLabel + 76).clamp(190.0, 280.0);
    final semanticLabel = widget.selectedAgents.isEmpty
        ? context.l10n.allAgents
        : widget.selectedAgents.length == 1
        ? widget.agentLabel(widget.selectedAgents.first)
        : '× ${widget.selectedAgents.length}';
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 168,
        height: 36,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: dropdownWidth,
                maxWidth: dropdownWidth,
                child: MultiDropdown<String>(
                  controller: controller,
                  items: items,
                  closeOnBackButton: false,
                  fieldDecoration: FieldDecoration(
                    hintText: '',
                    showClearIcon: false,
                    animateSuffixIcon: false,
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.surfaceMuted.withValues(alpha: 0),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixIcon: null,
                  ),
                  dropdownDecoration: DropdownDecoration(
                    backgroundColor: colors.surfaceMuted,
                    elevation: 5,
                    maxHeight: 360,
                    marginTop: 6,
                    borderRadius: BorderRadius.circular(14),
                    listPadding: const EdgeInsets.symmetric(vertical: 6),
                    header: _AgentFilterAllRow(
                      selected: widget.selectedAgents.isEmpty,
                      onPressed: _showAllAgents,
                    ),
                    noItemsFoundText: context.l10n.noInstalledAgentsTitle,
                    animationDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    animationCurve: Curves.easeOutCubic,
                  ),
                  itemBuilder: (item, index, onTap) => _AgentFilterOptionRow(
                    agent: item.value,
                    label: item.label,
                    selected: item.selected,
                    onPressed: onTap,
                  ),
                  selectedItemBuilder: (_) => const SizedBox.shrink(),
                  chipDecoration: const ChipDecoration(
                    padding: EdgeInsets.zero,
                    spacing: 0,
                    runSpacing: 0,
                  ),
                  onSelectionChange: (values) {
                    if (syncing) return;
                    widget.onChanged(values.toSet());
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderMuted),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              end: 24,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AgentFilterSummary(
                      selectedAgents: widget.selectedAgents,
                      agentLabel: widget.agentLabel,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 10,
              top: 11.5,
              child: IgnorePointer(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  size: 13,
                  strokeWidth: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentFilterSummary extends StatelessWidget {
  const _AgentFilterSummary({
    required this.selectedAgents,
    required this.agentLabel,
  });

  final Set<String> selectedAgents;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    if (selectedAgents.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedRobot01,
            size: 16,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              context.l10n.allAgents,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    if (selectedAgents.length == 1) {
      final agent = selectedAgents.first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AgentLogo(agentId: agent, displayName: agentLabel(agent), size: 17),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              agentLabel(agent),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    const countStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    final countLabel = '× ${selectedAgents.length}';
    return LayoutBuilder(
      builder: (context, constraints) {
        const logoSize = 17.0;
        const logoGap = 6.0;
        final expandedLogoWidth =
            selectedAgents.length * logoSize +
            (selectedAgents.length - 1) * logoGap;
        if (expandedLogoWidth <= constraints.maxWidth) {
          return _AgentLogoStrip(
            agents: selectedAgents.toList(),
            step: logoSize + logoGap,
          );
        }
        final countPainter = TextPainter(
          text: TextSpan(text: countLabel, style: countStyle),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final availableForLogos = constraints.maxWidth - countPainter.width - 7;
        final visibleCount = availableForLogos < 17
            ? 1
            : (1 + ((availableForLogos - 17) / 10).floor()).clamp(
                1,
                selectedAgents.length,
              );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AgentLogoStrip(
              agents: selectedAgents.take(visibleCount).toList(),
              step: 10,
            ),
            const SizedBox(width: 7),
            Text(countLabel, style: countStyle),
          ],
        );
      },
    );
  }
}

class _AgentLogoStrip extends StatelessWidget {
  const _AgentLogoStrip({required this.agents, required this.step});

  final List<String> agents;
  final double step;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 17 + (agents.length - 1) * step,
    height: 19,
    child: Stack(
      children: [
        for (var index = 0; index < agents.length; index++)
          PositionedDirectional(
            start: index * step,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.skillsColors.surfaceMuted),
              ),
              child: AgentLogo(
                agentId: agents[index],
                displayName: agents[index],
                size: 17,
              ),
            ),
          ),
      ],
    ),
  );
}

class _AgentFilterAllRow extends StatelessWidget {
  const _AgentFilterAllRow({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.allAgents,
    button: true,
    selected: selected,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedRobot01,
                size: 18,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(context.l10n.allAgents)),
              if (selected)
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick01,
                  size: 18,
                  strokeWidth: 1.8,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AgentFilterOptionRow extends StatelessWidget {
  const _AgentFilterOptionRow({
    required this.agent,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String agent;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    selected: selected,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              AgentLogo(agentId: agent, displayName: label, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick01,
                  size: 18,
                  strokeWidth: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('library-skeleton'),
    itemCount: 5,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: context.skillsComponents.cardRest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SkillsSkeletonBox(height: 42, width: 42, borderRadius: 12),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkillsSkeletonBox(height: 15, width: 180),
                  SizedBox(height: 9),
                  SkillsSkeletonBox(height: 11, width: 280),
                ],
              ),
            ),
            SizedBox(width: 16),
            SkillsSkeletonBox(height: 32, width: 88, borderRadius: 999),
          ],
        ),
      ),
    ),
  );
}
