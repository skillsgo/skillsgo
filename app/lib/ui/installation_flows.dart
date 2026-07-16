/*
 * [INPUT]: Depends on the app_shell library for gateway contracts, Riverpod installation operations, localized UI components, and shared navigation callbacks.
 * [OUTPUT]: Provides remote Skill detail plus Installation, Update, Target Management, risk review, progress, result, and retry flows.
 * [POS]: Serves as the complete mutation-flow view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

class _SkillCardSkeleton extends StatelessWidget {
  const _SkillCardSkeleton();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.skillsComponents.cardRest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Padding(
      padding: EdgeInsets.fromLTRB(16, 15, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkillsSkeletonBox(height: 38, width: 38, borderRadius: 10),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkillsSkeletonBox(height: 15, width: 150),
                    SizedBox(height: 8),
                    SkillsSkeletonBox(height: 11, width: 110),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          SkillsSkeletonBox(height: 12),
          SizedBox(height: 8),
          SkillsSkeletonBox(height: 12, width: 220),
          Spacer(),
          SkillsSkeletonBox(height: 11, width: 96),
        ],
      ),
    ),
  );
}

Future<List<SkillSummary>> _loadRepositorySkills(
  SkillsGateway gateway,
  SkillSummary current,
  SkillDetail detail,
) async {
  final repository = detail.repository.trim();
  if (repository.isEmpty) return [current];
  try {
    final skills = <String, SkillSummary>{};
    var offset = 0;
    while (true) {
      final page = await gateway.discover(
        DiscoveryCollection.search,
        query: repository,
        offset: offset,
        limit: 100,
      );
      for (final skill in page.skills) {
        if (skill.id == repository || skill.id.startsWith('$repository/-/')) {
          skills[skill.id] = skill;
        }
      }
      final next = page.nextOffset;
      if (next == null || next <= offset) break;
      offset = next;
    }
    skills[current.id] = current;
    final values = skills.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return values;
  } on Object {
    return [current];
  }
}

Future<void> _installRepositorySkills(
  SkillsGateway gateway,
  List<SkillSummary> skills,
  List<InstallationTargetSelection> selections,
  PersonalRiskPolicy riskPolicy,
) async {
  for (final skill in skills) {
    final detail = await gateway.loadRemoteDetail(skill);
    final operation = InstallOperationController();
    final plan = await operation.preflight(
      gateway,
      skill,
      detail.immutableVersion,
      selections,
      allowCritical: riskPolicy.allowCriticalOverride,
    );
    if (plan == null ||
        plan.summary.conflict > 0 ||
        plan.summary.blockedByRisk > 0) {
      continue;
    }
    await operation.execute(gateway);
  }
}

enum _InstallationPlanOutcome { viewLibrary }

class _InstallationPlanDialog extends StatefulWidget {
  const _InstallationPlanDialog({
    required this.gateway,
    required this.skill,
    required this.detail,
    required this.catalog,
    required this.initialProjects,
    required this.operation,
    required this.onProjectAdded,
    required this.riskPolicy,
  });

  final SkillsGateway gateway;
  final SkillSummary skill;
  final SkillDetail detail;
  final AgentCatalog catalog;
  final List<AddedProject> initialProjects;
  final InstallOperationController operation;
  final ValueChanged<AddedProject> onProjectAdded;
  final PersonalRiskPolicy riskPolicy;

  @override
  State<_InstallationPlanDialog> createState() =>
      _InstallationPlanDialogState();
}

class _InstallationPlanDialogState extends State<_InstallationPlanDialog> {
  late List<AddedProject> projects;
  final selected = <String, InstallationTargetSelection>{};
  bool riskConfirmed = false;

  @override
  void initState() {
    super.initState();
    projects = List.of(widget.initialProjects);
    for (final selection in widget.operation.selections) {
      selected[_selectionKey(selection)] = selection;
    }
  }

  List<
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
  >
  get rows => [
    (
      key: 'user',
      label: context.l10n.userScope,
      scope: InstallationScope.user,
      projectRoot: '',
      enabled: true,
    ),
    ...projects.map(
      (project) => (
        key: 'project:${project.id}',
        label: project.name,
        scope: InstallationScope.project,
        projectRoot: project.path,
        enabled: project.isAccessible,
      ),
    ),
  ];

  List<AgentStatus> get agents => widget.catalog.installed;

  String _selectionKey(InstallationTargetSelection selection) =>
      '${selection.scope.name}\u0000${selection.projectRoot}\u0000${selection.agent}';

  InstallationTargetSelection _selectionFor(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) => InstallationTargetSelection(
    scope: row.scope,
    projectRoot: row.projectRoot,
    agent: agent.id,
  );

  bool _isInstalled(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) => widget.detail.installationTargets.any(
    (target) =>
        target.scope == row.scope &&
        target.projectRoot == row.projectRoot &&
        target.agent == agent.id &&
        target.version == widget.detail.immutableVersion &&
        target.health == InstallationHealth.healthy,
  );

  bool _isEligible(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) =>
      row.enabled &&
      agent.supportedScopes.contains(row.scope) &&
      !_isInstalled(row, agent);

  List<InstallationTargetSelection> get selectedInMatrixOrder => [
    for (final row in rows)
      for (final agent in agents)
        if (selected.containsKey(_selectionKey(_selectionFor(row, agent))))
          selected[_selectionKey(_selectionFor(row, agent))]!,
  ];

  void _toggleCell(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
    bool value,
  ) {
    final selection = _selectionFor(row, agent);
    setState(() {
      if (value) {
        selected[_selectionKey(selection)] = selection;
      } else {
        selected.remove(_selectionKey(selection));
      }
    });
  }

  void _toggleRow(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    bool value,
  ) {
    setState(() {
      for (final agent in agents.where((agent) => _isEligible(row, agent))) {
        final selection = _selectionFor(row, agent);
        if (value) {
          selected[_selectionKey(selection)] = selection;
        } else {
          selected.remove(_selectionKey(selection));
        }
      }
    });
  }

  void _toggleAgent(AgentStatus agent, bool value) {
    setState(() {
      for (final row in rows.where((row) => _isEligible(row, agent))) {
        final selection = _selectionFor(row, agent);
        if (value) {
          selected[_selectionKey(selection)] = selection;
        } else {
          selected.remove(_selectionKey(selection));
        }
      }
    });
  }

  Future<void> _addProject() async {
    final project = await widget.gateway.addProject();
    if (project == null || !mounted) return;
    setState(() {
      final index = projects.indexWhere((item) => item.id == project.id);
      if (index < 0) {
        projects = [...projects, project];
      } else {
        projects[index] = project;
      }
    });
    widget.onProjectAdded(project);
  }

  Future<void> _preflight() async {
    await widget.operation.preflight(
      widget.gateway,
      widget.skill,
      widget.detail.immutableVersion,
      selectedInMatrixOrder,
      riskConfirmed: riskConfirmed,
      allowCritical: widget.riskPolicy.allowCriticalOverride,
    );
    if (mounted) setState(() {});
  }

  Future<void> _execute() async {
    await widget.operation.execute(widget.gateway);
    if (mounted) setState(() {});
  }

  Future<void> _retryFailed() async {
    await widget.operation.retryFailed(widget.gateway, widget.skill);
    if (mounted) setState(() {});
  }

  void _editTargets() {
    widget.operation.editTargets();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final execution = widget.operation.execution;
    final plan = widget.operation.plan;
    final showingProgress =
        widget.operation.operating &&
        widget.operation.progress.isNotEmpty &&
        execution == null;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
      closeIcon: Semantics(
        container: true,
        label: context.l10n.closeInstallationPlan,
        button: true,
        child: ExcludeSemantics(
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ),
      title: Text(
        showingProgress
            ? context.l10n.installationProgressTitle
            : execution != null
            ? context.l10n.installationResults
            : plan != null
            ? context.l10n.reviewInstallationPlan
            : context.l10n.installationPlanTitle,
      ),
      description: Text(
        showingProgress
            ? context.l10n.installationProgressSummary(
                widget.operation.finishedTargetCount,
                plan?.targets.length ?? 0,
              )
            : execution != null
            ? context.l10n.installationResultsDescription
            : plan != null
            ? context.l10n.reviewInstallationPlanDescription
            : context.l10n.installationPlanDescription,
      ),
      actions: _actions(plan, execution),
      child: SizedBox(
        width: 940,
        height: 540,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showingProgress && plan != null
              ? _progress(plan)
              : execution != null
              ? _result(execution)
              : plan != null
              ? _preflightReview(plan)
              : _matrix(),
        ),
      ),
    );
  }

  List<Widget> _actions(
    InstallationPlan? plan,
    InstallationExecution? execution,
  ) {
    if (execution != null) {
      return [
        SkillsButton.outline(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.stayHere),
        ),
        SkillsButton(
          enabled: execution.hasSuccess,
          onPressed: () =>
              Navigator.pop(context, _InstallationPlanOutcome.viewLibrary),
          child: Text(context.l10n.viewInLibrary),
        ),
        if (execution.summary.failed > 0)
          SkillsButton.outline(
            enabled: !widget.operation.operating,
            onPressed: _retryFailed,
            child: widget.operation.operating
                ? SizedBox(
                    width: 32,
                    child: SkillsProgress(
                      minHeight: 4,
                      semanticsLabel: context.l10n.installationInProgress,
                    ),
                  )
                : Text(
                    context.l10n.retryFailedTargets(execution.summary.failed),
                  ),
          ),
      ];
    }
    if (widget.operation.operating && widget.operation.progress.isNotEmpty) {
      return [
        SkillsButton.outline(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.stayHere),
        ),
      ];
    }
    if (plan != null) {
      final unresolved =
          plan.summary.conflict > 0 || plan.summary.blockedByRisk > 0;
      return [
        SkillsButton.outline(
          enabled: !widget.operation.operating,
          onPressed: _editTargets,
          child: Text(context.l10n.backToTargets),
        ),
        SkillsButton(
          enabled:
              !widget.operation.operating && (!unresolved || _canRefresh(plan)),
          onPressed: unresolved ? _preflight : _execute,
          child: widget.operation.operating
              ? SizedBox(
                  width: 32,
                  child: SkillsProgress(
                    minHeight: 4,
                    semanticsLabel: context.l10n.installationInProgress,
                  ),
                )
              : Text(
                  unresolved
                      ? context.l10n.refreshInstallationPlan
                      : context.l10n.installSelectedTargets(
                          plan.targets.length,
                        ),
                ),
        ),
      ];
    }
    return [
      SkillsButton.outline(
        enabled: !widget.operation.operating,
        onPressed: _addProject,
        child: Text(context.l10n.addProject),
      ),
      SkillsButton.outline(
        enabled: !widget.operation.operating,
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      SkillsButton(
        enabled: selected.isNotEmpty && !widget.operation.operating,
        onPressed: _preflight,
        child: widget.operation.operating
            ? SizedBox(
                width: 32,
                child: SkillsProgress(
                  minHeight: 4,
                  semanticsLabel: context.l10n.installationInProgress,
                ),
              )
            : Text(context.l10n.reviewTargets(selected.length)),
      ),
    ];
  }

  Widget _matrix() {
    final width = 210.0 + agents.length * 176.0;
    return Column(
      key: const ValueKey('installation-matrix'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionEyebrow(context.l10n.locationAgentMatrix),
            const Spacer(),
            Text(
              context.l10n.targetsSelected(selected.length),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _matrixHeader(),
                  SkillsSeparator.horizontal(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) => _matrixRow(rows[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.operation.error != null) ...[
          const SizedBox(height: 10),
          _PlanError(error: widget.operation.error!),
        ],
      ],
    );
  }

  Widget _matrixHeader() => SizedBox(
    height: 76,
    child: Row(
      children: [
        SizedBox(
          width: 210,
          child: Text(
            context.l10n.location,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...agents.map((agent) {
          final eligible = rows.where((row) => _isEligible(row, agent));
          final allSelected =
              eligible.isNotEmpty &&
              eligible.every(
                (row) => selected.containsKey(
                  _selectionKey(_selectionFor(row, agent)),
                ),
              );
          return SizedBox(
            width: 176,
            child: Semantics(
              label: context.l10n.selectAgentTargets(agent.displayName),
              checked: allSelected,
              enabled: eligible.isNotEmpty,
              onTap: eligible.isEmpty
                  ? null
                  : () => _toggleAgent(agent, !allSelected),
              excludeSemantics: true,
              child: SkillsCheckbox(
                value: allSelected,
                enabled: eligible.isNotEmpty,
                onChanged: (value) => _toggleAgent(agent, value),
                label: SizedBox(
                  width: 132,
                  child: Text(
                    agent.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );

  Widget _matrixRow(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
  ) {
    final eligible = agents.where((agent) => _isEligible(row, agent));
    final allSelected =
        eligible.isNotEmpty &&
        eligible.every(
          (agent) =>
              selected.containsKey(_selectionKey(_selectionFor(row, agent))),
        );
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: Semantics(
              label: context.l10n.selectLocationTargets(row.label),
              checked: allSelected,
              enabled: eligible.isNotEmpty,
              onTap: eligible.isEmpty
                  ? null
                  : () => _toggleRow(row, !allSelected),
              excludeSemantics: true,
              child: SkillsCheckbox(
                value: allSelected,
                enabled: eligible.isNotEmpty,
                onChanged: (value) => _toggleRow(row, value),
                label: SizedBox(
                  width: 164,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (!row.enabled)
                        Text(
                          context.l10n.projectUnavailable,
                          style: TextStyle(
                            color: context.skillsComponents.statusAttention,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ...agents.map((agent) => _matrixCell(row, agent)),
        ],
      ),
    );
  }

  Widget _matrixCell(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) {
    final selection = _selectionFor(row, agent);
    final key = _selectionKey(selection);
    final installed = _isInstalled(row, agent);
    final eligible = _isEligible(row, agent);
    return SizedBox(
      width: 176,
      child: Center(
        child: installed
            ? StatusChip(
                label: context.l10n.installedCell,
                color: context.skillsComponents.statusSuccess,
              )
            : eligible
            ? Semantics(
                label: context.l10n.selectTarget(row.label, agent.displayName),
                checked: selected.containsKey(key),
                enabled: true,
                onTap: () =>
                    _toggleCell(row, agent, !selected.containsKey(key)),
                excludeSemantics: true,
                child: SkillsCheckbox(
                  value: selected.containsKey(key),
                  onChanged: (value) => _toggleCell(row, agent, value),
                  label: Text(context.l10n.select),
                ),
              )
            : StatusChip(
                label: context.l10n.unsupportedCell,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
              ),
      ),
    );
  }

  Widget _preflightReview(InstallationPlan plan) => Column(
    key: const ValueKey('installation-preflight'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label: context.l10n.planCreateCount(plan.summary.create),
            color: context.skillsComponents.statusSuccess,
          ),
          StatusChip(
            label: context.l10n.planSkipCount(plan.summary.skip),
            color: context.skillsComponents.statusAccent,
          ),
          StatusChip(
            label: context.l10n.planReplaceCount(plan.summary.replace),
            color: context.skillsComponents.statusAttention,
          ),
          StatusChip(
            label: context.l10n.planConflictCount(plan.summary.conflict),
            color: plan.summary.conflict > 0
                ? context.skillsComponents.statusAttention
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
          ),
          StatusChip(
            label: context.l10n.planRiskCount(plan.summary.blockedByRisk),
            color: plan.summary.blockedByRisk > 0
                ? context.skillsComponents.statusDanger
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
          ),
          StatusChip(
            label: plan.version,
            color: context.skillsComponents.statusAccent,
          ),
        ],
      ),
      const SizedBox(height: 14),
      SelectableText(
        plan.coordinate,
        style: TextStyle(
          fontFamily: SkillsTokens.monoFamily,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 14),
      if (plan.summary.blockedByRisk > 0) ...[
        _riskResolution(plan),
        const SizedBox(height: 12),
      ],
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: GlassCard(
                child: ListView.separated(
                  itemCount: plan.targets.length,
                  separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) =>
                      _plannedTarget(plan.targets[index]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionEyebrow(context.l10n.workspaceLockChanges),
                    const SizedBox(height: 10),
                    Expanded(
                      child: plan.workspaceLockChanges.isEmpty
                          ? Text(
                              context.l10n.noWorkspaceLockChanges,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : ListView.separated(
                              itemCount: plan.workspaceLockChanges.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final change = plan.workspaceLockChanges[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      change.projectRoot,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.lockVersionChange(
                                        change.fromVersion.isEmpty
                                            ? context.l10n.notPresent
                                            : change.fromVersion,
                                        change.toVersion,
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontFamily: SkillsTokens.monoFamily,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      if (widget.operation.error != null) ...[
        const SizedBox(height: 10),
        _PlanError(error: widget.operation.error!),
      ],
    ],
  );

  Widget _plannedTarget(InstallationPlanItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _targetLabel(context, item.target),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.target.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                      fontFamily: SkillsTokens.monoFamily,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusChip(
              label: _planActionLabel(context, item.action),
              color: switch (item.action) {
                InstallationPlanAction.create =>
                  context.skillsComponents.statusSuccess,
                InstallationPlanAction.skip =>
                  context.skillsComponents.statusAccent,
                InstallationPlanAction.replace =>
                  context.skillsComponents.statusAttention,
                InstallationPlanAction.conflict ||
                InstallationPlanAction.blockedByRisk =>
                  context.skillsComponents.statusDanger,
              },
            ),
          ],
        ),
        if (item.action == InstallationPlanAction.conflict) ...[
          const SizedBox(height: 8),
          if (item.reasonCode == 'shared-target-conflict')
            SkillsAlert.destructive(
              icon: const Icon(Icons.hub_outlined),
              title: Text(context.l10n.sharedTargetConflict),
              description: Text(
                context.l10n.sharedTargetConflictDescription(
                  item.affectedBindings
                      .map((binding) => binding.agent)
                      .toSet()
                      .join(', '),
                ),
              ),
            )
          else
            SkillsCheckbox(
              value: _selectionMatchesReview(item),
              onChanged: (value) => _setResolution(item, value),
              label: Text(_conflictResolutionLabel(context, item.reasonCode)),
            ),
        ],
      ],
    ),
  );

  InstallationTargetSelection _selectionForTarget(
    InstallationPlanTarget target,
  ) {
    final fallback = InstallationTargetSelection(
      scope: target.scope,
      projectRoot: target.projectRoot,
      agent: target.agent,
      mode: target.mode,
    );
    return selected[_selectionKey(fallback)] ?? fallback;
  }

  bool _selectionMatchesReview(InstallationPlanItem item) {
    final selection = _selectionForTarget(item.target);
    return selection.resolution == InstallationTargetResolution.replace &&
        selection.expectedReason == item.reasonCode &&
        selection.expectedState == item.stateToken;
  }

  void _setResolution(InstallationPlanItem item, bool replace) {
    final current = _selectionForTarget(item.target);
    setState(() {
      selected[_selectionKey(current)] = current.copyWith(
        resolution: replace
            ? InstallationTargetResolution.replace
            : InstallationTargetResolution.none,
        expectedReason: replace ? item.reasonCode : '',
        expectedState: replace ? item.stateToken : '',
      );
    });
  }

  bool _canRefresh(InstallationPlan plan) {
    final conflictsResolved = plan.targets
        .where((item) => item.action == InstallationPlanAction.conflict)
        .every(_selectionMatchesReview);
    if (!conflictsResolved) return false;
    final blocked = plan.targets.where(
      (item) => item.action == InstallationPlanAction.blockedByRisk,
    );
    if (blocked.isEmpty) return true;
    final critical = blocked.any((item) => item.reasonCode == 'critical-risk');
    return riskConfirmed &&
        (!critical || widget.riskPolicy.allowCriticalOverride);
  }

  Widget _riskResolution(InstallationPlan plan) {
    final critical = plan.targets.any(
      (item) =>
          item.action == InstallationPlanAction.blockedByRisk &&
          item.reasonCode == 'critical-risk',
    );
    if (critical && !widget.riskPolicy.allowCriticalOverride) {
      return SkillsAlert.destructive(
        icon: const Icon(Icons.shield_outlined),
        title: Text(context.l10n.criticalRiskBlocked),
        description: Text(context.l10n.criticalRiskOverrideDisabled),
      );
    }
    return SkillsAlert(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(
        critical
            ? context.l10n.confirmCriticalRiskArtifact
            : context.l10n.confirmHighRiskArtifact,
      ),
      description: SkillsCheckbox(
        value: riskConfirmed,
        onChanged: (value) => setState(() => riskConfirmed = value),
        label: Text(context.l10n.confirmRiskForSelectedTargets),
      ),
    );
  }

  Widget _progress(InstallationPlan plan) {
    final progress = {
      for (final event in widget.operation.progress)
        operationTargetKey(event.target): event,
    };
    return Column(
      key: const ValueKey('installation-progress'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillsCard(
          width: double.infinity,
          title: Text(context.l10n.installationProgressTitle),
          description: Text(
            context.l10n.installationProgressSummary(
              widget.operation.finishedTargetCount,
              plan.targets.length,
            ),
          ),
          footer: SkillsProgress(
            value: plan.targets.isEmpty
                ? 0
                : widget.operation.finishedTargetCount / plan.targets.length,
            minHeight: 5,
            semanticsLabel: context.l10n.installationInProgress,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GlassCard(
            child: ListView.separated(
              itemCount: plan.targets.length,
              separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final item = plan.targets[index];
                final event = progress[operationTargetKey(item.target)];
                final finished =
                    event?.state == InstallationProgressState.finished;
                final failed =
                    event?.result?.outcome == InstallationTargetOutcome.failed;
                final label = event == null
                    ? context.l10n.targetWaiting
                    : finished
                    ? _targetOutcomeLabel(context, event.result!.outcome)
                    : context.l10n.targetRunning;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        finished
                            ? failed
                                  ? Icons.error
                                  : Icons.check_circle
                            : Icons.pending_outlined,
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
                        label: label,
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
  }

  Widget _result(InstallationExecution execution) => Column(
    key: const ValueKey('installation-result'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.installationResultSummary(
          execution.summary.succeeded,
          execution.summary.failed,
        ),
        style: const TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        execution.coordinate,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFamily: SkillsTokens.monoFamily,
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: GlassCard(
          child: ListView.separated(
            itemCount: execution.results.length,
            separatorBuilder: (_, _) => SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final result = execution.results[index];
              final success =
                  result.outcome == InstallationTargetOutcome.succeeded ||
                  result.outcome == InstallationTargetOutcome.skipped;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success
                          ? context.skillsComponents.statusSuccess
                          : context.skillsComponents.statusDanger,
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
                          if (result.errorCode.isNotEmpty)
                            Text(
                              _installationErrorLabel(
                                context,
                                result.errorCode,
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: _targetOutcomeLabel(context, result.outcome),
                      color: success
                          ? context.skillsComponents.statusSuccess
                          : context.skillsComponents.statusDanger,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      if (widget.operation.error != null) ...[
        const SizedBox(height: 10),
        _PlanError(error: widget.operation.error!),
      ],
    ],
  );
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final copy = _failureCopy(context, error);
    return SkillsAlert.destructive(
      icon: const Icon(Icons.error_outline),
      title: Text(context.l10n.installationPlanFailed),
      description: Text(copy.message),
    );
  }
}

class _InstallationCompletionBanner extends StatelessWidget {
  const _InstallationCompletionBanner({required this.execution});
  final InstallationExecution execution;

  @override
  Widget build(BuildContext context) => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.installationResults),
    description: Text(
      context.l10n.installationResultSummary(
        execution.summary.succeeded,
        execution.summary.failed,
      ),
    ),
  );
}

String _targetLabel(BuildContext context, InstallationPlanTarget target) {
  final location = target.scope == InstallationScope.user
      ? context.l10n.userScope
      : p.basename(target.projectRoot);
  return '$location / ${target.agent}';
}

String _planActionLabel(BuildContext context, InstallationPlanAction action) =>
    switch (action) {
      InstallationPlanAction.create => context.l10n.planActionCreate,
      InstallationPlanAction.replace => context.l10n.planActionReplace,
      InstallationPlanAction.skip => context.l10n.planActionSkip,
      InstallationPlanAction.conflict => context.l10n.planActionConflict,
      InstallationPlanAction.blockedByRisk =>
        context.l10n.planActionBlockedByRisk,
    };

String _targetOutcomeLabel(
  BuildContext context,
  InstallationTargetOutcome outcome,
) => switch (outcome) {
  InstallationTargetOutcome.succeeded => context.l10n.targetSucceeded,
  InstallationTargetOutcome.skipped => context.l10n.targetSkipped,
  InstallationTargetOutcome.conflict => context.l10n.targetConflict,
  InstallationTargetOutcome.failed => context.l10n.targetFailed,
};

String _installationErrorLabel(BuildContext context, String code) =>
    switch (code) {
      'target-path-exists' => context.l10n.targetPathExists,
      'blocked-by-risk' => context.l10n.targetBlockedByRisk,
      'install-failed' => context.l10n.targetInstallFailed,
      'workspace-update-failed' => context.l10n.targetWorkspaceUpdateFailed,
      _ => context.l10n.installationPlanFailed,
    };

String _conflictResolutionLabel(BuildContext context, String code) =>
    switch (code) {
      'version-conflict' => context.l10n.replaceVersionConflict,
      'identity-collision' => context.l10n.replaceIdentityCollision,
      'local-modification' => context.l10n.replaceLocalModification,
      _ => context.l10n.replaceConflictingTarget,
    };

class _RemoteDetailScreen extends ConsumerStatefulWidget {
  const _RemoteDetailScreen({
    super.key,
    required this.gateway,
    required this.skill,
    required this.operation,
    required this.onBack,
    required this.onViewLibrary,
    this.openPlanOnLoad = false,
  });
  final SkillsGateway gateway;
  final SkillSummary skill;
  final InstallOperationController operation;
  final Future<void> Function({required bool installed}) onBack;
  final VoidCallback onViewLibrary;
  final bool openPlanOnLoad;

  @override
  ConsumerState<_RemoteDetailScreen> createState() =>
      _RemoteDetailScreenState();
}

class _RemoteDetailScreenState extends ConsumerState<_RemoteDetailScreen> {
  final detailScrollController = ScrollController();
  SkillDetail? detail;
  Object? error;
  bool loading = true;
  CliStatus? cliStatus;
  AgentCatalog? agentCatalog;
  List<AddedProject> addedProjects = const [];
  List<SkillSummary> repositorySkills = const [];
  PersonalRiskPolicy riskPolicy = const PersonalRiskPolicy();
  bool didOpenInitialPlan = false;
  bool installationDialogOpen = false;
  bool get operating => widget.operation.operating;
  InstallationExecution? get execution => widget.operation.execution;

  @override
  void initState() {
    super.initState();
    widget.operation.addListener(_operationChanged);
    detailScrollController.addListener(_detailScrollChanged);
    unawaited(load());
  }

  void _detailScrollChanged() {
    if (mounted) setState(() {});
  }

  void _operationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.operation.removeListener(_operationChanged);
    detailScrollController
      ..removeListener(_detailScrollChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final detailRequest = widget.gateway.loadRemoteDetail(widget.skill);
    final cliRequest = widget.gateway.detectCli();
    final projectsRequest = widget.gateway.loadAddedProjects();
    final policyRequest = widget.gateway.loadRiskPolicy();
    try {
      detail = await detailRequest;
    } catch (caught) {
      error = caught;
      if (mounted) setState(() => loading = false);
      return;
    }
    if (!mounted) return;
    setState(() => loading = false);
    try {
      final values = await Future.wait([
        cliRequest,
        projectsRequest,
        policyRequest,
      ]);
      cliStatus = values[0] as CliStatus;
      addedProjects = values[1] as List<AddedProject>;
      riskPolicy = values[2] as PersonalRiskPolicy;
      if (mounted) setState(() {});
      final enrichments = await Future.wait([
        _loadRepositorySkills(widget.gateway, widget.skill, detail!),
        if (cliStatus!.isReady)
          widget.gateway.inspectAgents()
        else
          Future<AgentCatalog?>.value(),
      ]);
      repositorySkills = enrichments[0] as List<SkillSummary>;
      agentCatalog = enrichments[1] as AgentCatalog?;
    } on Object {
      agentCatalog = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> install(InstallLocationMenuPresenter present) async {
    if (agentCatalog == null || detail == null) return;
    final selections = await present(
      InstallLocationMenuRequest(
        gateway: widget.gateway,
        catalog: agentCatalog!,
        detail: detail!,
        projects: addedProjects,
        repositorySkills: repositorySkills,
        onProjectAdded: (project) {
          final index = addedProjects.indexWhere(
            (item) => item.id == project.id,
          );
          if (index < 0) {
            addedProjects = [...addedProjects, project];
          } else {
            addedProjects = [...addedProjects]..[index] = project;
          }
        },
      ),
    );
    if (!mounted || selections == null || selections.selections.isEmpty) return;
    if (selections.action == InstallLocationAction.repositorySkills) {
      await _installRepositorySkills(
        widget.gateway,
        repositorySkills,
        selections.selections,
        riskPolicy,
      );
      if (mounted) setState(() {});
      return;
    }
    widget.operation.editTargets();
    final plan = await widget.operation.preflight(
      widget.gateway,
      widget.skill,
      detail!.immutableVersion,
      selections.selections,
      allowCritical: riskPolicy.allowCriticalOverride,
    );
    if (!mounted) return;
    final requiresReview =
        plan == null ||
        plan.summary.conflict > 0 ||
        plan.summary.blockedByRisk > 0;
    if (!requiresReview) {
      final result = await widget.operation.execute(widget.gateway);
      if (!mounted) return;
      if (result != null &&
          result.summary.failed == 0 &&
          result.summary.conflict == 0) {
        ref.invalidate(libraryProvider);
        setState(() {});
        return;
      }
    }
    setState(() => installationDialogOpen = true);
    final outcome = await showSkillsDialog<_InstallationPlanOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InstallationPlanDialog(
        gateway: widget.gateway,
        skill: widget.skill,
        detail: detail!,
        catalog: agentCatalog!,
        initialProjects: addedProjects,
        operation: widget.operation,
        riskPolicy: riskPolicy,
        onProjectAdded: (project) {},
      ),
    );
    if (mounted) setState(() => installationDialogOpen = false);
    if (outcome == _InstallationPlanOutcome.viewLibrary && mounted) {
      widget.onViewLibrary();
    } else if (mounted) {
      if (widget.operation.execution?.hasSuccess == true) {
        ref.invalidate(libraryProvider);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          widget.onBack(installed: execution?.hasSuccess == true),
      const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () =>
          widget.onBack(installed: execution?.hasSuccess == true),
    },
    child: Focus(
      autofocus: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _content(),
            Align(alignment: Alignment.topCenter, child: _detailToolbar()),
          ],
        ),
      ),
    ),
  );

  Widget _detailToolbar() {
    final scheme = Theme.of(context).colorScheme;
    final offset = detailScrollController.hasClients
        ? detailScrollController.offset
        : 0.0;
    final materialProgress = ((offset - 12) / 52).clamp(0.0, 1.0);
    final compactProgress = ((offset - 72) / 56).clamp(0.0, 1.0);
    final value = detail;
    return SizedBox(
      key: const Key('detail-sticky-toolbar'),
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, .04, .96, 1],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0, .16, .68, 1],
                ).createShader(bounds),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 22 * materialProgress,
                    sigmaY: 22 * materialProgress,
                  ),
                  child: ColoredBox(
                    color: scheme.surface.withValues(
                      alpha: .62 * materialProgress,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Semantics(
                  label: context.l10n.backToSearch,
                  button: true,
                  child: Material(
                    color: scheme.surfaceContainerHigh.withValues(alpha: .82),
                    elevation: 3,
                    shadowColor: scheme.shadow.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      key: const Key('detail-back'),
                      onPressed: () => widget.onBack(
                        installed: execution?.hasSuccess == true,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        fixedSize: const Size.square(40),
                        minimumSize: const Size.square(40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedLessThan,
                        size: 20,
                        strokeWidth: 1.8,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (value != null && compactProgress > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      key: const Key('detail-compact-identity'),
                      opacity: compactProgress,
                      child: IgnorePointer(
                        ignoring: compactProgress < .95,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RepositoryAvatar(
                              source: value.source,
                              imageUrl: value.imageUrl,
                              size: 26,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (value != null && compactProgress > 0)
                  Opacity(
                    key: const Key('detail-compact-install'),
                    opacity: compactProgress,
                    child: IgnorePointer(
                      ignoring: compactProgress < .95,
                      child: InstallLocationMenuAnchor(
                        builder: (context, present) => PrimaryCapsuleButton(
                          label: context.l10n.install,
                          height: 36,
                          horizontalPadding: 16,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w400,
                          ),
                          onPressed:
                              agentCatalog == null ||
                                  agentCatalog!.installed.isEmpty
                              ? null
                              : () => install(present),
                          busy: operating,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (loading) {
      return _detailSkeleton();
    }
    if (error != null) {
      final copy = _failureCopy(context, error!, detail: true);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: SkillsButton(onPressed: load, child: Text(context.l10n.retry)),
      );
    }
    return _detailBody();
  }

  Widget _detailSkeleton() => Semantics(
    liveRegion: true,
    label: context.l10n.detailLoading,
    child: SingleChildScrollView(
      key: const ValueKey('detail-skeleton'),
      padding: const EdgeInsets.only(top: 76, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepositoryAvatar(
                source: widget.skill.source,
                imageUrl: widget.skill.imageUrl,
                size: 116,
                borderRadius: 24,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.skill.source,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SkillsSkeletonBox(height: 12, width: 280),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const SkillsSkeletonBox(height: 18, width: 190),
          const SizedBox(height: 16),
          const SkillsSkeletonBox(height: 13),
          const SizedBox(height: 10),
          const SkillsSkeletonBox(height: 13),
          const SizedBox(height: 10),
          const SkillsSkeletonBox(height: 13, width: 520),
          const SizedBox(height: 28),
          const SkillsSkeletonBox(height: 220, borderRadius: 14),
        ],
      ),
    ),
  );

  Widget _detailBody() {
    final value = detail!;
    return SingleChildScrollView(
      key: const Key('detail-scroll-view'),
      controller: detailScrollController,
      padding: const EdgeInsets.only(top: 76, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepositoryAvatar(
                key: const Key('detail-skill-avatar'),
                source: value.source,
                imageUrl: value.imageUrl,
                size: 116,
                borderRadius: 24,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 112),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: SkillsTokens.sansFamily,
                                  fontSize: 30,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            InstallLocationMenuAnchor(
                              builder: (context, present) =>
                                  PrimaryCapsuleButton(
                                    key: const Key('detail-hero-install'),
                                    label: context.l10n.install,
                                    height: 40,
                                    horizontalPadding: 18,
                                    labelStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    onPressed:
                                        agentCatalog == null ||
                                            agentCatalog!.installed.isEmpty
                                        ? null
                                        : () => install(present),
                                    busy: operating,
                                  ),
                            ),
                          ],
                        ),
                        if (value.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SkillMarkdownView(
                            key: const Key('detail-description-markdown'),
                            data: value.description.trim(),
                            scrollable: false,
                            maxHeight: 68,
                            presentation: SkillMarkdownPresentation.summary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _detailProductMetadata(value),
          if (value.hasExecutableContent || value.riskEvidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RiskNotice(detail: value),
          ],
          if (value.installationTargets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    context.l10n.knownInstallationTargets,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: value.installationTargets
                        .map(
                          (target) => StatusChip(
                            label: context.l10n.targetSummary(
                              switch (target.scope) {
                                InstallationScope.user =>
                                  context.l10n.userScope,
                                InstallationScope.project =>
                                  context.l10n.projectScope,
                              },
                              target.agent,
                              target.version,
                            ),
                            color: context.skillsComponents.statusSuccess,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ],
          if (agentCatalog != null && agentCatalog!.installed.isEmpty) ...[
            const SizedBox(height: 12),
            SkillsCard(
              width: double.infinity,
              title: Text(context.l10n.noInstalledAgentsTitle),
              description: Text(context.l10n.noInstalledAgentsMessage),
            ),
          ],
          if (operating &&
              widget.operation.progress.isNotEmpty &&
              execution == null) ...[
            const SizedBox(height: 14),
            SkillsCard(
              width: double.infinity,
              title: Text(context.l10n.installationProgressTitle),
              description: Text(
                context.l10n.installationProgressSummary(
                  widget.operation.finishedTargetCount,
                  widget.operation.plan?.targets.length ?? 0,
                ),
              ),
              footer: SkillsProgress(
                minHeight: 5,
                semanticsLabel: context.l10n.installationInProgress,
              ),
            ),
          ],
          if (execution != null && !installationDialogOpen) ...[
            const SizedBox(height: 14),
            _InstallationCompletionBanner(execution: execution!),
          ],
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SkillMarkdownView(
                key: const Key('detail-instructions'),
                data: value.markdown,
                scrollable: false,
                stripFrontMatter: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailProductMetadata(SkillDetail value) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        label: context.l10n.detailInstalls,
        value: _compactCount(value.installs),
      ),
      (
        label: context.l10n.detailRepository,
        value: _repositoryDisplayName(
          value.repository.isEmpty ? value.source : value.repository,
        ),
      ),
      (
        label: context.l10n.detailGitHubStars,
        value: _compactCount(value.githubStars),
      ),
      (
        label: context.l10n.detailUpdated,
        value: _shortDate(value.sourceUpdatedAt),
      ),
      (
        label: context.l10n.detailArchiveSize,
        value: _fileSize(value.archiveSize),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
      ),
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0)
                SizedBox(
                  height: 48,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: scheme.outlineVariant.withValues(alpha: .55),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 18,
                        width: double.infinity,
                        child: Center(
                          child: Text(
                            items[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 24,
                        width: double.infinity,
                        child: Center(
                          child: Tooltip(
                            message: index == 1 ? items[index].value : '',
                            child: Text(
                              items[index].value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: switch (index) {
                                  1 => 12,
                                  3 => 16,
                                  _ => 18,
                                },
                                height: 1,
                                fontWeight: index == 1
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _repositoryDisplayName(String repository) {
    final firstSeparator = repository.indexOf('/');
    if (firstSeparator <= 0) {
      return repository;
    }
    final firstSegment = repository.substring(0, firstSeparator);
    return firstSegment.contains('.')
        ? repository.substring(firstSeparator + 1)
        : repository;
  }

  String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _shortDate(DateTime? value) {
    if (value == null || value.year <= 1) return '—';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _fileSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(bytes >= 10240 ? 0 : 1)} KB';
  }
}

class _RiskNotice extends StatelessWidget {
  const _RiskNotice({required this.detail});
  final SkillDetail detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.skillsComponents.statusAttention.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: context.skillsComponents.statusAttention.withValues(alpha: .35),
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: context.skillsComponents.statusAttention,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.executableRisk,
                style: TextStyle(
                  color: context.skillsComponents.statusAttention,
                ),
              ),
              if (detail.riskEvidence.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  context.l10n.riskEvidence(
                    detail.riskEvidence
                        .map((evidence) => evidence.path)
                        .join(', '),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: SkillsTokens.monoFamily,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _TargetManagementDialog extends ConsumerStatefulWidget {
  const _TargetManagementDialog({required this.gateway, required this.plan});

  final SkillsGateway gateway;
  final TargetManagementPlan plan;

  @override
  ConsumerState<_TargetManagementDialog> createState() =>
      _TargetManagementDialogState();
}

class _TargetManagementDialogState
    extends ConsumerState<_TargetManagementDialog> {
  final selectedActions = <String, TargetManagementAction>{};

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
        if (action == TargetManagementAction.repair) {
          for (final binding in item.affectedBindings) {
            selectedActions.remove(updateTargetKey(binding));
          }
        }
        return;
      }
      final bindings = action == TargetManagementAction.repair
          ? item.affectedBindings
          : const <InstallationPlanTarget>[];
      if (bindings.isEmpty) {
        selectedActions[key] = action;
      } else {
        for (final binding in bindings) {
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
    final destructive = selectedActions.values.any(
      (action) => action != TargetManagementAction.repair,
    );
    if (destructive) {
      return SkillsButton.destructive(
        enabled: enabled,
        onPressed: _execute,
        child: child,
      );
    }
    return SkillsButton(enabled: enabled, onPressed: _execute, child: child);
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
      (item) =>
          item.workspaceMetadataChange &&
          item.action != TargetManagementAction.repair,
    );
    final preservesContent = plan.targets.any(
      (item) => item.action == TargetManagementAction.stopManaging,
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
            _failureCopy(context, error!).message,
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
                final removable =
                    item.allowedActions.length == 1 &&
                    item.allowedActions.single == TargetManagementAction.remove;
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
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFamily: SkillsTokens.monoFamily,
                                fontSize: 11,
                              ),
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
                            if (item.allowedActions.contains(
                              TargetManagementAction.stopManaging,
                            )) ...[
                              const SizedBox(height: 3),
                              Text(
                                context.l10n.stopManagingDescription,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _installationHealthChip(context, item.health),
                      const SizedBox(width: 10),
                      if (removable)
                        SkillsCheckbox(
                          value: selected == TargetManagementAction.remove,
                          enabled: !operating,
                          onChanged: (_) => _selectAction(
                            item,
                            TargetManagementAction.remove,
                          ),
                          label: Text(context.l10n.remove),
                        )
                      else
                        Wrap(
                          spacing: 7,
                          children: [
                            if (item.allowedActions.contains(
                              TargetManagementAction.repair,
                            ))
                              SkillsButton.outline(
                                size: SkillsButtonSize.sm,
                                enabled: !operating,
                                backgroundColor:
                                    selected == TargetManagementAction.repair
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer
                                    : null,
                                onPressed: () => _selectAction(
                                  item,
                                  TargetManagementAction.repair,
                                ),
                                child: Text(context.l10n.repairTarget),
                              ),
                            if (item.allowedActions.contains(
                              TargetManagementAction.stopManaging,
                            ))
                              SkillsButton.outline(
                                size: SkillsButtonSize.sm,
                                enabled: !operating,
                                backgroundColor:
                                    selected ==
                                        TargetManagementAction.stopManaging
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer
                                    : null,
                                onPressed: () => _selectAction(
                                  item,
                                  TargetManagementAction.stopManaging,
                                ),
                                child: Text(context.l10n.stopManaging),
                              ),
                          ],
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
        if (preservesContent) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.targetContentPreserved,
            style: TextStyle(
              color: context.skillsComponents.statusSuccess,
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
                    if (result.diagnostic.isNotEmpty)
                      Text(
                        result.diagnostic,
                        style: TextStyle(
                          color: context.skillsComponents.statusDanger,
                        ),
                      ),
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
  TargetManagementAction.repair => context.l10n.repairTarget,
  TargetManagementAction.stopManaging => context.l10n.stopManaging,
};

class _UpdatePlanDialog extends ConsumerStatefulWidget {
  const _UpdatePlanDialog({
    required this.gateway,
    required this.skill,
    required this.plan,
  });

  final SkillsGateway gateway;
  final InstalledSkill skill;
  final UpdatePlan plan;

  @override
  ConsumerState<_UpdatePlanDialog> createState() => _UpdatePlanDialogState();
}

class _UpdatePlanDialogState extends ConsumerState<_UpdatePlanDialog> {
  late final Set<String> selected = {
    for (final item in widget.plan.targets)
      if (item.action == UpdatePlanAction.update) updateTargetKey(item.target),
  };
  UpdateOperationState get operation =>
      ref.read(updateOperationProvider(widget.skill.identity));

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
        .read(updateOperationProvider(widget.skill.identity).notifier)
        .execute(plan);
  }

  Future<void> _retryFailed() => ref
      .read(updateOperationProvider(widget.skill.identity).notifier)
      .retryFailed(widget.skill);

  @override
  Widget build(BuildContext context) {
    ref.watch(updateOperationProvider(widget.skill.identity));
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
            _failureCopy(context, error!).message,
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
        if (selectedPlan.workspaceLockChanges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.workspaceLockChanges,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final change in selectedPlan.workspaceLockChanges)
            Text(
              '${change.path}: ${change.fromVersion} → ${change.toVersion}',
              style: TextStyle(
                fontFamily: SkillsTokens.monoFamily,
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                    Icon(
                      finished
                          ? failed
                                ? Icons.error
                                : Icons.check_circle
                          : Icons.pending_outlined,
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
          _failureCopy(context, error!).message,
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
                    Icon(
                      failed ? Icons.error : Icons.check_circle,
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
                          if (result.diagnostic.isNotEmpty)
                            Text(
                              result.diagnostic,
                              style: TextStyle(
                                color: context.skillsComponents.statusDanger,
                              ),
                            ),
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
    item.reasonCode == 'workspace-lock-reconcile'
    ? context.l10n.reconcileWorkspaceLockTarget
    : switch (item.action) {
        UpdatePlanAction.update => context.l10n.updateVersionChange(
          item.fromVersion,
          item.toVersion,
        ),
        UpdatePlanAction.current => context.l10n.currentVersionTarget,
        UpdatePlanAction.pinned => context.l10n.fixedVersionTarget,
        UpdatePlanAction.failed => context.l10n.updateCheckTargetFailed,
      };
