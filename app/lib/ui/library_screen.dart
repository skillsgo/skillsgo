/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, Riverpod Library state, gateway mutations, localization, and shared operation dialogs.
 * [OUTPUT]: Provides the Library destination, cold/stale loading UI, project and Agent filtering, External Adoption, Local detail, export, and installation-target views.
 * [POS]: Serves as the complete Library feature view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, required this.gateway});
  final SkillsGateway gateway;
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  static const _allRoute = 'all';
  static const _userRoute = 'user';
  static const _addProjectRoute = 'add-project';
  Object? actionError;
  bool checking = false;
  Object? updateCheckError;
  Map<String, UpdateState> updates = const {};
  CommandResult? result;
  final operatingSkills = <String>{};
  final scrollController = ScrollController();
  final librarySearchController = TextEditingController();
  final librarySearchFocusNode = FocusNode();
  String selectedRoute = _allRoute;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    librarySearchController.dispose();
    librarySearchFocusNode.dispose();
    super.dispose();
  }

  AsyncValue<LibraryContentState> get _library => ref.read(libraryProvider);

  List<InstalledSkill>? get skills => _library.value?.skills;

  AgentCatalog? get agentCatalog => _library.value?.agentCatalog;

  List<AddedProject> get projects =>
      _library.value?.projects ?? const <AddedProject>[];

  Object? get error =>
      actionError ?? _library.value?.refreshError ?? _library.error;

  bool get loading =>
      _library.isLoading || (_library.value?.refreshing ?? false);

  Future<void> load() async {
    if (actionError != null) setState(() => actionError = null);
    await ref.read(libraryProvider.notifier).refresh();
    if (!mounted) return;
    if (selectedRoute.startsWith('agent:')) {
      final selectedAgent = selectedRoute.substring('agent:'.length);
      if (!_agents.contains(selectedAgent)) selectedRoute = _allRoute;
    }
    if (selectedRoute.startsWith('project:') && _selectedProject == null) {
      selectedRoute = _allRoute;
    }
  }

  AddedProject? get _selectedProject {
    if (!selectedRoute.startsWith('project:')) return null;
    final id = selectedRoute.substring('project:'.length);
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Future<void> _addProject() async {
    try {
      final project = await widget.gateway.addProject();
      if (project == null || !mounted) return;
      setState(() => selectedRoute = 'project:${project.id}');
      await load();
    } on Object catch (caught) {
      if (mounted) setState(() => actionError = caught);
    }
  }

  Future<void> _relocateProject(AddedProject project) async {
    try {
      final relocated = await widget.gateway.relocateProject(project.id);
      if (relocated == null || !mounted) return;
      await load();
    } on Object catch (caught) {
      if (mounted) setState(() => actionError = caught);
    }
  }

  Future<void> _removeProject(AddedProject project) async {
    final confirmed = await _confirmCommand(
      context,
      title: context.l10n.removeProjectTitle(project.name),
      description: context.l10n.removeProjectDescription,
      facts: [project.path],
      confirmLabel: context.l10n.removeFromList,
    );
    if (!confirmed || !mounted) return;
    await widget.gateway.removeProject(project.id);
    if (!mounted) return;
    setState(() => selectedRoute = _allRoute);
    await load();
  }

  Future<void> checkUpdates() async {
    if (skills == null || checking) return;
    setState(() {
      checking = true;
      updateCheckError = null;
      updates = {
        for (final skill in skills!)
          _libraryUpdateKey(skill): skill.provenance == LibraryProvenance.hub
              ? UpdateState.checking
              : UpdateState.unsupported,
      };
    });
    try {
      updates = await widget.gateway.checkUpdates(skills!);
    } catch (caught) {
      updateCheckError = caught;
      updates = {
        for (final skill in skills!)
          _libraryUpdateKey(skill): UpdateState.failed,
      };
    }
    if (mounted) setState(() => checking = false);
  }

  Future<void> update(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    setState(() => operatingSkills.add(skill.name));
    setState(() => result = null);
    try {
      final plan = await widget.gateway.preflightUpdate(skill, skill.targets);
      if (!mounted) return;
      final execution = await showSkillsDialog<UpdateExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UpdatePlanDialog(
          gateway: widget.gateway,
          skill: skill,
          plan: plan,
        ),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => operatingSkills.remove(skill.name));
  }

  Future<void> manage(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    setState(() => operatingSkills.add(skill.name));
    setState(() => result = null);
    try {
      final plan = await widget.gateway.preflightTargetManagement(
        skill,
        skill.targets,
      );
      if (!mounted) return;
      final execution = await showSkillsDialog<TargetManagementExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _TargetManagementDialog(gateway: widget.gateway, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => operatingSkills.remove(skill.name));
  }

  List<String> get _agents {
    final values =
        <String>{
          ...?agentCatalog?.installed.map((agent) => agent.id),
          ...(skills ?? const <InstalledSkill>[]).expand(
            (skill) => skill.agents,
          ),
        }.toList()..sort(
          (left, right) => _agentLabel(left).compareTo(_agentLabel(right)),
        );
    return values;
  }

  bool get _hasUpdateableSkills => (skills ?? const <InstalledSkill>[]).any(
    (skill) => skill.provenance == LibraryProvenance.hub,
  );

  String _agentLabel(String agent) {
    for (final status in agentCatalog?.agents ?? const <AgentStatus>[]) {
      if (status.id == agent) return status.displayName;
    }
    return agent
        .split(RegExp(r'[-_]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  List<SkillsRailItem<String>> _railItems(BuildContext context) => [
    SkillsRailItem(value: _allRoute, label: context.l10n.all),
    SkillsRailItem(value: _userRoute, label: context.l10n.userScope),
    for (final project in projects)
      SkillsRailItem(
        value: 'project:${project.id}',
        label: project.isAccessible
            ? project.name
            : context.l10n.projectRailUnavailable(project.name),
      ),
    SkillsRailItem(value: _addProjectRoute, label: context.l10n.addProject),
    for (var index = 0; index < _agents.length; index++)
      SkillsRailItem(
        value: 'agent:${_agents[index]}',
        label: _agentLabel(_agents[index]),
        leading: AgentLogo(
          key: ValueKey('library-agent-logo-${_agents[index]}'),
          agentId: _agents[index],
          displayName: _agentLabel(_agents[index]),
        ),
        dividerBefore: index == 0,
      ),
  ];

  String _routeTitle(BuildContext context) {
    if (selectedRoute == _allRoute) return context.l10n.all;
    if (selectedRoute == _userRoute) return context.l10n.userScope;
    if (_selectedProject != null) return _selectedProject!.name;
    return _agentLabel(selectedRoute.substring('agent:'.length));
  }

  List<InstalledSkill> get _visibleSkills {
    final current = skills ?? const <InstalledSkill>[];
    final visible = <InstalledSkill>[];
    for (final skill in current) {
      final targets = switch (selectedRoute) {
        _userRoute =>
          skill.targets
              .where((target) => target.scope == InstallationScope.user)
              .toList(growable: false),
        _
            when selectedRoute.startsWith('project:') &&
                _selectedProject != null =>
          skill.targets
              .where((target) => target.projectRoot == _selectedProject!.path)
              .toList(growable: false),
        _ when selectedRoute.startsWith('agent:') =>
          skill.targets
              .where(
                (target) =>
                    target.agent == selectedRoute.substring('agent:'.length),
              )
              .toList(growable: false),
        _ => skill.targets,
      };
      if (targets.isEmpty) continue;
      final scoped = targets.length == skill.targets.length
          ? skill
          : skill.withTargets(targets);
      final query = librarySearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final searchable = [
          scoped.name,
          scoped.coordinate,
          ...scoped.agents,
          ...scoped.projects,
          ...scoped.versions,
        ].join('\n').toLowerCase();
        if (!searchable.contains(query)) continue;
      }
      visible.add(scoped);
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    return SkillsDestinationLayout(
      rail: SkillsSideRail<String>(
        semanticLabel: context.l10n.libraryNavigation,
        selected: selectedRoute,
        onSelected: (route) {
          if (route == _addProjectRoute) {
            unawaited(_addProject());
            return;
          }
          setState(() => selectedRoute = route);
        },
        items: _railItems(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionEyebrow(
                      _routeTitle(context),
                      color: context.skillsComponents.statusAccent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.yourLibrary,
                      style: const TextStyle(
                        fontFamily: SkillsTokens.serifFamily,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (_selectedProject != null) ...[
                      SecondaryCapsuleButton(
                        label: context.l10n.relocateProject,
                        icon: Icons.drive_file_move_outline,
                        onPressed: () => _relocateProject(_selectedProject!),
                      ),
                      SecondaryCapsuleButton(
                        label: context.l10n.removeFromList,
                        icon: Icons.remove_circle_outline,
                        onPressed: () => _removeProject(_selectedProject!),
                      ),
                    ],
                    SecondaryCapsuleButton(
                      label: checking
                          ? context.l10n.checking
                          : context.l10n.checkUpdates,
                      icon: Icons.sync,
                      onPressed: checking || !_hasUpdateableSkills
                          ? null
                          : checkUpdates,
                    ),
                    SecondaryCapsuleButton(
                      label: context.l10n.refresh,
                      icon: Icons.refresh,
                      onPressed: loading ? null : load,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 14),
            OperationPanel(result: result!),
          ],
          if (error != null && skills != null) ...[
            const SizedBox(height: 14),
            SkillsAlert(
              icon: const Icon(Icons.sync_problem_outlined),
              title: Text(_failureCopy(context, error!).title),
              description: Text(_failureCopy(context, error!).message),
            ),
          ],
          if (updateCheckError != null) ...[
            const SizedBox(height: 14),
            SkillsAlert(
              icon: const Icon(Icons.cloud_off_outlined),
              title: Text(_failureCopy(context, updateCheckError!).title),
              description: Text(
                _failureCopy(context, updateCheckError!).message,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SkillsInput(
            key: const Key('library-search'),
            controller: librarySearchController,
            focusNode: librarySearchFocusNode,
            onChanged: (_) => setState(() {}),
            leading: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            placeholder: Text(context.l10n.searchLibrary),
            placeholderStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading && skills == null) {
      return Semantics(
        liveRegion: true,
        label: context.l10n.loading,
        child: const _LibrarySkeleton(),
      );
    }
    if (error != null && skills == null) {
      final copy = _failureCopy(context, error!);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: PrimaryCapsuleButton(
          label: context.l10n.retry,
          onPressed: load,
        ),
      );
    }
    final project = _selectedProject;
    if (project != null) {
      if (!project.isAccessible) {
        final copy = switch (project.accessState) {
          ProjectAccessState.missing => (
            title: context.l10n.projectMissingTitle,
            message: context.l10n.projectMissingMessage,
          ),
          ProjectAccessState.permissionDenied => (
            title: context.l10n.projectPermissionTitle,
            message: context.l10n.projectPermissionMessage,
          ),
          ProjectAccessState.inaccessible => (
            title: context.l10n.projectInaccessibleTitle,
            message: context.l10n.projectInaccessibleMessage,
          ),
          ProjectAccessState.accessible => throw StateError(
            'Accessible project reached inaccessible state.',
          ),
        };
        return EmptyState(
          title: copy.title,
          message: '${copy.message}\n${project.path}',
          action: PrimaryCapsuleButton(
            label: context.l10n.relocateProject,
            onPressed: () => _relocateProject(project),
          ),
        );
      }
    }
    if (_visibleSkills.isEmpty) {
      if (librarySearchController.text.trim().isNotEmpty) {
        return EmptyState(
          title: context.l10n.libraryNoMatches,
          message: context.l10n.libraryNoMatchesMessage,
        );
      }
      if (project != null) {
        return EmptyState(
          title: context.l10n.emptyProjectTitle(project.name),
          message: context.l10n.emptyProjectMessage,
        );
      }
      return EmptyState(
        title: context.l10n.libraryEmpty,
        message: context.l10n.libraryEmptyMessage,
      );
    }
    return ListView.separated(
      key: const ValueKey('library-results'),
      controller: scrollController,
      itemCount: _visibleSkills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final skill = _visibleSkills[index];
        final state = updates[_libraryUpdateKey(skill)] ?? UpdateState.unknown;
        final operating = operatingSkills.contains(skill.name);
        return GlassCard(
          child: Row(
            children: [
              SkillGlyph(name: skill.name),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final appTheme = Theme.of(context);
                    final removed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => Theme(
                          data: appTheme,
                          child: LocalDetailScreen(
                            gateway: widget.gateway,
                            skill: skill,
                          ),
                        ),
                      ),
                    );
                    if (removed == true) await load();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        skill.coordinate.isEmpty
                            ? skill.path
                            : skill.coordinate,
                        style: TextStyle(
                          fontFamily: SkillsTokens.monoFamily,
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _libraryProvenanceChip(context, skill.provenance),
                    if (skill.provenance == LibraryProvenance.external)
                      StatusChip(
                        label: context.l10n.readOnly,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    StatusChip(
                      label: context.l10n.localTargets(skill.targetCount),
                      color: context.skillsComponents.statusSuccess,
                    ),
                    StatusChip(
                      label: context.l10n.agentsSummary(skill.agents.length),
                      color: context.skillsComponents.statusAccent,
                    ),
                    if (skill.projects.isNotEmpty)
                      StatusChip(
                        label: context.l10n.projectsSummary(
                          skill.projects.length,
                        ),
                        color: context.skillsComponents.statusAccent,
                      ),
                    if (skill.versions.isNotEmpty)
                      StatusChip(
                        label: context.l10n.versionsSummary(
                          skill.versions.length,
                        ),
                        color: skill.versionDivergence
                            ? context.skillsComponents.statusSevere
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    if (skill.versionDivergence)
                      StatusChip(
                        label: context.l10n.versionDivergence,
                        color: context.skillsComponents.statusSevere,
                      ),
                    _installationHealthChip(context, skill.health),
                    SkillRiskChip(risk: skill.riskAssessment),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (skill.provenance == LibraryProvenance.hub &&
                  state != UpdateState.unknown)
                StatusChip(
                  label: _updateLabel(context, state),
                  color: state == UpdateState.available
                      ? context.skillsComponents.statusSevere
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              if (skill.provenance == LibraryProvenance.hub &&
                  state == UpdateState.available) ...[
                const SizedBox(width: 8),
                SecondaryCapsuleButton(
                  label: context.l10n.update,
                  onPressed: operating ? null : () => update(skill),
                ),
              ],
              if (skill.provenance != LibraryProvenance.external) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: context.l10n.manageTargets,
                  child: Semantics(
                    label: context.l10n.manageTargets,
                    button: true,
                    child: SkillsButton.ghost(
                      width: 38,
                      height: 38,
                      padding: EdgeInsets.zero,
                      enabled: !operating,
                      onPressed: () => manage(skill),
                      child: Icon(
                        Icons.tune,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('library-skeleton'),
    itemCount: 5,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: context.skillsComponents.cardRest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SkillsSkeletonBox(height: 42, width: 42, borderRadius: 12),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkillsSkeletonBox(height: 15, width: 180),
                  SizedBox(height: 9),
                  SkillsSkeletonBox(height: 11, width: 280),
                ],
              ),
            ),
            SizedBox(width: 16),
            SkillsSkeletonBox(height: 32, width: 88, borderRadius: 999),
          ],
        ),
      ),
    ),
  );
}

class _ExternalAdoptionDialog extends StatefulWidget {
  const _ExternalAdoptionDialog({required this.gateway, required this.plan});

  final SkillsGateway gateway;
  final ExternalAdoptionPlan plan;

  @override
  State<_ExternalAdoptionDialog> createState() =>
      _ExternalAdoptionDialogState();
}

class _ExternalAdoptionDialogState extends State<_ExternalAdoptionDialog> {
  HubContentMatch? selectedMatch;
  bool operating = false;
  Object? error;

  ExternalAdoptionPlan? get selectedPlan {
    final match = selectedMatch;
    if (match != null) return widget.plan.selectHubMatch(match);
    if (widget.plan.matches.isEmpty && widget.plan.canImportLocal) {
      return widget.plan.selectLocalImport();
    }
    return null;
  }

  Future<void> execute() async {
    final plan = selectedPlan;
    if (operating || plan == null) return;
    setState(() {
      operating = true;
      error = null;
    });
    try {
      final result = await widget.gateway.executeExternalAdoption(plan);
      if (mounted) Navigator.pop(context, result);
    } catch (caught) {
      if (mounted) {
        setState(() {
          operating = false;
          error = caught;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMatches = widget.plan.matches.isNotEmpty;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
      title: Text(context.l10n.adoptExternalTitle),
      description: Text(context.l10n.adoptExternalDescription),
      actions: [
        SkillsButton.outline(
          enabled: !operating,
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        SkillsButton(
          enabled: !operating && selectedPlan != null,
          onPressed: execute,
          child: operating
              ? const SizedBox(width: 42, child: SkillsProgress(minHeight: 4))
              : Text(
                  hasMatches
                      ? context.l10n.confirmAdoption
                      : context.l10n.confirmLocalImport,
                ),
        ),
      ],
      child: SizedBox(
        width: 680,
        height: 470,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkillsCard(
              width: double.infinity,
              title: Text(context.l10n.adoptionContentDigest),
              description: SelectableText(
                widget.plan.contentDigest,
                style: const TextStyle(
                  fontFamily: SkillsTokens.monoFamily,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SkillsAlert(
              icon: const Icon(Icons.lock_outline),
              description: Text(context.l10n.adoptionPreservesContent),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              SkillsAlert.destructive(
                icon: const Icon(Icons.error_outline),
                title: Text(context.l10n.adoptionFailed),
                description: Text(_failureCopy(context, error!).message),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              hasMatches
                  ? context.l10n.hubContentMatches
                  : context.l10n.importAsLocal,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hasMatches
                  ? ListView.separated(
                      itemCount: widget.plan.matches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final match = widget.plan.matches[index];
                        final selected = identical(selectedMatch, match);
                        return SkillsButton.outline(
                          width: double.infinity,
                          height: 86,
                          onPressed: operating
                              ? null
                              : () => setState(() => selectedMatch = match),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? context.skillsComponents.statusAccent
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 560,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      match.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.hubMatchSource(match.source),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      context.l10n.hubMatchVersion(
                                        match.immutableVersion,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: SkillsTokens.monoFamily,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : SkillsCard(
                      width: double.infinity,
                      title: Text(context.l10n.importAsLocal),
                      description: Text(context.l10n.importAsLocalDescription),
                      footer: Text(
                        context.l10n.exportLocalSkillDescription,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            if (hasMatches && selectedMatch == null)
              Text(
                context.l10n.chooseHubMatch,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LocalDetailScreen extends StatefulWidget {
  const LocalDetailScreen({
    super.key,
    required this.gateway,
    required this.skill,
  });
  final SkillsGateway gateway;
  final InstalledSkill skill;
  @override
  State<LocalDetailScreen> createState() => _LocalDetailScreenState();
}

class _LocalDetailScreenState extends State<LocalDetailScreen> {
  late InstalledSkill skill;
  SkillDetail? detail;
  Object? error;
  String? selectedFilePath;
  bool managing = false;
  bool updating = false;
  bool adopting = false;
  bool installingMore = false;
  bool exporting = false;
  CommandResult? result;
  @override
  void initState() {
    super.initState();
    skill = widget.skill;
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      error = null;
      selectedFilePath = null;
    });
    try {
      detail = await widget.gateway.loadLocalDetail(skill);
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() {});
  }

  Future<void> manage() async {
    if (managing || skill.provenance == LibraryProvenance.external) return;
    setState(() {
      managing = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightTargetManagement(
        skill,
        skill.targets,
      );
      if (!mounted) return;
      final execution = await showSkillsDialog<TargetManagementExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _TargetManagementDialog(gateway: widget.gateway, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        final projects = await widget.gateway.loadAddedProjects();
        final entries = await widget.gateway.listInstalled(projects: projects);
        final refreshed = entries.where(
          (entry) => entry.identity == skill.identity,
        );
        if (!mounted) return;
        if (refreshed.isEmpty) {
          Navigator.pop(context, true);
          return;
        }
        skill = refreshed.first;
        await load();
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => managing = false);
  }

  Future<void> update() async {
    if (updating || skill.provenance != LibraryProvenance.hub) return;
    setState(() {
      updating = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightUpdate(skill, skill.targets);
      if (!mounted) return;
      final execution = await showSkillsDialog<UpdateExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UpdatePlanDialog(
          gateway: widget.gateway,
          skill: skill,
          plan: plan,
        ),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        final projects = await widget.gateway.loadAddedProjects();
        final entries = await widget.gateway.listInstalled(projects: projects);
        final refreshed = entries.where(
          (entry) => entry.identity == skill.identity,
        );
        if (refreshed.isNotEmpty) {
          skill = refreshed.first;
          await load();
        }
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => updating = false);
  }

  Future<void> adopt() async {
    if (adopting || skill.provenance != LibraryProvenance.external) return;
    setState(() {
      adopting = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightExternalAdoption(skill);
      if (!mounted) return;
      final adopted = await showSkillsDialog<ExternalAdoptionResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _ExternalAdoptionDialog(gateway: widget.gateway, plan: plan),
      );
      if (adopted != null) {
        await _refreshManagedSkill(
          coordinate: adopted.coordinate,
          targetPath: adopted.target.path,
        );
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => adopting = false);
  }

  Future<void> installMore() async {
    final currentDetail = detail;
    if (installingMore ||
        skill.provenance == LibraryProvenance.external ||
        currentDetail == null) {
      return;
    }
    setState(() {
      installingMore = true;
      result = null;
    });
    final operation = InstallOperationController();
    try {
      final values = await Future.wait([
        widget.gateway.inspectAgents(),
        widget.gateway.loadAddedProjects(),
        widget.gateway.loadRiskPolicy(),
      ]);
      if (!mounted) return;
      var projects = values[1] as List<AddedProject>;
      await showSkillsDialog<_InstallationPlanOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _InstallationPlanDialog(
          gateway: widget.gateway,
          skill: SkillSummary(
            id: skill.coordinate,
            skillId: skill.coordinate,
            name: skill.name,
            source: currentDetail.source,
            imageUrl: currentDetail.imageUrl,
            installs: 0,
            latestVersion: currentDetail.immutableVersion,
            description: currentDetail.description,
            riskAssessment: skill.riskAssessment,
            localTargetCount: skill.targetCount,
          ),
          detail: currentDetail,
          catalog: values[0] as AgentCatalog,
          initialProjects: projects,
          operation: operation,
          onProjectAdded: (project) {
            projects = [...projects, project];
          },
          riskPolicy: values[2] as PersonalRiskPolicy,
        ),
      );
      if (operation.execution?.hasSuccess ?? false) {
        await _refreshManagedSkill(coordinate: skill.coordinate);
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    } finally {
      operation.dispose();
    }
    if (mounted) setState(() => installingMore = false);
  }

  Future<void> exportLocal() async {
    if (exporting || skill.provenance != LibraryProvenance.local) return;
    setState(() {
      exporting = true;
      result = null;
    });
    try {
      final exported = await widget.gateway.exportLocalSkill(skill);
      if (exported != null) result = exported;
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => exporting = false);
  }

  Future<void> _refreshManagedSkill({
    required String coordinate,
    String? targetPath,
  }) async {
    final projects = await widget.gateway.loadAddedProjects();
    final entries = await widget.gateway.listInstalled(projects: projects);
    final refreshed = entries.where(
      (entry) =>
          entry.coordinate == coordinate &&
          (targetPath == null ||
              entry.targets.any((target) => target.path == targetPath)),
    );
    if (!mounted || refreshed.isEmpty) return;
    skill = refreshed.first;
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n.backToLibrary,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                SkillGlyph(name: skill.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontFamily: SkillsTokens.serifFamily,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SelectableText(
                        skill.path,
                        style: TextStyle(
                          fontFamily: SkillsTokens.monoFamily,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _libraryProvenanceChip(context, skill.provenance),
                const SizedBox(width: 8),
                SkillRiskChip(risk: skill.riskAssessment),
                const SizedBox(width: 8),
                if (skill.provenance == LibraryProvenance.external) ...[
                  StatusChip(
                    label: context.l10n.readOnly,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  SecondaryCapsuleButton(
                    label: context.l10n.bringUnderManagement,
                    icon: Icons.add_link,
                    onPressed: adopting ? null : adopt,
                  ),
                ] else ...[
                  if (skill.provenance == LibraryProvenance.hub) ...[
                    SecondaryCapsuleButton(
                      label: context.l10n.update,
                      icon: Icons.sync,
                      onPressed: updating || managing ? null : update,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Tooltip(
                    message: context.l10n.manageTargets,
                    child: Semantics(
                      label: context.l10n.manageTargets,
                      button: true,
                      child: SkillsButton.ghost(
                        width: 38,
                        height: 38,
                        padding: EdgeInsets.zero,
                        enabled: !managing && !installingMore && !updating,
                        onPressed: manage,
                        child: const Icon(Icons.tune, size: 18),
                      ),
                    ),
                  ),
                  if (detail?.immutableVersion.isNotEmpty ?? false) ...[
                    const SizedBox(width: 8),
                    SecondaryCapsuleButton(
                      label: context.l10n.installMoreTargets,
                      icon: Icons.add_to_photos_outlined,
                      onPressed: installingMore || managing || updating
                          ? null
                          : installMore,
                    ),
                  ],
                  if (skill.provenance == LibraryProvenance.local) ...[
                    const SizedBox(width: 8),
                    SecondaryCapsuleButton(
                      label: context.l10n.exportLocalSkill,
                      icon: Icons.ios_share_outlined,
                      onPressed: exporting ? null : exportLocal,
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (result != null) ...[
              OperationPanel(result: result!),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: Column(
                children: [
                  _InstallationTargetsPanel(skill: skill),
                  const SizedBox(height: 14),
                  if (detail?.hasExecutableContent ?? false) ...[
                    _RiskNotice(detail: detail!),
                    const SizedBox(height: 14),
                  ],
                  Expanded(
                    child: error != null
                        ? EmptyState(
                            title: context.l10n.localReadFailed,
                            message: context.l10n.localReadFailedMessage,
                            action: PrimaryCapsuleButton(
                              label: context.l10n.retry,
                              onPressed: load,
                            ),
                          )
                        : detail == null
                        ? const Center(child: CircularProgressIndicator())
                        : _LocalSkillDocuments(
                            detail: detail!,
                            selectedFilePath: selectedFilePath,
                            onSelected: (path) =>
                                setState(() => selectedFilePath = path),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InstallationTargetsPanel extends StatelessWidget {
  const _InstallationTargetsPanel({required this.skill});

  final InstalledSkill skill;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.knownInstallationTargets,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final (index, target) in skill.targets.indexed) ...[
          if (index > 0)
            SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.targetSummary(
                        target.scope == InstallationScope.user
                            ? context.l10n.userScope
                            : context.l10n.projectScope,
                        _agentDisplayLabel(target.agent),
                        target.version.isEmpty
                            ? context.l10n.unversioned
                            : target.version,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      target.path,
                      style: TextStyle(
                        fontFamily: SkillsTokens.monoFamily,
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(
                label: _installationModeLabel(context, target.mode),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              StatusChip(
                label: _receiptStateLabel(context, target.receiptState),
                color: target.receiptState == ReceiptState.present
                    ? context.skillsComponents.statusSuccess
                    : context.skillsComponents.statusAttention,
              ),
              const SizedBox(width: 7),
              _installationHealthChip(context, target.health),
            ],
          ),
        ],
      ],
    ),
  );
}

class _LocalSkillDocuments extends StatelessWidget {
  const _LocalSkillDocuments({
    required this.detail,
    required this.selectedFilePath,
    required this.onSelected,
  });

  final SkillDetail detail;
  final String? selectedFilePath;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final supportingFiles = detail.files
        .where((file) => file.kind != 'instructions' && file.path != 'SKILL.md')
        .toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedFilePath ?? context.l10n.instructionsTab,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(child: _document(context)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 260,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionEyebrow(context.l10n.supportingFiles),
                const SizedBox(height: 10),
                SkillsButton.ghost(
                  width: double.infinity,
                  mainAxisAlignment: MainAxisAlignment.start,
                  backgroundColor: selectedFilePath == null
                      ? Theme.of(context).colorScheme.surfaceContainer
                      : null,
                  onPressed: () => onSelected(null),
                  child: Text(context.l10n.instructionsTab),
                ),
                SkillsSeparator.horizontal(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: ListView(
                    children: supportingFiles
                        .map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SkillsButton.ghost(
                              width: double.infinity,
                              mainAxisAlignment: MainAxisAlignment.start,
                              backgroundColor: selectedFilePath == file.path
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer
                                  : null,
                              onPressed: () => onSelected(file.path),
                              leading: Icon(
                                file.executable
                                    ? Icons.terminal
                                    : file.binary
                                    ? Icons.data_object
                                    : Icons.description_outlined,
                                size: 15,
                                color: file.executable
                                    ? context.skillsComponents.statusAttention
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .72),
                              ),
                              child: Flexible(
                                child: Text(
                                  file.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: SkillsTokens.monoFamily,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _document(BuildContext context) {
    if (selectedFilePath == null) {
      return SkillMarkdownView(data: detail.markdown);
    }
    final file = detail.files.firstWhere(
      (candidate) => candidate.path == selectedFilePath,
    );
    if (file.binary || file.contents.isEmpty) {
      return Center(
        child: Text(
          context.l10n.fileContentUnavailable,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final content = file.path.toLowerCase().endsWith('.md')
        ? SkillMarkdownView(data: file.contents)
        : SingleChildScrollView(
            child: SelectableText(
              file.contents,
              style: const TextStyle(fontFamily: SkillsTokens.monoFamily),
            ),
          );
    if (!file.truncated) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.fileContentTruncated,
          style: TextStyle(color: context.skillsComponents.statusAttention),
        ),
        const SizedBox(height: 8),
        Expanded(child: content),
      ],
    );
  }
}
