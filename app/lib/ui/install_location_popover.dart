/*
 * [INPUT]: Depends on SkillsGateway Agent and Added Project models, localized copy, Flutter Material MenuAnchor, HugeIcons project glyphs, and vendored Agent SVGs.
 * [OUTPUT]: Provides an edge-aware anchored installation menu that asks where a Skill should be available, then returns explicit location-and-Agent selections.
 * [POS]: Serves as the shared first step of installation from discovery cards and remote Skill detail.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'install_location_island/install_location_island.dart';
import 'native_components.dart';

class InstallLocationMenuRequest {
  const InstallLocationMenuRequest({
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.projects,
    required this.onProjectAdded,
    this.repositorySkills = const [],
  });

  final SkillsGateway gateway;
  final AgentCatalog catalog;
  final SkillDetail detail;
  final List<AddedProject> projects;
  final ValueChanged<AddedProject> onProjectAdded;
  final List<SkillSummary> repositorySkills;
}

enum InstallLocationAction { currentSkill, repositorySkills }

class InstallLocationChoice {
  const InstallLocationChoice({required this.selections, required this.action});

  final List<InstallationTargetSelection> selections;
  final InstallLocationAction action;
}

typedef InstallLocationMenuPresenter =
    Future<InstallLocationChoice?> Function(InstallLocationMenuRequest request);

class InstallLocationMenuAnchor extends StatefulWidget {
  const InstallLocationMenuAnchor({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    InstallLocationMenuPresenter present,
  )
  builder;

  @override
  State<InstallLocationMenuAnchor> createState() =>
      _InstallLocationMenuAnchorState();
}

class _InstallLocationMenuAnchorState extends State<InstallLocationMenuAnchor> {
  final controller = MenuController();
  InstallLocationMenuRequest? request;
  Completer<InstallLocationChoice?>? result;

  Future<InstallLocationChoice?> _present(
    InstallLocationMenuRequest next,
  ) async {
    if (controller.isOpen) controller.close();
    result?.complete(null);
    final completer = Completer<InstallLocationChoice?>();
    setState(() {
      request = next;
      result = completer;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    controller.open();
    return completer.future;
  }

  void _complete(InstallLocationChoice choice) {
    result?.complete(choice);
    result = null;
    controller.close();
  }

  void _closed() {
    result?.complete(null);
    result = null;
    if (mounted) setState(() => request = null);
  }

  @override
  Widget build(BuildContext context) {
    final current = request;
    return MenuAnchor(
      controller: controller,
      useRootOverlay: true,
      consumeOutsideTap: true,
      crossAxisUnconstrained: true,
      reservedPadding: const EdgeInsets.all(16),
      alignmentOffset: const Offset(0, 8),
      animated: true,
      onClose: _closed,
      clipBehavior: Clip.none,
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: current == null
          ? const [SizedBox.shrink()]
          : [
              SizedBox(
                width: 400,
                child: _InstallLocationCard(
                  gateway: current.gateway,
                  catalog: current.catalog,
                  detail: current.detail,
                  repositorySkills: current.repositorySkills,
                  initialProjects: current.projects,
                  onProjectAdded: current.onProjectAdded,
                  onSubmit: _complete,
                ),
              ),
            ],
      builder: (context, menuController, child) =>
          widget.builder(context, _present),
    );
  }
}

class _InstallLocationCard extends StatefulWidget {
  const _InstallLocationCard({
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.repositorySkills,
    required this.initialProjects,
    required this.onProjectAdded,
    required this.onSubmit,
  });

  final SkillsGateway gateway;
  final AgentCatalog catalog;
  final SkillDetail detail;
  final List<SkillSummary> repositorySkills;
  final List<AddedProject> initialProjects;
  final ValueChanged<AddedProject> onProjectAdded;
  final ValueChanged<InstallLocationChoice> onSubmit;

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

  List<AgentStatus> get agents => widget.catalog.installed;

  @override
  void initState() {
    super.initState();
    projects = List.of(widget.initialProjects);
    selectedUserAgents.addAll(
      agents
          .where(
            (agent) => agent.supportedScopes.contains(InstallationScope.user),
          )
          .map((agent) => agent.id),
    );
    selectedProjectAgents.addAll(
      agents
          .where(
            (agent) =>
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
          if (selectedUserAgents.contains(agent.id) &&
              !_isInstalled(InstallationScope.user, '', agent.id))
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
                !_isInstalled(
                  InstallationScope.project,
                  project.path,
                  agent.id,
                ))
              InstallationTargetSelection(
                scope: InstallationScope.project,
                projectRoot: project.path,
                agent: agent.id,
              ),
    ];
  }

  bool _isInstalled(
    InstallationScope targetScope,
    String projectRoot,
    String agent,
  ) => widget.detail.installationTargets.any(
    (target) =>
        target.scope == targetScope &&
        target.projectRoot == projectRoot &&
        target.agent == agent &&
        target.version == widget.detail.immutableVersion &&
        target.health == InstallationHealth.healthy,
  );

  Future<void> _addProject() async {
    if (addingProject) return;
    setState(() => addingProject = true);
    final project = await widget.gateway.addProject();
    if (!mounted) return;
    setState(() {
      addingProject = false;
      if (project == null) return;
      final index = projects.indexWhere((item) => item.id == project.id);
      if (index < 0) {
        projects = [...projects, project];
      } else {
        projects = [...projects]..[index] = project;
      }
      if (project.isAccessible) selectedProjects.add(project.id);
    });
    if (project != null) widget.onProjectAdded(project);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final repositoryName = _repositoryName(widget.detail.repository);
    final island = InstallLocationIsland(
      header: _InstallScopeSelector(
        title: l10n.installSkillTo(widget.detail.name),
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
        outerBackgroundColor: scheme.surfaceContainerHigh,
        cardBackgroundColor: scheme.surfaceContainer,
        tabTrackColor: scheme.surfaceContainerHighest,
        tabIndicatorColor: scheme.primaryContainer,
        tabIndicatorTextColor: scheme.onPrimaryContainer,
        selectedColor: scheme.primary,
        checkboxBorderColor: scheme.outlineVariant,
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: .64),
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              if (widget.repositorySkills.length > 1) ...[
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
                              count: widget.repositorySkills.length,
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
                label: l10n.confirmInstall,
                height: 36,
                horizontalPadding: 18,
                labelStyle: const TextStyle(fontWeight: FontWeight.w400),
                onPressed: canInstall
                    ? () => widget.onSubmit(
                        InstallLocationChoice(
                          selections: selections,
                          action: InstallLocationAction.currentSkill,
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
                (targetScope != InstallationScope.user ||
                    !_isInstalled(targetScope, '', agent.id)),
            supportingText: !agent.supportedScopes.contains(targetScope)
                ? l10n.unsupportedCell
                : targetScope == InstallationScope.user &&
                      _isInstalled(targetScope, '', agent.id)
                ? l10n.installedCell
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

class _InstallScopeSelector extends StatelessWidget {
  const _InstallScopeSelector({
    required this.title,
    required this.scope,
    required this.allProjectsLabel,
    required this.selectedProjectsLabel,
    required this.onChanged,
    required this.addProjectLabel,
    required this.onAddProject,
  });

  final String title;
  final InstallationScope scope;
  final String allProjectsLabel;
  final String selectedProjectsLabel;
  final ValueChanged<InstallationScope> onChanged;
  final String addProjectLabel;
  final VoidCallback? onAddProject;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      RadioGroup<InstallationScope>(
        groupValue: scope,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        child: Column(
          children: [
            _ScopeRadioRow(
              label: allProjectsLabel,
              value: InstallationScope.user,
              onChanged: onChanged,
            ),
            _ScopeRadioRow(
              label: selectedProjectsLabel,
              value: InstallationScope.project,
              onChanged: onChanged,
              trailing: TextButton(
                onPressed: onAddProject,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(addProjectLabel),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ScopeRadioRow extends StatelessWidget {
  const _ScopeRadioRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final InstallationScope value;
  final ValueChanged<InstallationScope> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => onChanged(value),
    child: Row(
      children: [
        SizedBox(
          width: 40,
          child: Center(
            child: Radio<InstallationScope>(
              value: value,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _ProjectAvatar extends StatelessWidget {
  const _ProjectAvatar({required this.project});

  final AddedProject project;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HugeIcon(
      icon: HugeIcons.strokeRoundedFolderCode,
      size: 18,
      color: project.isAccessible
          ? scheme.primary
          : scheme.onSurfaceVariant.withValues(alpha: .55),
      strokeWidth: 1.7,
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.agent});

  final AgentStatus agent;

  @override
  Widget build(BuildContext context) =>
      AgentLogo(agentId: agent.id, displayName: agent.displayName, size: 18);
}
