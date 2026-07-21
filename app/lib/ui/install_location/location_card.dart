/*
 * [INPUT]: Depends on Agent catalogs, Added Projects, exact existing targets, project icon resolution, install actions, target selections, and submission feedback.
 * [OUTPUT]: Provides the stateful location, project, Agent, repository-action loading gate, duplicate-target exclusion, validation, and submission card.
 * [POS]: Serves as the selection and submission owner of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

class _InstallLocationCard extends StatefulWidget {
  const _InstallLocationCard({
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.repositorySkills,
    this.repositorySkillsFuture,
    required this.preferredAction,
    required this.initialProjects,
    required this.onProjectAdded,
    required this.onSubmit,
    this.existingTargets = const [],
  });

  final SkillsGateway gateway;
  final AgentCatalog catalog;
  final SkillDetail detail;
  final List<SkillSummary> repositorySkills;
  final Future<List<SkillSummary>>? repositorySkillsFuture;
  final InstallLocationAction preferredAction;
  final List<AddedProject> initialProjects;
  final ValueChanged<AddedProject> onProjectAdded;
  final ValueChanged<InstallLocationChoice> onSubmit;
  final List<SkillInstallationTarget> existingTargets;

  @override
  State<_InstallLocationCard> createState() => _InstallLocationCardState();
}

class _InstallLocationCardState extends State<_InstallLocationCard> {
  InstallationScope scope = InstallationScope.user;
  late List<AddedProject> projects;
  final selectedProjects = <String>{};
  final selectedUserAgents = <String>{};
  final selectedProjectAgents = <String>{};
  bool addingProject = false;
  late List<SkillSummary> repositorySkills;
  bool repositorySkillsLoading = false;

  List<AgentStatus> get agents => widget.catalog.installed;

  bool _alreadyInstalled(
    InstallationScope targetScope,
    String agent, {
    String projectRoot = '',
  }) => widget.existingTargets.any(
    (target) =>
        target.scope == targetScope &&
        target.agent == agent &&
        (targetScope == InstallationScope.user ||
            target.projectRoot == projectRoot),
  );

  @override
  void initState() {
    super.initState();
    projects = List.of(widget.initialProjects);
    repositorySkills = widget.repositorySkills;
    final repositoryFuture = widget.repositorySkillsFuture;
    if (repositoryFuture != null) {
      repositorySkillsLoading = true;
      repositoryFuture.then((skills) {
        if (!mounted) return;
        setState(() {
          repositorySkills = skills;
          repositorySkillsLoading = false;
        });
      });
    }
    selectedUserAgents.addAll(
      agents
          .where(
            (agent) =>
                agent.installed &&
                agent.supportedScopes.contains(InstallationScope.user) &&
                !_alreadyInstalled(InstallationScope.user, agent.id),
          )
          .map((agent) => agent.id),
    );
    selectedProjectAgents.addAll(
      agents
          .where(
            (agent) =>
                agent.installed &&
                agent.supportedScopes.contains(InstallationScope.project),
          )
          .map((agent) => agent.id),
    );
  }

  Set<String> get selectedAgents => scope == InstallationScope.user
      ? selectedUserAgents
      : selectedProjectAgents;

  bool get canInstall => selections.isNotEmpty;

  List<InstallationTargetSelection> get selections {
    if (scope == InstallationScope.user) {
      return [
        for (final agent in agents)
          if (selectedUserAgents.contains(agent.id))
            InstallationTargetSelection(
              scope: InstallationScope.user,
              projectRoot: '',
              agent: agent.id,
            ),
      ];
    }
    return [
      for (final project in projects)
        if (selectedProjects.contains(project.id))
          for (final agent in agents)
            if (selectedProjectAgents.contains(agent.id) &&
                !_alreadyInstalled(
                  InstallationScope.project,
                  agent.id,
                  projectRoot: project.path,
                ))
              InstallationTargetSelection(
                scope: InstallationScope.project,
                projectRoot: project.path,
                agent: agent.id,
              ),
    ];
  }

  Future<void> _addProject() async {
    if (addingProject) return;
    setState(() => addingProject = true);
    final addedProjects = await widget.gateway.addProjects();
    if (!mounted) return;
    setState(() {
      addingProject = false;
      for (final project in addedProjects) {
        final index = projects.indexWhere((item) => item.id == project.id);
        if (index < 0) {
          projects = [...projects, project];
        } else {
          projects = [...projects]..[index] = project;
        }
        if (project.isAccessible) selectedProjects.add(project.id);
      }
    });
    for (final project in addedProjects) {
      widget.onProjectAdded(project);
      unawaited(_resolveProjectIcon(project));
    }
  }

  Future<void> _resolveProjectIcon(AddedProject project) async {
    final resolved = await widget.gateway.resolveProjectIcon(project);
    if (!mounted) return;
    final index = projects.indexWhere((item) => item.id == resolved.id);
    if (index < 0 || projects[index].path != resolved.path) return;
    setState(() => projects = [...projects]..[index] = resolved);
    widget.onProjectAdded(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final components = context.skillsComponents;
    final repositoryName = _repositoryName(widget.detail.repository);
    final island = InstallLocationIsland(
      header: _InstallScopeSelector(
        title: widget.preferredAction == InstallLocationAction.repositorySkills
            ? l10n.installAllSkillsTo
            : l10n.installSkillTo(widget.detail.name),
        scope: scope,
        allProjectsLabel: l10n.availableInAllProjects,
        selectedProjectsLabel: l10n.availableInSelectedProjects,
        onChanged: (value) => setState(() => scope = value),
        addProjectLabel: addingProject ? l10n.loading : l10n.addProject,
        onAddProject: addingProject
            ? null
            : () {
                setState(() => scope = InstallationScope.project);
                unawaited(_addProject());
              },
      ),
      groups: scope == InstallationScope.user
          ? [_agentGroup(InstallationScope.user, l10n.usedBy)]
          : [
              _projectGroup(),
              _agentGroup(InstallationScope.project, l10n.usedBy),
            ],
      onItemChanged: _itemChanged,
      contentKey: ValueKey('install-island-scroll-${scope.name}'),
      style: InstallLocationIslandStyle(
        outerBackgroundColor: components.overlay,
        cardBackgroundColor: components.overlay,
        tabTrackColor: scheme.surfaceContainerHighest,
        tabIndicatorColor: scheme.primaryContainer,
        tabIndicatorTextColor: scheme.onPrimaryContainer,
        selectedColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        checkboxBorderColor: components.controlBorder,
        textColor: scheme.onSurface,
        secondaryTextColor: scheme.onSurfaceVariant,
        shadowColor: scheme.shadow,
        outerBorderRadius: 20,
        cardBorderRadius: 16,
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scope == InstallationScope.user
                ? l10n.userInstallSummary(selections.length)
                : l10n.projectInstallSummary(
                    selectedProjects.length,
                    selectedAgents.length,
                  ),
            style: context.skillsTypography.metadata.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: .64),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              if (repositorySkillsLoading) ...[
                const Expanded(
                  child: SkillsSkeletonBox(height: 36, borderRadius: 999),
                ),
                const SizedBox(width: 10),
              ] else if (repositorySkills.length > 1 &&
                  widget.preferredAction ==
                      InstallLocationAction.currentSkill) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: canInstall
                        ? () => widget.onSubmit(
                            InstallLocationChoice(
                              selections: selections,
                              action: InstallLocationAction.repositorySkills,
                            ),
                          )
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      backgroundColor: Color.alphaBlend(
                        scheme.primary.withValues(alpha: .10),
                        scheme.surfaceContainer,
                      ),
                      foregroundColor: scheme.primary,
                      disabledBackgroundColor: Color.alphaBlend(
                        scheme.primary.withValues(alpha: .05),
                        scheme.surfaceContainer,
                      ),
                      disabledForegroundColor: scheme.primary.withValues(
                        alpha: .38,
                      ),
                      shape: const StadiumBorder(),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Tooltip(
                      message: repositoryName ?? '',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const style = TextStyle(fontWeight: FontWeight.w400);
                          return Text(
                            _repositoryButtonLabel(
                              l10n: l10n,
                              repositoryName: repositoryName,
                              count: repositorySkills.length,
                              maxWidth: constraints.maxWidth,
                              style: style,
                            ),
                            maxLines: 1,
                            style: style,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ] else
                const Spacer(),
              PrimaryCapsuleButton(
                label:
                    widget.preferredAction ==
                        InstallLocationAction.repositorySkills
                    ? l10n.installAll
                    : l10n.confirmInstall,
                height: 36,
                horizontalPadding: 18,
                labelStyle: const TextStyle(fontWeight: FontWeight.w400),
                onPressed: canInstall && !repositorySkillsLoading
                    ? () => widget.onSubmit(
                        InstallLocationChoice(
                          selections: selections,
                          action: widget.preferredAction,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
    return SizedBox(height: 460, child: island);
  }

  String? _repositoryName(String value) {
    var repository = value.trim();
    if (repository.isEmpty) return null;

    repository = repository.split(RegExp(r'[?#]')).first;
    final scpLike = RegExp(r'^[^/@]+@[^/:]+:(.+)$').firstMatch(repository);
    if (scpLike != null) {
      repository = scpLike.group(1)!;
    } else {
      final uri = Uri.tryParse(repository);
      if (uri != null && uri.host.isNotEmpty) {
        repository = uri.path;
      } else {
        repository = repository.replaceFirst(RegExp(r'^[^/]+\.[^/]+/'), '');
      }
    }

    repository = repository
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceFirst(RegExp(r'\.git$', caseSensitive: false), '');
    return repository.isEmpty ? null : repository;
  }

  String _repositoryButtonLabel({
    required AppLocalizations l10n,
    required String? repositoryName,
    required int count,
    required double maxWidth,
    required TextStyle style,
  }) {
    if (repositoryName == null) {
      return l10n.installAllRepositorySkills(count);
    }

    String labelFor(String name) => l10n.installRepositorySkills(name, count);
    if (_textWidth(labelFor(repositoryName), style) <= maxWidth) {
      return labelFor(repositoryName);
    }

    for (var visible = repositoryName.length - 1; visible >= 3; visible--) {
      final leading = (visible / 2).ceil();
      final trailing = visible - leading;
      final compact =
          '${repositoryName.substring(0, leading)}…'
          '${repositoryName.substring(repositoryName.length - trailing)}';
      final label = labelFor(compact);
      if (_textWidth(label, style) <= maxWidth) return label;
    }
    return l10n.installAllRepositorySkills(count);
  }

  double _textWidth(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }

  InstallLocationIslandGroup _projectGroup() {
    final l10n = AppLocalizations.of(context);
    return InstallLocationIslandGroup(
      id: 'projects',
      label: l10n.projects,
      showHeader: false,
      items: [
        for (final project in projects)
          InstallLocationIslandItem(
            id: project.id,
            label: project.name,
            leading: _ProjectAvatar(project: project),
            selected: selectedProjects.contains(project.id),
            enabled: project.isAccessible,
            supportingText: project.isAccessible
                ? null
                : l10n.projectUnavailable,
          ),
      ],
    );
  }

  InstallLocationIslandGroup _agentGroup(
    InstallationScope targetScope,
    String label,
  ) {
    final l10n = AppLocalizations.of(context);
    return InstallLocationIslandGroup(
      id: 'agents',
      label: label,
      collapsible: false,
      prominentHeader: true,
      itemLeftPadding: 16,
      selectionControlWidth: 40,
      items: [
        for (final agent in agents)
          InstallLocationIslandItem(
            id: agent.id,
            label: agent.displayName,
            leading: _AgentAvatar(agent: agent),
            selected:
                (targetScope == InstallationScope.user
                        ? selectedUserAgents
                        : selectedProjectAgents)
                    .contains(agent.id),
            enabled:
                agent.supportedScopes.contains(targetScope) &&
                !(targetScope == InstallationScope.user &&
                    _alreadyInstalled(targetScope, agent.id)),
            supportingText:
                targetScope == InstallationScope.user &&
                    _alreadyInstalled(targetScope, agent.id)
                ? l10n.agentInstalled
                : !agent.supportedScopes.contains(targetScope)
                ? l10n.unsupportedCell
                : null,
          ),
      ],
    );
  }

  void _itemChanged(String groupId, String itemId, bool selected) {
    setState(() {
      final target = switch (groupId) {
        'projects' => selectedProjects,
        'agents' when scope == InstallationScope.user => selectedUserAgents,
        _ => selectedProjectAgents,
      };
      selected ? target.add(itemId) : target.remove(itemId);
    });
  }
}
