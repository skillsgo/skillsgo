/*
 * [INPUT]: Depends on reviewed Update Plans, Riverpod execution state, progress callbacks, retry state, and localized result UI.
 * [OUTPUT]: Provides the public target-specific update selection, execution, failed-only retry, progress, and result dialog.
 * [POS]: Serves as the Update Plan journey inside the Installation module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

class UpdatePlanDialog extends ConsumerStatefulWidget {
  const UpdatePlanDialog({
    super.key,
    required this.gateway,
    required this.skill,
    required this.plan,
  });

  final SkillsGateway gateway;
  final InstalledSkill skill;
  final UpdatePlan plan;

  @override
  ConsumerState<UpdatePlanDialog> createState() => UpdatePlanDialogState();
}

class UpdatePlanDialogState extends ConsumerState<UpdatePlanDialog> {
  late final Set<String> selected = {
    for (final item in widget.plan.targets)
      if (item.action == UpdatePlanAction.update) updateTargetKey(item.target),
  };
  UpdateOperationState get operation =>
      ref.read(updateOperationProvider(widget.skill.inventoryKey));

  Map<String, UpdateTargetProgress> get progress => operation.progress;

  UpdateExecution? get execution => operation.execution;

  Object? get error => operation.error;

  bool get operating => operation.operating;

  List<UpdatePlanItem> get selectedItems => widget.plan.targets
      .where((item) => selected.contains(updateTargetKey(item.target)))
      .toList(growable: false);

  int get availableCount => widget.plan.targets
      .where((item) => item.action == UpdatePlanAction.update)
      .length;

  int get finishedCount => operation.finishedCount;

  Future<void> _execute({UpdatePlan? retryPlan}) async {
    final plan = retryPlan ?? widget.plan.selectTargets(selectedItems);
    await ref
        .read(updateOperationProvider(widget.skill.inventoryKey).notifier)
        .execute(plan);
  }

  Future<void> _retryFailed() => ref
      .read(updateOperationProvider(widget.skill.inventoryKey).notifier)
      .retryFailed(widget.skill);

  @override
  Widget build(BuildContext context) {
    ref.watch(updateOperationProvider(widget.skill.inventoryKey));
    final currentExecution = execution;
    final title = operating
        ? context.l10n.updateProgressTitle
        : currentExecution != null
        ? context.l10n.updateResultsTitle
        : context.l10n.updatePlanTitle;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
      title: Text(title),
      description: Text(
        operating
            ? context.l10n.updateProgressSummary(
                finishedCount,
                (currentExecution == null
                    ? selectedItems.length
                    : currentExecution.results
                          .where(
                            (result) =>
                                result.outcome == UpdateTargetOutcome.failed,
                          )
                          .length),
              )
            : currentExecution != null
            ? context.l10n.installationResultSummary(
                currentExecution.summary.succeeded,
                currentExecution.summary.failed,
              )
            : context.l10n.updatePlanDescription,
      ),
      actions: [
        if (currentExecution == null) ...[
          SkillsButton.outline(
            enabled: !operating,
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          SkillsButton(
            enabled: !operating && selectedItems.isNotEmpty,
            onPressed: _execute,
            child: Text(context.l10n.updateSelectedTargets),
          ),
        ] else ...[
          if (currentExecution.summary.failed > 0)
            SkillsButton.outline(
              enabled: !operating,
              onPressed: _retryFailed,
              child: Text(
                context.l10n.retryFailedUpdates(
                  currentExecution.summary.failed,
                ),
              ),
            ),
          SkillsButton(
            enabled: !operating,
            onPressed: () => Navigator.pop(context, currentExecution),
            child: Text(context.l10n.closeUpdatePlan),
          ),
        ],
      ],
      child: SizedBox(
        height: 500,
        child: operating && currentExecution == null
            ? _liveProgress(selectedItems)
            : currentExecution != null
            ? _results(currentExecution)
            : _selection(),
      ),
    );
  }

  Widget _selection() {
    final selectedPlan = widget.plan.selectTargets(selectedItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillsCard(
          width: double.infinity,
          title: Text(
            context.l10n.updateTargetsSelected(
              selectedItems.length,
              availableCount,
            ),
          ),
          description: Text(context.l10n.updatePlanDescription),
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
                final enabled = item.action == UpdatePlanAction.update;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SkillsCheckbox(
                    value: selected.contains(key),
                    enabled: enabled && !operating,
                    onChanged: (value) => setState(() {
                      final bindings = item.affectedBindings.isEmpty
                          ? [item.target]
                          : item.affectedBindings;
                      for (final binding in bindings) {
                        final bindingKey = updateTargetKey(binding);
                        if (value) {
                          selected.add(bindingKey);
                        } else {
                          selected.remove(bindingKey);
                        }
                      }
                    }),
                    label: SizedBox(
                      width: 690,
                      child: Row(
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
                                  context.l10n.sourceReference(item.sourceRef),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item.affectedBindings.isNotEmpty)
                                  Text(
                                    context.l10n.agentsSummary(
                                      item.affectedBindings.length,
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .72),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusChip(
                            label: _updatePlanItemLabel(context, item),
                            color: enabled
                                ? context.skillsComponents.statusSevere
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (selectedPlan.workspaceManifestChanges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.workspaceManifestChanges,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final change in selectedPlan.workspaceManifestChanges)
            Text(
              '${change.path}: ${change.fromVersion} → ${change.toVersion}',
              style: context.skillsTypography.caption,
            ),
        ],
      ],
    );
  }

  Widget _liveProgress(List<UpdatePlanItem> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkillsCard(
        width: double.infinity,
        title: Text(context.l10n.updateProgressTitle),
        description: Text(
          context.l10n.updateProgressSummary(finishedCount, items.length),
        ),
        footer: SkillsProgress(
          value: items.isEmpty ? 0 : finishedCount / items.length,
          minHeight: 5,
          semanticsLabel: context.l10n.updateProgressTitle,
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: GlassCard(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final event = progress[updateTargetKey(item.target)];
              final finished =
                  event?.state == InstallationProgressState.finished;
              final failed =
                  event?.result?.outcome == UpdateTargetOutcome.failed;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: finished
                          ? failed
                                ? HugeIcons.strokeRoundedAlertCircle
                                : HugeIcons.strokeRoundedCheckmarkCircle02
                          : HugeIcons.strokeRoundedLoading03,
                      strokeWidth: 1.8,
                      color: finished
                          ? failed
                                ? context.skillsComponents.statusDanger
                                : context.skillsComponents.statusSuccess
                          : context.skillsComponents.statusAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _targetLabel(context, item.target),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusChip(
                      label: event == null
                          ? context.l10n.targetWaiting
                          : finished
                          ? failed
                                ? context.l10n.targetFailed
                                : context.l10n.update
                          : context.l10n.updateProgressTitle,
                      color: failed
                          ? context.skillsComponents.statusDanger
                          : context.skillsComponents.statusAccent,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _results(UpdateExecution current) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (operating)
        SkillsProgress(
          value: current.results.isEmpty
              ? null
              : finishedCount / current.results.length,
          minHeight: 5,
          semanticsLabel: context.l10n.updateProgressTitle,
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
            itemCount: current.results.length,
            separatorBuilder: (_, _) => SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final result = current.results[index];
              final failed = result.outcome == UpdateTargetOutcome.failed;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: failed
                          ? HugeIcons.strokeRoundedAlertCircle
                          : HugeIcons.strokeRoundedCheckmarkCircle02,
                      strokeWidth: 1.8,
                      color: failed
                          ? context.skillsComponents.statusDanger
                          : context.skillsComponents.statusSuccess,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _targetLabel(context, result.target),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            context.l10n.updateVersionChange(
                              result.fromVersion,
                              result.toVersion,
                            ),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                          : context.l10n.update,
                      color: failed
                          ? context.skillsComponents.statusDanger
                          : context.skillsComponents.statusSuccess,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

String _updatePlanItemLabel(BuildContext context, UpdatePlanItem item) =>
    item.reasonCode == 'workspace-manifest-reconcile'
    ? context.l10n.reconcileWorkspaceManifestTarget
    : switch (item.action) {
        UpdatePlanAction.update => context.l10n.updateVersionChange(
          item.fromVersion,
          item.toVersion,
        ),
        UpdatePlanAction.current => context.l10n.currentVersionTarget,
        UpdatePlanAction.pinned => context.l10n.fixedVersionTarget,
        UpdatePlanAction.failed => context.l10n.updateCheckTargetFailed,
      };
