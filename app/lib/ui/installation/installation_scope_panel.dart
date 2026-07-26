/*
 * [INPUT]: Depends on installation targets, Added Projects, localized Agent labels, target health chips, and expandable Material presentation.
 * [OUTPUT]: Provides the public InstallationScopePanel and grouped user/project target summaries.
 * [POS]: Serves as the installed-target scope summary segment of detail journeys.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

class InstallationScopePanel extends StatefulWidget {
  const InstallationScopePanel({
    super.key,
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
  State<InstallationScopePanel> createState() => _InstallationScopePanelState();
}

class _InstallationScopePanelState extends State<InstallationScopePanel> {
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
            alignment: AlignmentDirectional.topStart,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 36,
                      top: 6,
                    ),
                    child: Column(
                      children: [
                        for (final target in group.targets)
                          _InstallationTargetDetail(
                            target: target,
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
                message: agentDisplayLabel(agent),
                child: AgentLogo(
                  agentId: agent,
                  displayName: agentDisplayLabel(agent),
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

Future<TargetManagementExecution> executeInlineTargetAction({
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
  };
  final execution = await gateway.executeTargetManagement(
    plan.selectActions(actions),
  );
  if (execution.summary.failed > 0) {
    throw StateError('The selected target action failed.');
  }
  return execution;
}
