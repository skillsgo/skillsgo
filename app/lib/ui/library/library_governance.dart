/*
 * [INPUT]: Depends on Library content mode, context-scoped Skill metadata and usage evidence, localized governance copy, HugeIcons, and semantic theme roles.
 * [OUTPUT]: Provides the content-level All Skills / Needs Attention switcher, responsive resident-budget insights that pair readable tooltips with a spinning pending indicator while statistics are still being computed, Library-local count badges with update alerts, and actionable unused, Other Installation, and update governance entries with compact update previews.
 * [POS]: Serves as the stable Library governance navigation surface above inventory and governance bodies.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _LibraryContentSwitcher extends StatelessWidget {
  const _LibraryContentSwitcher({
    required this.mode,
    required this.resultCount,
    required this.attentionCount,
    required this.updatesAvailable,
    required this.budget,
    required this.analyticsProgress,
    required this.unusedBudgetSelected,
    required this.onAllSkills,
    required this.onNeedsAttention,
    required this.onUnusedBudget,
  });

  final _LibraryContentMode mode;
  final int resultCount;
  final int attentionCount;
  final bool updatesAvailable;
  final _LibraryResidentBudget? budget;
  final AnalyticsSyncProgress? analyticsProgress;
  final bool unusedBudgetSelected;
  final VoidCallback onAllSkills;
  final VoidCallback onNeedsAttention;
  final VoidCallback onUnusedBudget;

  @override
  Widget build(BuildContext context) {
    final attentionSelected = mode != _LibraryContentMode.allSkills;
    final navigation = Semantics(
      container: true,
      label: context.l10n.libraryNavigation,
      child: Wrap(
        key: const Key('library-content-switcher'),
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LibraryContentSwitchButton(
            key: const Key('library-content-all-skills'),
            label: context.l10n.allSkills,
            count: resultCount,
            countKey: const Key('library-content-count-all-skills'),
            selected: !attentionSelected,
            onPressed: onAllSkills,
          ),
          _LibraryContentSwitchButton(
            key: const Key('library-content-needs-attention'),
            label: context.l10n.libraryNeedsAttention,
            count: attentionCount,
            countKey: const Key('library-content-count-needs-attention'),
            alert: updatesAvailable,
            selected: attentionSelected,
            onPressed: onNeedsAttention,
          ),
        ],
      ),
    );
    final insights = _LibraryBudgetInsights(
      budget: budget,
      analyticsProgress: analyticsProgress,
      unusedSelected: unusedBudgetSelected,
      onUnusedBudget: onUnusedBudget,
    );
    return Wrap(
      key: const Key('library-content-summary'),
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [navigation, insights],
    );
  }
}

class _LibraryResidentBudget {
  const _LibraryResidentBudget({
    required this.skillCount,
    required this.availableUsageCount,
    required this.totalCharacters,
    required this.unused45DaysCharacters,
    required this.partialUsageCoverage,
  });

  final int skillCount;
  final int availableUsageCount;
  final int totalCharacters;
  final int unused45DaysCharacters;
  final bool partialUsageCoverage;

  factory _LibraryResidentBudget.fromSkills(List<InstalledSkill> skills) {
    var total = 0;
    var unused = 0;
    var available = 0;
    var partial = false;
    for (final skill in skills) {
      final characters = _residentCharacters(skill);
      total += characters;
      switch (skill.usageState) {
        case SkillUsageState.available:
          available++;
          if (skill.hits45Days == 0) unused += characters;
        case SkillUsageState.loading:
        case SkillUsageState.unavailable:
          partial = true;
      }
    }
    return _LibraryResidentBudget(
      skillCount: skills.length,
      availableUsageCount: available,
      totalCharacters: total,
      unused45DaysCharacters: unused,
      partialUsageCoverage: partial,
    );
  }
}

int _residentCharacters(InstalledSkill skill) {
  final text = '${skill.name}\n${skill.description}'.trim();
  return math.max(1, text.runes.length);
}

class _LibraryBudgetInsights extends StatelessWidget {
  const _LibraryBudgetInsights({
    required this.budget,
    required this.analyticsProgress,
    required this.unusedSelected,
    required this.onUnusedBudget,
  });

  final _LibraryResidentBudget? budget;
  final AnalyticsSyncProgress? analyticsProgress;
  final bool unusedSelected;
  final VoidCallback onUnusedBudget;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: context.l10n.libraryBudgetInsights,
    child: Container(
      key: const Key('library-budget-insights'),
      child: budget == null
          ? const _LibraryBudgetMetricSkeleton(
              key: Key('library-budget-insights-loading'),
            )
          : _LibraryBudgetMetric(
              metricKey: const Key('library-unused-budget-45-days'),
              primaryLabel: context.l10n.libraryResidentBudget,
              primaryValue: budget!.skillCount == 0
                  ? '—'
                  : '${_formatBudget(budget!.totalCharacters)} ${context.l10n.libraryBudgetCharacters}',
              secondaryLabel: context.l10n.libraryUnusedBudget45Days,
              secondaryValue: _formatUnusedBudget(
                context,
                budget!,
                analyticsProgress,
              ),
              progress: budget!.availableUsageCount == 0
                  ? analyticsProgress
                  : null,
              tooltip: _formatAnalyticsTooltip(
                context,
                budget!,
                analyticsProgress,
              ),
              pending:
                  budget!.skillCount > 0 &&
                  budget!.availableUsageCount == 0 &&
                  (analyticsProgress?.complete ?? false) == false,
              selected: unusedSelected,
              onPressed: budget!.availableUsageCount == 0
                  ? null
                  : onUnusedBudget,
            ),
    ),
  );
}

class _LibraryBudgetMetricSkeleton extends StatelessWidget {
  const _LibraryBudgetMetricSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 332,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

class _LibraryBudgetMetric extends StatelessWidget {
  const _LibraryBudgetMetric({
    required this.metricKey,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.tooltip,
    this.pending = false,
    this.progress,
    this.selected = false,
    this.onPressed,
  });

  final Key metricKey;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final String tooltip;
  final bool pending;
  final AnalyticsSyncProgress? progress;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    final labelColor = selected
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: 0.82);
    final valueColor = selected ? colors.primary : colors.onSurface;
    final tooltipMaxWidth = math.min(
      380.0,
      math.max(200.0, MediaQuery.sizeOf(context).width - 48),
    );
    return Tooltip(
      message: tooltip,
      constraints: BoxConstraints(maxWidth: tooltipMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Semantics(
        button: onPressed != null,
        selected: onPressed == null ? null : selected,
        label: '$primaryLabel, $primaryValue; $secondaryLabel, $secondaryValue',
        child: TextButton(
          key: metricKey,
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: selected
                ? colors.primaryContainer
                : colors.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            minimumSize: const Size(0, 34),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    primaryLabel,
                    key: const Key('library-budget-primary-label'),
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    primaryValue,
                    key: const Key('library-budget-primary-value'),
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    secondaryLabel,
                    key: const Key('library-budget-secondary-label'),
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                  if (pending)
                    SkillsPendingSpinner(
                      key: const Key('library-budget-pending-spinner'),
                      size: 12,
                      color: valueColor,
                      fraction: progress?.complete == false
                          ? progress!.fraction
                          : null,
                    ),
                  Text(
                    secondaryValue,
                    key: const Key('library-budget-secondary-value'),
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBudget(int tokens) {
  if (tokens < 1000) return '$tokens';
  final compact = (tokens / 1000).toStringAsFixed(1);
  return '${compact}k';
}

String _formatUnusedBudget(
  BuildContext context,
  _LibraryResidentBudget budget,
  AnalyticsSyncProgress? progress,
) {
  if (budget.skillCount == 0) return '—';
  if (budget.availableUsageCount == 0) {
    return _formatAnalyticsProgress(context, progress);
  }
  final percentage = budget.totalCharacters == 0
      ? 0
      : (budget.unused45DaysCharacters * 100 / budget.totalCharacters).round();
  final lowerBound = budget.partialUsageCoverage ? '≥' : '';
  return '$lowerBound${_formatBudget(budget.unused45DaysCharacters)} · $percentage%';
}

String _formatAnalyticsProgress(
  BuildContext context,
  AnalyticsSyncProgress? progress,
) {
  if (progress == null || progress.complete) {
    return context.l10n.libraryUsageCalculating;
  }
  final fraction = progress.fraction;
  if (fraction != null) {
    final percentage = (fraction * 100).floor().clamp(0, 100);
    if (progress.bytesTotal == 0 && progress.sessionsTotal > 0) {
      return '$percentage% · ${progress.sessionsDone}/${progress.sessionsTotal}';
    }
    if (progress.bytesTotal == 0 && progress.projectsTotal > 0) {
      return '$percentage% · ${progress.projectsDone}/${progress.projectsTotal}';
    }
    return '$percentage%';
  }
  if (progress.messagesIndexed > 0) {
    return '${context.l10n.libraryUsageCalculating} · ${_formatBudget(progress.messagesIndexed)}';
  }
  return context.l10n.libraryUsageCalculating;
}

String _formatAnalyticsTooltip(
  BuildContext context,
  _LibraryResidentBudget budget,
  AnalyticsSyncProgress? progress,
) {
  if (budget.availableUsageCount > 0 || progress == null) {
    return context.l10n.libraryUnusedBudget45DaysTooltip;
  }
  final counts = progress.sessionsTotal > 0
      ? '${progress.sessionsDone} / ${progress.sessionsTotal}'
      : progress.messagesIndexed > 0
      ? _formatBudget(progress.messagesIndexed)
      : '';
  return counts.isEmpty
      ? context.l10n.libraryUsageCalculating
      : '${context.l10n.libraryUsageCalculating} · $counts';
}

class _LibraryContentSwitchButton extends StatelessWidget {
  const _LibraryContentSwitchButton({
    super.key,
    required this.label,
    required this.count,
    required this.countKey,
    this.alert = false,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final Key countKey;
  final bool alert;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        minimumSize: const Size(0, 34),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 7),
          _LibraryCountBadge(key: countKey, count: count, alert: alert),
        ],
      ),
    ),
  );
}

class _LibraryNeedsAttentionBody extends StatelessWidget {
  const _LibraryNeedsAttentionBody({
    required this.unusedCount,
    required this.externalCount,
    required this.updateCount,
    required this.updateSkills,
    required this.checkingUpdates,
    required this.onUnused,
    required this.onExternal,
    required this.onUpdates,
  });

  final int unusedCount;
  final int externalCount;
  final int updateCount;
  final List<InstalledSkill> updateSkills;
  final bool checkingUpdates;
  final VoidCallback onUnused;
  final VoidCallback onExternal;
  final VoidCallback onUpdates;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('library-needs-attention-body'),
    children: [
      _LibraryGovernanceEntry(
        key: const Key('library-attention-unused'),
        icon: HugeIcons.strokeRoundedAlarmClockOff,
        title: context.l10n.libraryUnused45Days,
        description: context.l10n.libraryFilterUnused45DaysTooltip,
        count: unusedCount,
        onPressed: onUnused,
      ),
      const SizedBox(height: 10),
      _LibraryGovernanceEntry(
        key: const Key('library-attention-other-installation'),
        icon: HugeIcons.strokeRoundedFolderOpen,
        title: context.l10n.libraryLocalSkills,
        description: context.l10n.libraryFilterOtherTooltip,
        count: externalCount,
        onPressed: onExternal,
      ),
      const SizedBox(height: 10),
      _LibraryGovernanceEntry(
        key: const Key('library-attention-updates'),
        icon: HugeIcons.strokeRoundedArrowReloadVertical,
        title: context.l10n.updatesOnly,
        description: checkingUpdates
            ? context.l10n.loading
            : context.l10n.libraryFilterUpdatesTooltip,
        count: updateCount,
        badgeKey: const Key('library-attention-updates-count'),
        alert: updateCount > 0,
        trailing: _LibraryUpdateSkillPreview(
          key: const Key('library-update-skill-preview'),
          skills: updateSkills,
        ),
        onPressed: onUpdates,
      ),
    ],
  );
}

class _LibraryGovernanceEntry extends StatelessWidget {
  const _LibraryGovernanceEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    required this.onPressed,
    this.badgeKey,
    this.alert = false,
    this.trailing,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final int count;
  final Key? badgeKey;
  final bool alert;
  final Widget? trailing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 22, strokeWidth: 1.8),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (trailing != null) ...[trailing!, const SizedBox(width: 12)],
            _LibraryCountBadge(key: badgeKey, count: count, alert: alert),
            const SizedBox(width: 8),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 17,
              strokeWidth: 1.8,
            ),
          ],
        ),
      ),
    ),
  );
}

const _maxUpdatePreviewItems = 5;

class _LibraryUpdateSkillPreview extends StatelessWidget {
  const _LibraryUpdateSkillPreview({super.key, required this.skills});

  final List<InstalledSkill> skills;

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();
    final visible = skills.take(_maxUpdatePreviewItems).toList(growable: false);
    final remaining = skills.length - visible.length;
    return Semantics(
      label: context.l10n.updatesOnly,
      child: Row(
        key: const Key('library-update-skill-preview-row'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < visible.length; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            Tooltip(
              message: visible[index].name,
              child: PackageAvatar(
                key: ValueKey(
                  'library-update-skill-avatar-${visible[index].inventoryKey}',
                ),
                source: visible[index].packagePath,
                imageUrl: visible[index].imageUrl,
                size: 24,
                borderRadius: 7,
              ),
            ),
          ],
          if (remaining > 0) ...[
            const SizedBox(width: 4),
            Container(
              key: const Key('library-update-skill-preview-more'),
              height: 24,
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '+$remaining',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LibraryCountBadge extends StatelessWidget {
  const _LibraryCountBadge({
    super.key,
    required this.count,
    this.alert = false,
  });

  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = alert ? colors.onError : colors.onSurfaceVariant;
    return Container(
      height: 17,
      constraints: const BoxConstraints(minWidth: 18),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: alert
            ? colors.error
            : colors.onSurfaceVariant.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Transform.translate(
        offset: const Offset(0, -0.75),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
