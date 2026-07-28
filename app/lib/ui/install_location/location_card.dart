/*
 * [INPUT]: Depends on Agent catalogs, Added Projects, exact existing targets, project icon resolution, install actions, target selections, and submission feedback.
 * [OUTPUT]: Provides the stateful location, project, Agent, Package-action loading gate, uniform reinstall-capable target selection, validation, and a stably identified Install action.
 * [POS]: Serves as the selection and submission owner of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

class _InstallLocationCard extends StatefulWidget {
  const _InstallLocationCard({
    required this.summary,
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.moduleSkills,
    this.moduleSkillsFuture,
    required this.preferredAction,
    required this.initialProjects,
    required this.onProjectAdded,
    required this.onSubmit,
  });

  final SkillSummary summary;
  final SkillsGateway gateway;
  final AgentCatalog catalog;
  final SkillDetail detail;
  final List<SkillSummary> moduleSkills;
  final Future<List<SkillSummary>>? moduleSkillsFuture;
  final InstallLocationAction preferredAction;
  final List<AddedProject> initialProjects;
  final ValueChanged<AddedProject> onProjectAdded;
  final ValueChanged<InstallLocationChoice> onSubmit;

  @override
  State<_InstallLocationCard> createState() => _InstallLocationCardState();
}

class _InstallLocationCardState extends State<_InstallLocationCard> {
  InstallationScope scope = InstallationScope.global;
  late List<AddedProject> projects;
  final selectedProjects = <String>{};
  final selectedGlobalAgents = <String>{};
  final selectedProjectAgents = <String>{};
  bool addingProject = false;
  late List<SkillSummary> moduleSkills;
  bool moduleSkillsLoading = false;

  List<AgentStatus> get agents => widget.catalog.installed;

  @override
  void initState() {
    super.initState();
    projects = List.of(widget.initialProjects);
    moduleSkills = widget.moduleSkills;
    final moduleFuture = widget.moduleSkillsFuture;
    if (moduleFuture != null) {
      moduleSkillsLoading = true;
      moduleFuture.then((skills) {
        if (!mounted) return;
        setState(() {
          moduleSkills = skills;
          moduleSkillsLoading = false;
        });
      });
    }
    selectedGlobalAgents.addAll(
      agents
          .where(
            (agent) =>
                agent.installed &&
                agent.supportedScopes.contains(InstallationScope.global),
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

  Set<String> get selectedAgents => scope == InstallationScope.global
      ? selectedGlobalAgents
      : selectedProjectAgents;

  bool get canInstall => selections.isNotEmpty;

  List<InstallationTargetSelection> get selections {
    if (scope == InstallationScope.global) {
      return [
        for (final agent in agents)
          if (selectedGlobalAgents.contains(agent.id))
            InstallationTargetSelection(
              scope: InstallationScope.global,
              projectRoot: '',
              agent: agent.id,
            ),
      ];
    }
    return [
      for (final project in projects)
        if (selectedProjects.contains(project.id))
          for (final agent in agents)
            if (selectedProjectAgents.contains(agent.id))
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
    final moduleName = _moduleName(widget.detail.packagePath);
    final island = InstallLocationIsland(
      header: _InstallScopeSelector(
        title: widget.preferredAction == InstallLocationAction.moduleSkills
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
      groups: scope == InstallationScope.global
          ? [_agentGroup(InstallationScope.global, l10n.usedBy)]
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
            scope == InstallationScope.global
                ? l10n.globalInstallSummary(selections.length)
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
              if (moduleSkillsLoading) ...[
                const Expanded(
                  child: SkillsSkeletonBox(height: 36, borderRadius: 999),
                ),
                const SizedBox(width: 10),
              ] else if (moduleSkills.length > 1 &&
                  widget.preferredAction ==
                      InstallLocationAction.currentSkill) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: canInstall
                        ? () => widget.onSubmit(
                            InstallLocationChoice(
                              selections: selections,
                              action: InstallLocationAction.moduleSkills,
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
                      message: moduleName ?? '',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const style = TextStyle(fontWeight: FontWeight.w400);
                          return Text(
                            _moduleButtonLabel(
                              l10n: l10n,
                              moduleName: moduleName,
                              count: moduleSkills.length,
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
                key: const ValueKey('install-location-submit'),
                label: l10n.install,
                height: 36,
                horizontalPadding: 18,
                labelStyle: const TextStyle(fontWeight: FontWeight.w400),
                onPressed: canInstall && !moduleSkillsLoading
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

  String? _moduleName(String value) {
    var module = value.trim();
    if (module.isEmpty) return null;

    module = module.split(RegExp(r'[?#]')).first;
    final scpLike = RegExp(r'^[^/@]+@[^/:]+:(.+)$').firstMatch(module);
    if (scpLike != null) {
      module = scpLike.group(1)!;
    } else {
      final uri = Uri.tryParse(module);
      if (uri != null && uri.host.isNotEmpty) {
        module = uri.path;
      } else {
        module = module.replaceFirst(RegExp(r'^[^/]+\.[^/]+/'), '');
      }
    }

    module = module
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceFirst(RegExp(r'\.git$', caseSensitive: false), '');
    return module.isEmpty ? null : module;
  }

  String _moduleButtonLabel({
    required AppLocalizations l10n,
    required String? moduleName,
    required int count,
    required double maxWidth,
    required TextStyle style,
  }) {
    if (moduleName == null) {
      return l10n.installAllPackageSkills(count);
    }

    String labelFor(String name) => l10n.installPackageSkills(name, count);
    if (_textWidth(labelFor(moduleName), style) <= maxWidth) {
      return labelFor(moduleName);
    }

    for (var visible = moduleName.length - 1; visible >= 3; visible--) {
      final leading = (visible / 2).ceil();
      final trailing = visible - leading;
      final compact =
          '${moduleName.substring(0, leading)}…'
          '${moduleName.substring(moduleName.length - trailing)}';
      final label = labelFor(compact);
      if (_textWidth(label, style) <= maxWidth) return label;
    }
    return l10n.installAllPackageSkills(count);
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
                (targetScope == InstallationScope.global
                        ? selectedGlobalAgents
                        : selectedProjectAgents)
                    .contains(agent.id),
            enabled: agent.supportedScopes.contains(targetScope),
            inlineStatusText: !agent.supportedScopes.contains(targetScope)
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
        'agents' when scope == InstallationScope.global => selectedGlobalAgents,
        _ => selectedProjectAgents,
      };
      selected ? target.add(itemId) : target.remove(itemId);
    });
  }
}
