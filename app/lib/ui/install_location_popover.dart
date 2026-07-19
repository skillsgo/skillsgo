/*
 * [INPUT]: Depends on SkillsGateway Agent and asynchronously enriched Added Project models, localized copy, Flutter Material MenuAnchor, SkillsGo semantic typography, Portal Labs stacked toasts, shared project identities, and vendored Agent SVGs.
 * [OUTPUT]: Provides an edge-aware anchored installation menu that opens immediately, resolves its data and newly batch-added project icons without blocking interaction, asks where a Skill or Repository should be available, executes the initiating surface's preferred install scope, and publishes App-top stacked success or error feedback.
 * [POS]: Serves as the shared first step of installation from discovery cards and remote Skill detail.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'design_system/skills_component_tokens.dart';
import 'design_system/skills_typography.dart';
import 'install_location_island/install_location_island.dart';
import 'native_components.dart';
import 'project_identity_icon.dart';
import 'stacked_toast.dart';

class InstallLocationMenuRequest {
  const InstallLocationMenuRequest({
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.projects,
    required this.onProjectAdded,
    this.repositorySkills = const [],
    this.repositorySkillsFuture,
    this.preferredAction = InstallLocationAction.currentSkill,
  }) : summary = null,
       loader = null;

  const InstallLocationMenuRequest.loading({
    required this.summary,
    required this.loader,
  }) : gateway = null,
       catalog = null,
       detail = null,
       projects = null,
       onProjectAdded = null,
       repositorySkills = null,
       repositorySkillsFuture = null,
       preferredAction = InstallLocationAction.currentSkill;

  final SkillsGateway? gateway;
  final AgentCatalog? catalog;
  final SkillDetail? detail;
  final List<AddedProject>? projects;
  final ValueChanged<AddedProject>? onProjectAdded;
  final List<SkillSummary>? repositorySkills;
  final Future<List<SkillSummary>>? repositorySkillsFuture;
  final InstallLocationAction preferredAction;
  final SkillSummary? summary;
  final Future<InstallLocationMenuRequest> Function()? loader;

  bool get isLoading => loader != null;
}

enum InstallLocationAction { currentSkill, repositorySkills }

class InstallLocationChoice {
  const InstallLocationChoice({required this.selections, required this.action});

  final List<InstallationTargetSelection> selections;
  final InstallLocationAction action;
}

typedef InstallLocationMenuPresenter =
    Future<bool?> Function(
      InstallLocationMenuRequest request,
      Future<InstallLocationSubmission> Function(InstallLocationChoice choice)
      submit,
    );

class InstallLocationSubmission {
  const InstallLocationSubmission.success() : title = null, message = null;

  const InstallLocationSubmission.failure({
    required this.title,
    required this.message,
  });

  final String? title;
  final String? message;

  bool get succeeded => title == null;
}

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
  final toastController = StackedToastController();
  OverlayEntry? toastOverlay;
  Timer? toastCleanupTimer;
  bool preserveToastAfterClose = false;
  InstallLocationMenuRequest? request;
  Future<InstallLocationSubmission> Function(InstallLocationChoice choice)?
  submit;
  Completer<bool?>? result;
  bool submitting = false;

  Future<bool?> _present(
    InstallLocationMenuRequest next,
    Future<InstallLocationSubmission> Function(InstallLocationChoice choice)
    nextSubmit,
  ) async {
    if (controller.isOpen) controller.close();
    toastCleanupTimer?.cancel();
    result?.complete(null);
    final completer = Completer<bool?>();
    setState(() {
      request = next;
      submit = nextSubmit;
      result = completer;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    _ensureToastOverlay();
    controller.open();
    return completer.future;
  }

  void _ensureToastOverlay() {
    if (toastOverlay != null) return;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 320,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox.expand(
                child: Material(
                  color: Colors.transparent,
                  child: StackedToastInteraction(
                    controller: toastController,
                    style: const StackedToastStyle(
                      horizontalPadding: 12,
                      topMargin: 16,
                      maxStackedItems: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    toastOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  Future<void> _complete(InstallLocationChoice choice) async {
    final execute = submit;
    if (execute == null || submitting) return;
    setState(() => submitting = true);
    late InstallLocationSubmission outcome;
    try {
      outcome = await execute(choice);
    } on Object catch (error) {
      if (!mounted) return;
      outcome = InstallLocationSubmission.failure(
        title: AppLocalizations.of(context).installationFailed,
        message: error.toString(),
      );
    }
    if (!mounted) return;
    setState(() => submitting = false);
    if (outcome.succeeded) {
      preserveToastAfterClose = true;
      toastController.show(
        StackedToastItem(
          id: 'install-success-${DateTime.now().microsecondsSinceEpoch}',
          type: StackedToastType.success,
          title: AppLocalizations.of(context).installationSucceeded,
          message: AppLocalizations.of(context).installationSucceededMessage,
          duration: const Duration(seconds: 4),
          actionLabel: MaterialLocalizations.of(context).closeButtonLabel,
        ),
      );
      toastCleanupTimer?.cancel();
      toastCleanupTimer = Timer(const Duration(milliseconds: 4500), () {
        toastOverlay?.remove();
        toastOverlay = null;
      });
      result?.complete(true);
      result = null;
      controller.close();
      return;
    }
    toastController.show(
      StackedToastItem(
        id: 'install-error-${DateTime.now().microsecondsSinceEpoch}',
        type: StackedToastType.error,
        title: outcome.title!,
        message: outcome.message!,
        duration: const Duration(seconds: 6),
        actionLabel: MaterialLocalizations.of(context).closeButtonLabel,
      ),
    );
  }

  void _closed() {
    result?.complete(null);
    result = null;
    if (mounted) {
      setState(() {
        request = null;
        submit = null;
        submitting = false;
      });
    }
    if (preserveToastAfterClose) {
      preserveToastAfterClose = false;
    } else {
      toastOverlay?.remove();
      toastOverlay = null;
    }
  }

  @override
  void dispose() {
    toastCleanupTimer?.cancel();
    toastOverlay?.remove();
    toastOverlay = null;
    super.dispose();
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    current.isLoading
                        ? _AsyncInstallLocationCard(
                            key: ObjectKey(current),
                            summary: current.summary!,
                            loader: current.loader!,
                            onSubmit: _complete,
                          )
                        : _InstallLocationCard(
                            gateway: current.gateway!,
                            catalog: current.catalog!,
                            detail: current.detail!,
                            repositorySkills: current.repositorySkills!,
                            repositorySkillsFuture:
                                current.repositorySkillsFuture,
                            preferredAction: current.preferredAction,
                            initialProjects: current.projects!,
                            onProjectAdded: current.onProjectAdded!,
                            onSubmit: _complete,
                          ),
                    if (submitting)
                      const Positioned.fill(
                        child: AbsorbPointer(child: SizedBox.expand()),
                      ),
                  ],
                ),
              ),
            ],
      builder: (context, menuController, child) =>
          widget.builder(context, _present),
    );
  }
}

class _AsyncInstallLocationCard extends StatefulWidget {
  const _AsyncInstallLocationCard({
    super.key,
    required this.summary,
    required this.loader,
    required this.onSubmit,
  });

  final SkillSummary summary;
  final Future<InstallLocationMenuRequest> Function() loader;
  final ValueChanged<InstallLocationChoice> onSubmit;

  @override
  State<_AsyncInstallLocationCard> createState() =>
      _AsyncInstallLocationCardState();
}

class _AsyncInstallLocationCardState extends State<_AsyncInstallLocationCard> {
  late Future<InstallLocationMenuRequest> request;

  @override
  void initState() {
    super.initState();
    request = widget.loader();
  }

  void retry() => setState(() => request = widget.loader());

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<InstallLocationMenuRequest>(
        future: request,
        builder: (context, snapshot) {
          final l10n = AppLocalizations.of(context);
          final ready = snapshot.data;
          if (ready != null) {
            return _InstallLocationCard(
              gateway: ready.gateway!,
              catalog: ready.catalog!,
              detail: ready.detail!,
              repositorySkills: ready.repositorySkills!,
              repositorySkillsFuture: ready.repositorySkillsFuture,
              preferredAction: ready.preferredAction,
              initialProjects: ready.projects!,
              onProjectAdded: ready.onProjectAdded!,
              onSubmit: widget.onSubmit,
            );
          }
          if (snapshot.hasError) {
            return SkillsCard(
              title: Text(l10n.installSkillTo(widget.summary.name)),
              description: Text(l10n.installationPlanFailed),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SkillsButton(onPressed: retry, child: Text(l10n.retry)),
              ),
            );
          }
          return Semantics(
            liveRegion: true,
            label: l10n.loading,
            child: SkillsCard(
              key: const ValueKey('install-location-skeleton'),
              title: Text(l10n.installSkillTo(widget.summary.name)),
              child: const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkillsSkeletonBox(height: 18, width: 150),
                    SizedBox(height: 18),
                    SkillsSkeletonBox(height: 44, borderRadius: 12),
                    SizedBox(height: 14),
                    SkillsSkeletonBox(height: 18, width: 112),
                    SizedBox(height: 12),
                    SkillsSkeletonBox(height: 36),
                    SizedBox(height: 10),
                    SkillsSkeletonBox(height: 36),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

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
                agent.supportedScopes.contains(InstallationScope.user),
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
                onPressed: canInstall
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
            enabled: agent.supportedScopes.contains(targetScope),
            supportingText: !agent.supportedScopes.contains(targetScope)
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
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
  Widget build(BuildContext context) =>
      ProjectIdentityIcon(project: project, size: 18);
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.agent});

  final AgentStatus agent;

  @override
  Widget build(BuildContext context) =>
      AgentLogo(agentId: agent.id, displayName: agent.displayName, size: 18);
}
