/*
 * [INPUT]: Depends on reviewed Target Operation Plans, Riverpod execution state, progress callbacks, and localized confirmation/results UI.
 * [OUTPUT]: Provides the public Material confirmation for compact Skill-first exact-path removal, expandable details, execution progress, and results.
 * [POS]: Serves as the removal confirmation journey inside the Installation module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

class RemoveTargetsDialog extends ConsumerStatefulWidget {
  const RemoveTargetsDialog({
    super.key,
    required this.gateway,
    required this.plan,
  });

  final SkillsGateway gateway;
  final TargetManagementPlan plan;

  @override
  ConsumerState<RemoveTargetsDialog> createState() =>
      RemoveTargetsDialogState();
}

class RemoveTargetsDialogState extends ConsumerState<RemoveTargetsDialog> {
  final selectedActions = <String, TargetManagementAction>{};
  bool showDetails = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.plan.targets) {
      if (!item.allowedActions.contains(TargetManagementAction.remove)) {
        continue;
      }
      selectedActions[installationTargetKey(item.target)] =
          TargetManagementAction.remove;
      for (final binding in item.affectedBindings) {
        selectedActions[installationTargetKey(binding)] =
            TargetManagementAction.remove;
      }
    }
  }

  String get operationKey => widget.plan.targets
      .map((item) => installationTargetKey(item.target))
      .join('\u0000');

  TargetManagementOperationState get operation =>
      ref.read(targetManagementOperationProvider(operationKey));

  Map<String, TargetManagementProgress> get progress => operation.progress;

  TargetManagementExecution? get execution => operation.execution;

  Object? get error => operation.error;

  bool get operating => operation.operating;

  List<({String key, String name, List<TargetManagementPlanItem> items})>
  get skillGroups {
    final grouped = <String, List<TargetManagementPlanItem>>{};
    for (final item in widget.plan.targets) {
      final identity =
          '${item.packagePath}\u0000${item.skillId}\u0000${item.name}';
      grouped.putIfAbsent(identity, () => []).add(item);
    }
    return [
      for (final entry in grouped.entries)
        (
          key: entry.key,
          name: entry.value.first.name,
          items: List.unmodifiable(entry.value),
        ),
    ];
  }

  TargetManagementPlan get selectedPlan =>
      widget.plan.selectActions(selectedActions);

  int get finishedCount => operation.finishedCount;

  Future<void> _execute() async {
    final plan = selectedPlan;
    await ref
        .read(targetManagementOperationProvider(operationKey).notifier)
        .execute(plan);
  }

  Widget _applyButton(BuildContext context) {
    final enabled = !operating && selectedActions.isNotEmpty;
    final child = Text(context.l10n.remove);
    return SkillsButton.destructive(
      enabled: enabled,
      onPressed: _execute,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(targetManagementOperationProvider(operationKey));
    final result = execution;
    final title = operating
        ? context.l10n.managementProgressTitle
        : result == null
        ? context.l10n.confirmRemoveTarget
        : context.l10n.managementResultsTitle;
    final description = result == null
        ? _selectionDescription()
        : Text(
            context.l10n.managementResultSummary(
              result.summary.succeeded,
              result.summary.failed,
            ),
          );
    return AlertDialog(
      key: const ValueKey('remove-targets-dialog'),
      backgroundColor: context.skillsComponents.overlay,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 540),
      titlePadding: const EdgeInsetsDirectional.fromSTEB(24, 22, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: context.skillsTypography.bodySecondary,
            child: description,
          ),
        ],
      ),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
      content: SizedBox(
        width: 500,
        child: result == null ? _selection() : _results(result),
      ),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
      actionsAlignment: MainAxisAlignment.end,
      buttonPadding: EdgeInsets.zero,
      actions: [
        if (result == null) ...[
          SkillsButton.outline(
            enabled: !operating,
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          _applyButton(context),
        ] else
          SkillsButton(
            onPressed: () => Navigator.pop(context, result),
            child: Text(context.l10n.closeUpdatePlan),
          ),
      ],
    );
  }

  Widget _selectionDescription() => Row(
    children: [
      Flexible(
        child: Text(
          context.l10n.removeSkillsDescription,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        key: const ValueKey('remove-targets-toggle-details'),
        onPressed: operating
            ? null
            : () => setState(() => showDetails = !showDetails),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          textStyle: context.skillsTypography.compactControlLabel,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          showDetails
              ? context.l10n.hideRemovalDetails
              : context.l10n.viewRemovalDetails,
        ),
      ),
    ],
  );

  Widget _selection() {
    final plan = selectedPlan;
    final groups = skillGroups;
    final detailRows = groups.fold<int>(
      0,
      (total, group) => total + group.items.length,
    );
    final diagnosticRows = showDetails
        ? groups.fold<int>(
            0,
            (total, group) =>
                total +
                group.items.where((item) => item.diagnostic.isNotEmpty).length,
          )
        : 0;
    final listHeight =
        (groups.length * 44 +
                (showDetails ? detailRows * 22 : 0) +
                diagnosticRows * 28)
            .clamp(44, 264)
            .toDouble();
    final animationDuration = const Duration(milliseconds: 180);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (operating)
          SkillsProgress(
            value: plan.targets.isEmpty
                ? 0
                : finishedCount / plan.targets.length,
            semanticsLabel: context.l10n.managementProgressTitle,
          ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            failureCopy(context, error!).message,
            style: TextStyle(color: context.skillsComponents.statusDanger),
          ),
        ],
        if (operating || error != null) const SizedBox(height: 10),
        AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          height: listHeight,
          child: Scrollbar(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: groups.length,
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SkillsSeparator.horizontal(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              itemBuilder: (context, index) {
                final group = groups[index];
                final details = Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 12,
                    top: 3,
                    bottom: 7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in group.items) ...[
                        Tooltip(
                          message: item.target.path,
                          child: Text(
                            item.target.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.skillsTypography.caption.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (item.diagnostic.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3, bottom: 4),
                            child: Text(
                              item.diagnostic,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.skillsTypography.caption.copyWith(
                                color: context.skillsComponents.statusAttention,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 7),
                      ],
                    ],
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 43,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.skillsTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (showDetails) details,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
          child: SkillsSeparator.horizontal(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _results(TargetManagementExecution execution) => SizedBox(
    height: (execution.results.length * 64).clamp(64, 280).toDouble(),
    child: ListView.separated(
      itemCount: execution.results.length,
      separatorBuilder: (_, _) => SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final result = execution.results[index];
        final failed = result.outcome == TargetManagementOutcome.failed;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _targetLabel(context, result.target),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _managementActionLabel(context, result.action),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (result.error != null)
                      _targetFailureDetails(context, result.error!),
                  ],
                ),
              ),
              StatusChip(
                label: failed
                    ? context.l10n.targetFailed
                    : context.l10n.targetSucceeded,
                color: failed
                    ? context.skillsComponents.statusDanger
                    : context.skillsComponents.statusSuccess,
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _managementActionLabel(
  BuildContext context,
  TargetManagementAction action,
) => switch (action) {
  TargetManagementAction.remove => context.l10n.remove,
};
