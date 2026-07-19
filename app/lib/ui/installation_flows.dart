/*
 * [INPUT]: Depends on the app_shell library for gateway contracts, HugeIcons, Riverpod installation operations, localized UI components, and shared navigation callbacks.
 * [OUTPUT]: Provides remote Skill detail plus direct confirmed Installation, Update, Remove/Repair, risk, progress, result, and retry flows without a second target matrix.
 * [POS]: Serves as the complete mutation-flow view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

Widget _targetFailureDetails(BuildContext context, TargetFailure failure) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(switch (failure.code) {
        'installation.target_failed' =>
          context.l10n.installationTargetFailureMessage,
        'workspace.persistence_failed' =>
          context.l10n.workspacePersistenceFailureMessage,
        'installation.state_changed' =>
          context.l10n.installationStateChangedMessage,
        'update.target_failed' => context.l10n.updateTargetFailureMessage,
        'management.target_failed' =>
          context.l10n.managementTargetFailureMessage,
        _ =>
          failure.retryable
              ? context.l10n.targetFailureRetryable
              : context.l10n.targetFailureNeedsAttention,
      }, style: TextStyle(color: context.skillsComponents.statusDanger)),
      if (failure.diagnostic.isNotEmpty)
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              context.l10n.technicalDetails,
              style: context.skillsTypography.metadata,
            ),
            children: [
              SelectableText(
                failure.diagnostic,
                style: context.skillsTypography.caption.copyWith(
                  color: context.skillsComponents.statusDanger,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

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
    await gateway.installTargets(
      skill,
      detail.immutableVersion,
      selections,
      confirmRisk: true,
      allowCritical: riskPolicy.allowCriticalOverride,
    );
  }
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final copy = _failureCopy(context, error);
    return SkillsAlert.destructive(
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedAlertCircle,
        strokeWidth: 1.8,
      ),
      title: Text(context.l10n.installationFailed),
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

const _skillDetailSectionGap = 24.0;
const _skillDetailDocumentGap = 24.0;

Widget _skillDetailDivider(BuildContext context) => SkillsSeparator.horizontal(
  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
);

class _SkillDetailHero extends StatelessWidget {
  const _SkillDetailHero({
    required this.name,
    required this.source,
    required this.description,
    required this.actions,
    this.imageUrl,
    this.avatarKey,
    this.descriptionKey,
  });

  final String name;
  final String source;
  final String description;
  final String? imageUrl;
  final Key? avatarKey;
  final Key? descriptionKey;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RepositoryAvatar(
        key: avatarKey,
        source: source,
        imageUrl: imageUrl,
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.skillsTypography.display,
                      ),
                    ),
                    const SizedBox(width: 24),
                    actions,
                  ],
                ),
                const SizedBox(height: 8),
                if (description.trim().isNotEmpty)
                  Text(
                    description.trim(),
                    key: descriptionKey,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.skillsTypography.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.42,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _SkillDetailPageBody extends StatelessWidget {
  const _SkillDetailPageBody({
    required this.scrollKey,
    required this.hero,
    required this.contextArea,
    required this.document,
    this.controller,
  });

  final Key scrollKey;
  final ScrollController? controller;
  final Widget hero;
  final Widget contextArea;
  final Widget document;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: scrollKey,
    controller: controller,
    padding: const EdgeInsets.only(top: 76, bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const SizedBox(height: _skillDetailSectionGap),
        _skillDetailDivider(context),
        contextArea,
        _skillDetailDivider(context),
        const SizedBox(height: _skillDetailDocumentGap),
        document,
      ],
    ),
  );
}

class _InstallationScopePanel extends StatefulWidget {
  const _InstallationScopePanel({
    required this.targets,
    this.projects = const [],
    this.onManageTarget,
  });

  final List<SkillInstallationTarget> targets;
  final List<AddedProject> projects;
  final Future<void> Function(
    SkillInstallationTarget target,
    TargetManagementAction action,
  )?
  onManageTarget;

  @override
  State<_InstallationScopePanel> createState() =>
      _InstallationScopePanelState();
}

class _InstallationScopePanelState extends State<_InstallationScopePanel> {
  final expandedGroups = <String>{};

  List<_InstalledTargetGroup> get groups {
    final values = <String, List<SkillInstallationTarget>>{};
    for (final target in widget.targets) {
      final key = target.scope == InstallationScope.user
          ? 'user'
          : 'project:${target.projectRoot}';
      values.putIfAbsent(key, () => []).add(target);
    }
    return [
      for (final entry in values.entries)
        _InstalledTargetGroup(key: entry.key, targets: entry.value),
    ];
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('installation-scope-panel'),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, group) in groups.indexed) ...[
            if (index > 0)
              LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: EdgeInsets.only(
                    left: 36,
                    right: constraints.maxWidth < 760 ? 12 : 18,
                  ),
                  child: SkillsSeparator.horizontal(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .32),
                  ),
                ),
              ),
            _group(context, group),
          ],
        ],
      ),
    ),
  );

  Widget _group(BuildContext context, _InstalledTargetGroup group) {
    final abnormal = group.targets.any(
      (target) => target.health != InstallationHealth.healthy,
    );
    final expanded = expandedGroups.contains(group.key);
    final agents = {for (final target in group.targets) target.agent}.toList()
      ..sort();
    final versions =
        group.targets
            .map((target) => target.version)
            .where((version) => version.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final first = group.targets.first;
    final label = first.scope == InstallationScope.user
        ? context.l10n.userScope
        : p.basename(first.projectRoot);
    AddedProject? project;
    if (first.scope == InstallationScope.project) {
      for (final candidate in widget.projects) {
        if (candidate.path == first.projectRoot) {
          project = candidate;
          break;
        }
      }
      project ??= AddedProject(
        id: first.projectRoot,
        name: label,
        path: first.projectRoot,
        accessState: ProjectAccessState.accessible,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: expanded
                ? context.l10n.hideTargetDetails
                : context.l10n.targetDetails,
            child: Semantics(
              button: true,
              expanded: expanded,
              label: label,
              child: InkWell(
                key: ValueKey('installation-scope-toggle-${group.key}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  if (!expandedGroups.add(group.key)) {
                    expandedGroups.remove(group.key);
                  }
                }),
                child: SizedBox(
                  height: 48,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final tight = constraints.maxWidth < 560;
                      final agentsMaxWidth = tight
                          ? 54.0
                          : compact
                          ? 96.0
                          : 168.0;
                      final trailingInset = compact ? 12.0 : 18.0;
                      return Row(
                        children: [
                          if (project != null)
                            ProjectIdentityIcon(project: project, size: 26)
                          else
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.skillsColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(26 * .24),
                                border: Border.all(
                                  color: context.skillsColors.borderMuted,
                                ),
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedUser,
                                size: 16,
                                strokeWidth: 1.6,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.skillsTypography.body,
                            ),
                          ),
                          const SizedBox(width: 14),
                          _InstallationAgentStrip(
                            agents: agents,
                            maxWidth: agentsMaxWidth,
                          ),
                          const SizedBox(width: 14),
                          if (versions.isNotEmpty)
                            Text(
                              versions.length == 1
                                  ? versions.single
                                  : context.l10n.versionDivergence,
                              maxLines: 1,
                              style: context.skillsTypography.caption.copyWith(
                                color: versions.length == 1
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : context.skillsComponents.statusAttention,
                              ),
                            ),
                          if (abnormal) ...[
                            const SizedBox(width: 8),
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedAlert02,
                              size: 15,
                              strokeWidth: 1.6,
                              color: context.skillsComponents.statusDangerSolid,
                            ),
                          ],
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: expanded ? .5 : 0,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowDown01,
                              size: 14,
                              strokeWidth: 1.45,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: trailingInset),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            alignment: Alignment.topLeft,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 36, top: 6),
                    child: Column(
                      children: [
                        for (final target in group.targets)
                          _InstallationTargetDetail(
                            target: target,
                            onRepair: widget.onManageTarget == null
                                ? null
                                : () => widget.onManageTarget!(
                                    target,
                                    TargetManagementAction.repair,
                                  ),
                            onRemove: widget.onManageTarget == null
                                ? null
                                : () => widget.onManageTarget!(
                                    target,
                                    TargetManagementAction.remove,
                                  ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _InstallationAgentStrip extends StatelessWidget {
  const _InstallationAgentStrip({required this.agents, this.maxWidth = 168});
  final List<String> agents;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const slot = 24.0;
        final capacity = (constraints.maxWidth / slot).floor().clamp(1, 7);
        final hidden = agents.length > capacity
            ? agents.length - capacity + 1
            : 0;
        final visibleCount = hidden > 0 ? capacity - 1 : agents.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final agent in agents.take(visibleCount)) ...[
              Tooltip(
                message: _agentDisplayLabel(agent),
                child: AgentLogo(
                  agentId: agent,
                  displayName: _agentDisplayLabel(agent),
                  size: 18,
                ),
              ),
              if (agent != agents.take(visibleCount).last)
                const SizedBox(width: 6),
            ],
            if (hidden > 0) ...[
              if (visibleCount > 0) const SizedBox(width: 6),
              Text('×$hidden', style: context.skillsTypography.caption),
            ],
          ],
        );
      },
    ),
  );
}

class _InstalledTargetGroup {
  const _InstalledTargetGroup({required this.key, required this.targets});
  final String key;
  final List<SkillInstallationTarget> targets;
}

Future<TargetManagementExecution> _executeInlineTargetAction({
  required SkillsGateway gateway,
  required InstalledSkill skill,
  required SkillInstallationTarget target,
  required TargetManagementAction action,
}) async {
  final plan = await gateway.preflightTargetManagement(skill, [target]);
  final matching = plan.targets.where(
    (item) =>
        item.target.path == target.path &&
        item.target.agent == target.agent &&
        item.allowedActions.contains(action),
  );
  if (matching.isEmpty) {
    throw StateError('The selected target action is unavailable.');
  }
  final item = matching.first;
  final actions = <String, TargetManagementAction>{
    updateTargetKey(item.target): action,
    if (action == TargetManagementAction.repair)
      for (final binding in item.affectedBindings)
        updateTargetKey(binding): action,
  };
  final execution = await gateway.executeTargetManagement(
    plan.selectActions(actions),
  );
  if (execution.summary.failed > 0) {
    throw StateError('The selected target action failed.');
  }
  return execution;
}

class _InstallationTargetDetail extends StatefulWidget {
  const _InstallationTargetDetail({
    required this.target,
    this.onRepair,
    this.onRemove,
  });
  final SkillInstallationTarget target;
  final Future<void> Function()? onRepair;
  final Future<void> Function()? onRemove;

  @override
  State<_InstallationTargetDetail> createState() =>
      _InstallationTargetDetailState();
}

class _InstallationTargetDetailState extends State<_InstallationTargetDetail> {
  bool confirmingRemoval = false;
  bool operating = false;
  Object? actionError;

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null || operating) return;
    setState(() {
      operating = true;
      actionError = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => actionError = error);
    } finally {
      if (mounted) {
        setState(() {
          operating = false;
          confirmingRemoval = false;
        });
      }
    }
  }

  Widget _actionButton(
    BuildContext context, {
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    bool danger = false,
    bool busy = false,
  }) {
    final color = danger
        ? context.skillsComponents.statusDangerSolid
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return TextButton(
      key: key,
      onPressed: busy ? null : onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 26)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 7),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStatePropertyAll(color),
        overlayColor: WidgetStatePropertyAll(color.withValues(alpha: .07)),
        textStyle: WidgetStatePropertyAll(context.skillsTypography.metadata),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
      child: busy
          ? SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 1.3, color: color),
            )
          : Text(label),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: AgentLogo(
                agentId: widget.target.agent,
                displayName: _agentDisplayLabel(widget.target.agent),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    _agentDisplayLabel(widget.target.agent),
                    style: context.skillsTypography.bodySecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tooltip(
                      message: widget.target.path,
                      child: Text(
                        widget.target.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.skillsTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (widget.target.health != InstallationHealth.healthy) ...[
              _installationHealthChip(context, widget.target.health),
              const SizedBox(width: 7),
            ],
            if (widget.target.health == InstallationHealth.healthy &&
                widget.onRemove != null) ...[
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    alignment: Alignment.centerRight,
                    child: child,
                  ),
                ),
                child: confirmingRemoval
                    ? Row(
                        key: const ValueKey('confirm-removal-actions'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(
                            context,
                            label: context.l10n.cancel,
                            onPressed: () =>
                                setState(() => confirmingRemoval = false),
                          ),
                          const SizedBox(width: 2),
                          _actionButton(
                            context,
                            key: ValueKey(
                              'confirm-remove-installation-target-${widget.target.path}',
                            ),
                            label: context.l10n.confirmRemoveTarget,
                            onPressed: () => _run(widget.onRemove),
                            danger: true,
                            busy: operating,
                          ),
                        ],
                      )
                    : _actionButton(
                        context,
                        key: ValueKey(
                          'remove-installation-target-${widget.target.path}',
                        ),
                        label: context.l10n.remove,
                        onPressed: () =>
                            setState(() => confirmingRemoval = true),
                        danger: true,
                      ),
              ),
            ] else if (widget.onRepair != null) ...[
              const SizedBox(width: 6),
              _actionButton(
                context,
                key: ValueKey(
                  'repair-installation-target-${widget.target.path}',
                ),
                label: context.l10n.repairTarget,
                onPressed: () => _run(widget.onRepair),
                busy: operating,
              ),
            ],
            const SizedBox(width: 18),
          ],
        ),
        if (actionError != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4, right: 18),
            child: Text(
              _failureCopy(context, actionError!).message,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.skillsComponents.statusDanger,
                fontSize: 11,
              ),
            ),
          ),
      ],
    ),
  );
}

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
  bool loadingCatalog = false;
  bool managingTarget = false;
  CliStatus? cliStatus;
  List<AddedProject> addedProjects = const [];
  List<SkillSummary> repositorySkills = const [];
  PersonalRiskPolicy riskPolicy = const PersonalRiskPolicy();
  bool didOpenInitialPlan = false;
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
      repositorySkills = await _loadRepositorySkills(
        widget.gateway,
        widget.skill,
        detail!,
      );
    } on Object {
      repositorySkills = [widget.skill];
    }
    if (mounted) setState(() {});
  }

  Future<void> install(InstallLocationMenuPresenter present) async {
    if (detail == null || loadingCatalog) return;
    setState(() => loadingCatalog = true);
    try {
      final catalog = await ref
          .read(agentCatalogProvider.notifier)
          .ensureLoaded();
      if (!mounted) return;
      await present(
        InstallLocationMenuRequest(
          gateway: widget.gateway,
          catalog: catalog,
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
        (choice) async {
          try {
            if (choice.action == InstallLocationAction.repositorySkills) {
              await _installRepositorySkills(
                widget.gateway,
                repositorySkills,
                choice.selections,
                riskPolicy,
              );
            } else {
              final result = await widget.operation.installTargets(
                widget.gateway,
                widget.skill,
                detail!.immutableVersion,
                choice.selections,
                confirmRisk: true,
                allowCritical: riskPolicy.allowCriticalOverride,
              );
              if (result == null || widget.operation.error != null) {
                if (!mounted) {
                  return const InstallLocationSubmission.success();
                }
                final copy = _failureCopy(
                  context,
                  widget.operation.error ?? StateError('Installation failed.'),
                );
                return InstallLocationSubmission.failure(
                  title: context.l10n.installationFailed,
                  message: copy.message,
                );
              }
            }
            if (mounted) {
              ref.invalidate(libraryProvider);
              unawaited(
                ref.read(agentCatalogProvider.notifier).refreshSilently(),
              );
              setState(() {});
            }
            return const InstallLocationSubmission.success();
          } on Object catch (error) {
            if (!mounted) {
              return const InstallLocationSubmission.success();
            }
            final copy = _failureCopy(context, error);
            return InstallLocationSubmission.failure(
              title: context.l10n.installationFailed,
              message: copy.message,
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => loadingCatalog = false);
    }
  }

  Future<void> manageTargetInline(
    SkillInstallationTarget target,
    TargetManagementAction action,
  ) async {
    if (managingTarget) return;
    setState(() => managingTarget = true);
    try {
      final projects = await widget.gateway.loadAddedProjects();
      final entries = await widget.gateway.listInstalled(projects: projects);
      final matching = entries.where(
        (entry) =>
            entry.targets.any(
              (candidate) =>
                  candidate.path == target.path &&
                  candidate.agent == target.agent,
            ) ||
            (entry.skillId.isNotEmpty && entry.skillId == widget.skill.id),
      );
      if (matching.isEmpty) {
        throw StateError('The installed Skill is no longer available.');
      }
      await _executeInlineTargetAction(
        gateway: widget.gateway,
        skill: matching.first,
        target: target,
        action: action,
      );
      unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
      ref.invalidate(libraryProvider);
      final refreshed = await widget.gateway.loadRemoteDetail(widget.skill);
      if (!mounted) return;
      setState(() {
        detail = refreshed;
        addedProjects = projects;
      });
    } finally {
      if (mounted) setState(() => managingTarget = false);
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
                          label: _installActionLabel(value),
                          height: 36,
                          horizontalPadding: 16,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w400,
                          ),
                          onPressed: () => install(present),
                          busy: operating || loadingCatalog,
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
    return _SkillDetailPageBody(
      scrollKey: const Key('detail-scroll-view'),
      controller: detailScrollController,
      hero: _SkillDetailHero(
        name: value.name,
        source: value.source,
        description: value.description,
        imageUrl: value.imageUrl,
        avatarKey: const Key('detail-skill-avatar'),
        descriptionKey: const Key('detail-description-markdown'),
        actions: InstallLocationMenuAnchor(
          builder: (context, present) => PrimaryCapsuleButton(
            key: const Key('detail-hero-install'),
            label: _installActionLabel(value),
            height: 40,
            horizontalPadding: 18,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            onPressed: () => install(present),
            busy: operating || loadingCatalog,
          ),
        ),
      ),
      contextArea: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailProductMetadata(value),
          if (value.installationTargets.isNotEmpty) ...[
            _skillDetailDivider(context),
            _InstallationScopePanel(
              targets: value.installationTargets,
              projects: addedProjects,
              onManageTarget: manageTargetInline,
            ),
          ],
          if (widget.operation.error != null) ...[
            const SizedBox(height: 14),
            _PlanError(error: widget.operation.error!),
          ],
          if (execution != null) ...[
            const SizedBox(height: 14),
            _InstallationCompletionBanner(execution: execution!),
          ],
        ],
      ),
      document: SkillMarkdownView(
        key: const Key('detail-instructions'),
        data: value.markdown,
        scrollable: false,
        stripFrontMatter: true,
      ),
    );
  }

  String _installActionLabel(SkillDetail value) =>
      value.installationTargets.isNotEmpty || execution?.hasSuccess == true
      ? context.l10n.installMoreTargets
      : context.l10n.install;

  Widget _detailProductMetadata(SkillDetail value) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        label: context.l10n.detailRepository,
        value: _repositoryDisplayName(
          value.repository.isEmpty ? value.source : value.repository,
        ),
      ),
      (label: context.l10n.detailStars, value: _compactCount(value.stars)),
      (
        label: context.l10n.detailInstalls,
        value: _compactCount(value.installs),
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
    return SizedBox(
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
                          style: context.skillsTypography.metadata.copyWith(
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
                          message: index == 0 ? items[index].value : '',
                          child: Text(
                            items[index].value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: context.skillsTypography.bodySecondary
                                .copyWith(
                                  fontSize: switch (index) {
                                    0 => 12,
                                    3 => 15,
                                    _ => 16,
                                  },
                                  height: 1,
                                  fontWeight: FontWeight.w400,
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

class _TargetManagementDialog extends ConsumerStatefulWidget {
  const _TargetManagementDialog({
    required this.gateway,
    required this.plan,
    this.initialAction,
  });

  final SkillsGateway gateway;
  final TargetManagementPlan plan;
  final TargetManagementAction? initialAction;

  @override
  ConsumerState<_TargetManagementDialog> createState() =>
      _TargetManagementDialogState();
}

class _TargetManagementDialogState
    extends ConsumerState<_TargetManagementDialog> {
  final selectedActions = <String, TargetManagementAction>{};

  @override
  void initState() {
    super.initState();
    final action = widget.initialAction;
    if (action == null) return;
    for (final item in widget.plan.targets) {
      if (!item.allowedActions.contains(action)) continue;
      selectedActions[updateTargetKey(item.target)] = action;
      if (action == TargetManagementAction.repair) {
        for (final binding in item.affectedBindings) {
          selectedActions[updateTargetKey(binding)] = action;
        }
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
  TargetManagementAction.repair => context.l10n.repairTarget,
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
