/*
 * [INPUT]: Depends on reviewed Target Operation Plans, Riverpod execution state, progress callbacks, and localized confirmation/results UI.
 * [OUTPUT]: Provides the public exact-path removal selection, execution, progress, and result dialog.
 * [POS]: Serves as the Target Operation Plan journey inside the Installation module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

class TargetManagementDialog extends ConsumerStatefulWidget {
  const TargetManagementDialog({
    super.key,
    required this.gateway,
    required this.plan,
    this.initialAction,
  });

  final SkillsGateway gateway;
  final TargetManagementPlan plan;
  final TargetManagementAction? initialAction;

  @override
  ConsumerState<TargetManagementDialog> createState() =>
      TargetManagementDialogState();
}

class TargetManagementDialogState
    extends ConsumerState<TargetManagementDialog> {
  final selectedActions = <String, TargetManagementAction>{};

  @override
  void initState() {
    super.initState();
    final action = widget.initialAction;
    if (action == null) return;
    for (final item in widget.plan.targets) {
      if (!item.allowedActions.contains(action)) continue;
      selectedActions[updateTargetKey(item.target)] = action;
      for (final binding in item.affectedBindings) {
        selectedActions[updateTargetKey(binding)] = action;
      }
    }
  }

  String get operationKey => widget.plan.targets
      .map((item) => updateTargetKey(item.target))
      .join('\u0000');

  TargetManagementOperationState get operation =>
      ref.read(targetManagementOperationProvider(operationKey));

  Map<String, TargetManagementProgress> get progress => operation.progress;

  TargetManagementExecution? get execution => operation.execution;

  Object? get error => operation.error;

  bool get operating => operation.operating;

  TargetManagementPlan get selectedPlan =>
      widget.plan.selectActions(selectedActions);

  int get finishedCount => operation.finishedCount;

  void _selectAction(
    TargetManagementPlanItem item,
    TargetManagementAction action,
  ) {
    setState(() {
      final key = updateTargetKey(item.target);
      if (selectedActions[key] == action) {
        selectedActions.remove(key);
        for (final binding in item.affectedBindings) {
          selectedActions.remove(updateTargetKey(binding));
        }
        return;
      }
      if (item.affectedBindings.isEmpty) {
        selectedActions[key] = action;
      } else {
        for (final binding in item.affectedBindings) {
          selectedActions[updateTargetKey(binding)] = action;
        }
      }
    });
  }

  Future<void> _execute() async {
    final plan = selectedPlan;
    await ref
        .read(targetManagementOperationProvider(operationKey).notifier)
        .execute(plan);
  }

  Widget _applyButton(BuildContext context) {
    final enabled = !operating && selectedActions.isNotEmpty;
    final child = Text(context.l10n.applyTargetActions);
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
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 740),
      title: Text(
        operating
            ? context.l10n.managementProgressTitle
            : result == null
            ? context.l10n.manageTargetsTitle
            : context.l10n.managementResultsTitle,
      ),
      description: Text(
        result == null
            ? context.l10n.manageTargetsDescription
            : context.l10n.managementResultSummary(
                result.summary.succeeded,
                result.summary.failed,
              ),
      ),
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
      child: SizedBox(
        height: 530,
        child: result == null ? _selection() : _results(result),
      ),
    );
  }

  Widget _selection() {
    final plan = selectedPlan;
    final changesWorkspace = plan.targets.any(
      (item) => item.workspaceMetadataChange,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillsCard(
          width: double.infinity,
          title: Text(
            context.l10n.targetActionsSelected(
              selectedActions.length,
              widget.plan.targets.length,
            ),
          ),
          description: Text(context.l10n.manageTargetsDescription),
          footer: operating
              ? SkillsProgress(
                  value: plan.targets.isEmpty
                      ? 0
                      : finishedCount / plan.targets.length,
                  semanticsLabel: context.l10n.managementProgressTitle,
                )
              : null,
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            failureCopy(context, error!).message,
            style: TextStyle(color: context.skillsComponents.statusDanger),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: GlassCard(
            child: ListView.separated(
              itemCount: widget.plan.targets.length,
              separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final item = widget.plan.targets[index];
                final key = updateTargetKey(item.target);
                final selected = selectedActions[key];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _targetLabel(context, item.target),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.target.path,
                              style: context.skillsTypography.caption,
                            ),
                            if (item.diagnostic.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.diagnostic,
                                style: TextStyle(
                                  color:
                                      context.skillsComponents.statusAttention,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      installationHealthChip(context, item.health),
                      const SizedBox(width: 10),
                      SkillsCheckbox(
                        value: selected == TargetManagementAction.remove,
                        enabled: !operating,
                        onChanged: (_) =>
                            _selectAction(item, TargetManagementAction.remove),
                        label: Text(context.l10n.remove),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (changesWorkspace) ...[
          const SizedBox(height: 10),
          Text(
            context.l10n.workspaceOwnershipChanges,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _results(TargetManagementExecution execution) => GlassCard(
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
