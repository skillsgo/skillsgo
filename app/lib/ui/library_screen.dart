/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives and top-level navigation, HugeIcons, multi_dropdown, the shared destination rail, ProjectIdentityIcon, Riverpod Library state, gateway mutations, localization, and shared operation dialogs.
 * [OUTPUT]: Provides the unified Library destination with fixed All and Global navigation, fixed header/footer section dividers, an independently scrollable compact Added Project rail, a pinned multi-directory Add Project action, a concise project-empty path to Discover, location-scoped one-confirmation Batch Takeover with next-frame progress and aggregate results, reminder-aware update and safety summaries, cold/stale loading UI, composable update, multi-Agent filtering, compact target-derived installation scope with hover details, animated Local detail with a sticky compact toolbar, exact External removal, export, and installation-target views.
 * [POS]: Serves as the complete Library feature view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

enum _LibraryLocationKind { all, global, project }

class _LibraryLocationRoute {
  const _LibraryLocationRoute._(this.kind, [this.projectId]);

  static const all = _LibraryLocationRoute._(_LibraryLocationKind.all);
  static const global = _LibraryLocationRoute._(_LibraryLocationKind.global);

  factory _LibraryLocationRoute.project(String projectId) =>
      _LibraryLocationRoute._(_LibraryLocationKind.project, projectId);

  final _LibraryLocationKind kind;
  final String? projectId;

  @override
  bool operator ==(Object other) =>
      other is _LibraryLocationRoute &&
      other.kind == kind &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(kind, projectId);
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key,
    required this.gateway,
    required this.onBrowseSkills,
  });
  final SkillsGateway gateway;
  final VoidCallback onBrowseSkills;
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  Object? actionError;
  bool checking = false;
  Object? updateCheckError;
  Map<String, UpdateState> updates = const {};
  CommandResult? result;
  final operatingSkills = <String>{};
  final scrollController = ScrollController();
  final librarySearchController = TextEditingController();
  final librarySearchFocusNode = FocusNode();
  final selectedSkillKeys = <String>{};
  bool updatesOnly = false;
  final selectedAgents = <String>{};
  _LibraryLocationRoute selectedLocation = _LibraryLocationRoute.all;
  bool addingProject = false;
  bool takingOver = false;
  InstalledSkill? selectedDetailSkill;
  ReminderSettings? reminderSettings;
  bool _reminderInitializationStarted = false;
  bool detailTransitioning = false;
  late final AnimationController detailTransition;

  @override
  void initState() {
    super.initState();
    detailTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    detailTransition.dispose();
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
    setState(() {
      final currentKeys = (skills ?? const <InstalledSkill>[])
          .map(_librarySelectionKey)
          .toSet();
      selectedSkillKeys.removeWhere((key) => !currentKeys.contains(key));
      selectedAgents.removeWhere((agent) => !_agents.contains(agent));
      if (selectedLocation.kind == _LibraryLocationKind.project &&
          _selectedProject == null) {
        selectedLocation = _LibraryLocationRoute.all;
      }
    });
  }

  List<InstalledSkill> get _selectedSkills {
    final selected = selectedSkillKeys;
    return (skills ?? const <InstalledSkill>[])
        .where((skill) => selected.contains(_librarySelectionKey(skill)))
        .toList(growable: false);
  }

  void _toggleSkillSelection(InstalledSkill skill, bool selected) {
    setState(() {
      final key = _librarySelectionKey(skill);
      if (selected) {
        selectedSkillKeys.add(key);
      } else {
        selectedSkillKeys.remove(key);
      }
    });
  }

  void _toggleVisibleSelection(
    List<InstalledSkill> visibleSkills,
    bool selected,
  ) {
    setState(() {
      final visibleKeys = visibleSkills.map(_librarySelectionKey);
      if (selected) {
        selectedSkillKeys.addAll(visibleKeys);
      } else {
        selectedSkillKeys.removeAll(visibleKeys);
      }
    });
  }

  Future<void> _updateSelectedSkills() async {
    final selected = _selectedSkills
        .where(
          (skill) => updates[_libraryUpdateKey(skill)] == UpdateState.available,
        )
        .toList(growable: false);
    for (final skill in selected) {
      if (!mounted) return;
      await update(skill);
    }
    if (mounted) setState(selectedSkillKeys.clear);
  }

  Future<void> _manageSelectedSkills() async {
    final selected = _selectedSkills;
    for (final skill in selected) {
      if (!mounted) return;
      await manage(skill);
    }
    if (mounted) setState(selectedSkillKeys.clear);
  }

  AddedProject? get _selectedProject {
    final id = selectedLocation.projectId;
    if (id == null) return null;
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
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

  Future<void> _addProject() async {
    if (addingProject) return;
    setState(() {
      addingProject = true;
      actionError = null;
    });
    try {
      final addedProjects = await widget.gateway.addProjects();
      if (addedProjects.isEmpty || !mounted) return;
      await load();
      if (!mounted) return;
      setState(() {
        selectedLocation =
            addedProjects.length == 1 &&
                projects.any((item) => item.id == addedProjects.single.id)
            ? _LibraryLocationRoute.project(addedProjects.single.id)
            : _LibraryLocationRoute.all;
      });
    } on Object catch (caught) {
      if (mounted) setState(() => actionError = caught);
    } finally {
      if (mounted) setState(() => addingProject = false);
    }
  }

  Future<void> _takeoverExistingSkills() async {
    if (takingOver) return;
    final selectedProject = _selectedProject;
    if (selectedLocation.kind == _LibraryLocationKind.project &&
        selectedProject == null) {
      return;
    }
    final includeUser = selectedLocation.kind != _LibraryLocationKind.project;
    final projectRoots = switch (selectedLocation.kind) {
      _LibraryLocationKind.all =>
        projects
            .where((project) => project.isAccessible)
            .map((project) => project.path)
            .toList(growable: false),
      _LibraryLocationKind.global => const <String>[],
      _LibraryLocationKind.project => [selectedProject!.path],
    };
    final confirmed = await showSkillsDialog<bool>(
      context: context,
      builder: (context) => SkillsDialog(
        title: Text(context.l10n.batchTakeoverTitle),
        description: Text(context.l10n.batchTakeoverDescription),
        actions: [
          SkillsButton.outline(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          SkillsButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.batchTakeoverConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      takingOver = true;
      actionError = null;
    });
    try {
      final takeover = await widget.gateway.takeoverExistingSkills(
        includeUser: includeUser,
        projectRoots: projectRoots,
      );
      await load();
      if (!mounted) return;
      await showSkillsDialog<void>(
        context: context,
        builder: (context) => SkillsDialog(
          title: Text(context.l10n.batchTakeoverResultTitle),
          description: Text(
            context.l10n.batchTakeoverSummary(
              takeover.takenOver,
              takeover.skipped,
            ),
          ),
          actions: [
            SkillsButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.batchTakeoverClose),
            ),
          ],
        ),
      );
    } on Object catch (caught) {
      if (mounted) setState(() => actionError = caught);
    } finally {
      if (mounted) setState(() => takingOver = false);
    }
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

  Future<void> _initializeReminders() async {
    final settings = await widget.gateway.loadReminderSettings();
    if (!mounted) return;
    setState(() => reminderSettings = settings);
    if (settings.updateAvailable) await checkUpdates();
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

  Future<void> _openDetail(InstalledSkill skill) async {
    setState(() {
      selectedDetailSkill = skill;
      detailTransitioning = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      detailTransition.value = 1;
    } else {
      await detailTransition.forward(from: 0);
    }
    if (!mounted || selectedDetailSkill?.inventoryKey != skill.inventoryKey) {
      return;
    }
    setState(() => detailTransitioning = false);
  }

  Future<void> _closeDetail() async {
    if (selectedDetailSkill == null) return;
    setState(() => detailTransitioning = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      detailTransition.value = 0;
    } else {
      await detailTransition.reverse();
    }
    if (!mounted) return;
    setState(() {
      selectedDetailSkill = null;
      detailTransitioning = false;
    });
  }

  Future<void> _closeRemovedDetail() async {
    await _closeDetail();
    await load();
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

  List<InstalledSkill> get _visibleSkills {
    final current = skills ?? const <InstalledSkill>[];
    final visible = <InstalledSkill>[];
    for (final skill in current) {
      if (updatesOnly &&
          updates[_libraryUpdateKey(skill)] != UpdateState.available) {
        continue;
      }
      if (selectedAgents.isNotEmpty &&
          !skill.targets.any(
            (target) => selectedAgents.contains(target.agent),
          )) {
        continue;
      }
      if (selectedLocation.kind == _LibraryLocationKind.global &&
          !skill.targets.any(
            (target) => target.scope == InstallationScope.user,
          )) {
        continue;
      }
      final project = _selectedProject;
      if (project != null &&
          !skill.targets.any((target) => target.projectRoot == project.path)) {
        continue;
      }
      final query = librarySearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final searchable = [
          skill.name,
          skill.description,
          skill.skillId,
          ...skill.agents,
          ...skill.projects,
          ...skill.versions,
        ].join('\n').toLowerCase();
        if (!searchable.contains(query)) continue;
      }
      visible.add(skill);
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    if (skills != null && !_reminderInitializationStarted) {
      _reminderInitializationStarted = true;
      unawaited(_initializeReminders());
    }
    final selected = _selectedSkills;
    final visibleSkills = _visibleSkills;
    final visibleSelectedCount = visibleSkills
        .where(
          (skill) => selectedSkillKeys.contains(_librarySelectionKey(skill)),
        )
        .length;
    final allVisibleSelected =
        visibleSkills.isNotEmpty &&
        visibleSelectedCount == visibleSkills.length;
    final someVisibleSelected = visibleSelectedCount > 0 && !allVisibleSelected;
    final updateableSelected = selected.where(
      (skill) => updates[_libraryUpdateKey(skill)] == UpdateState.available,
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final detailSkill = selectedDetailSkill;
    final availableUpdateCount = updates.values
        .where((state) => state == UpdateState.available)
        .length;
    final securityAdvisoryCount = (skills ?? const <InstalledSkill>[])
        .where(
          (skill) =>
              skill.riskAssessment == SkillRiskAssessment.high ||
              skill.riskAssessment == SkillRiskAssessment.critical,
        )
        .length;
    return SkillsDestinationLayout(
      rail: SkillsSideRail<_LibraryLocationRoute>(
        key: const Key('library-location-rail'),
        semanticLabel: context.l10n.libraryNavigation,
        selected: selectedLocation,
        onSelected: (location) => setState(() => selectedLocation = location),
        sectionDividers: true,
        fixedItems: [
          SkillsRailItem(
            value: _LibraryLocationRoute.all,
            label: context.l10n.allSkills,
            icon: HugeIcons.strokeRoundedLayers01,
          ),
          SkillsRailItem(
            value: _LibraryLocationRoute.global,
            label: context.l10n.userScope,
            icon: HugeIcons.strokeRoundedUser,
          ),
        ],
        items: [
          for (var index = 0; index < projects.length; index++)
            SkillsRailItem(
              value: _LibraryLocationRoute.project(projects[index].id),
              label: projects[index].isAccessible
                  ? projects[index].name
                  : context.l10n.projectRailUnavailable(projects[index].name),
              compact: true,
              leading: ProjectIdentityIcon(project: projects[index], size: 18),
            ),
        ],
        footer: _LibraryAddProjectAction(
          adding: addingProject,
          onPressed: () => unawaited(_addProject()),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: detailSkill != null && !detailTransitioning,
            child: IgnorePointer(
              ignoring: detailSkill != null,
              child: ExcludeFocus(
                excluding: detailSkill != null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reminderSettings?.updateAvailable == true &&
                        availableUpdateCount > 0) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        key: const Key('library-update-reminder'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => updatesOnly = true),
                        child: SkillsAlert(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedDownload04,
                            strokeWidth: 1.8,
                          ),
                          title: Text(
                            context.l10n.availableUpdatesReminder(
                              availableUpdateCount,
                            ),
                          ),
                          description: Text(context.l10n.openAvailableUpdates),
                        ),
                      ),
                    ],
                    if (reminderSettings?.securityAdvisory == true &&
                        securityAdvisoryCount > 0) ...[
                      const SizedBox(height: 14),
                      SkillsAlert.destructive(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          strokeWidth: 1.8,
                        ),
                        title: Text(
                          context.l10n.securityAdvisoriesReminder(
                            securityAdvisoryCount,
                          ),
                        ),
                        description: Text(context.l10n.reviewInstalledSkills),
                      ),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 14),
                      OperationPanel(result: result!),
                    ],
                    if (error != null && skills != null) ...[
                      const SizedBox(height: 14),
                      SkillsAlert(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedRefreshCwOff,
                          strokeWidth: 1.8,
                        ),
                        title: Text(_failureCopy(context, error!).title),
                        description: Text(
                          _failureCopy(context, error!).message,
                        ),
                      ),
                    ],
                    if (updateCheckError != null) ...[
                      const SizedBox(height: 14),
                      SkillsAlert(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCloudOff,
                          strokeWidth: 1.8,
                        ),
                        title: Text(
                          _failureCopy(context, updateCheckError!).title,
                        ),
                        description: Text(
                          _failureCopy(context, updateCheckError!).message,
                        ),
                      ),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: SizedBox(
                            width: 44,
                            height: 45,
                            child: Align(
                              alignment: const Alignment(
                                0,
                                skillSearchLeaderboardContentAlignment,
                              ),
                              child: Transform.translate(
                                offset: const Offset(0, 2),
                                child: Tooltip(
                                  message: allVisibleSelected
                                      ? context.l10n.clearCurrentResultSelection
                                      : context.l10n.selectCurrentResults,
                                  child: SkillsCheckbox(
                                    key: const Key('library-select-visible'),
                                    value: allVisibleSelected,
                                    indeterminate: someVisibleSelected,
                                    enabled: visibleSkills.isNotEmpty,
                                    onChanged: (value) =>
                                        _toggleVisibleSelection(
                                          visibleSkills,
                                          value,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SkillSearchField(
                            key: const Key('library-search'),
                            controller: librarySearchController,
                            focusNode: librarySearchFocusNode,
                            onSubmitted: (_) {},
                            onCleared: () =>
                                setState(librarySearchController.clear),
                            onChanged: (_) => setState(() {}),
                            height: 45,
                            appearance: SkillSearchAppearance.leaderboard,
                            hintText: context.l10n.searchLibrary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SecondaryCapsuleButton(
                          key: const Key('library-batch-takeover'),
                          label: takingOver
                              ? context.l10n.batchTakeoverPending
                              : context.l10n.batchTakeoverAction,
                          icon: HugeIcons.strokeRoundedFolderTransfer,
                          onPressed: takingOver
                              ? null
                              : () => unawaited(_takeoverExistingSkills()),
                        ),
                        const SizedBox(width: 4),
                        _LibraryScopeToggle(
                          updatesOnly: updatesOnly,
                          onChanged: (value) =>
                              setState(() => updatesOnly = value),
                        ),
                        const SizedBox(width: 4),
                        _LibraryAgentMultiFilter(
                          key: const Key('library-agent-filter'),
                          agents: _agents,
                          selectedAgents: selectedAgents,
                          agentLabel: _agentLabel,
                          onChanged: (agents) => setState(() {
                            selectedAgents
                              ..clear()
                              ..addAll(agents);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 28,
            bottom: 18,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _LibrarySelectionBarTransition(
                key: const Key('library-selection-bar-switcher'),
                disableAnimations: disableAnimations,
                child: selected.isEmpty
                    ? null
                    : _LibrarySelectionBar(
                        key: const ValueKey('selection-bar-visible'),
                        selectedCount: selected.length,
                        updateableCount: updateableSelected.length,
                        operating: selected.any(
                          (skill) => operatingSkills.contains(skill.name),
                        ),
                        onClear: () => setState(selectedSkillKeys.clear),
                        onUpdate: _updateSelectedSkills,
                        onManage: _manageSelectedSkills,
                        manageLabel:
                            selected.every(
                              (skill) =>
                                  skill.provenance ==
                                  LibraryProvenance.external,
                            )
                            ? context.l10n.remove
                            : context.l10n.manageTargets,
                      ),
              ),
            ),
          ),
          if (detailSkill != null)
            SlideTransition(
              key: const Key('library-detail-surface'),
              position: disableAnimations
                  ? const AlwaysStoppedAnimation(Offset.zero)
                  : Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: detailTransition,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeOutCubic,
                      ),
                    ),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: LocalDetailScreen(
                  gateway: widget.gateway,
                  skill: detailSkill,
                  projects: projects,
                  initialUpdateState:
                      updates[_libraryUpdateKey(detailSkill)] ??
                      UpdateState.unknown,
                  onBack: () => unawaited(_closeDetail()),
                  onRemoved: _closeRemovedDetail,
                ),
              ),
            ),
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
          title: context.l10n.emptyProjectTitle,
          action: PrimaryCapsuleButton(
            label: context.l10n.browseSkills,
            onPressed: widget.onBrowseSkills,
          ),
        );
      }
      return EmptyState(
        title: context.l10n.libraryEmpty,
        message: context.l10n.libraryEmptyMessage,
      );
    }
    final groups = _groupInstalledSkills(context, _visibleSkills);
    return ListView.separated(
      key: const ValueKey('library-results'),
      controller: scrollController,
      padding: EdgeInsets.only(bottom: selectedSkillKeys.isEmpty ? 0 : 72),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 22),
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return _InstalledSkillGroup(
          group: group,
          projects: projects,
          agentLabel: _agentLabel,
          onOpen: _openDetail,
          selectedSkillKeys: selectedSkillKeys,
          onSelectionChanged: _toggleSkillSelection,
        );
      },
    );
  }
}

class _InstalledSkillGroupData {
  const _InstalledSkillGroupData({
    required this.source,
    required this.label,
    required this.skills,
  });

  final String source;
  final String label;
  final List<InstalledSkill> skills;
}

List<_InstalledSkillGroupData> _groupInstalledSkills(
  BuildContext context,
  List<InstalledSkill> skills,
) {
  final managed = <String, List<InstalledSkill>>{};
  final external = <InstalledSkill>[];
  for (final skill in skills) {
    if (skill.provenance == LibraryProvenance.external) {
      external.add(skill);
      continue;
    }
    final source = _installedSourceLabel(context, skill);
    managed.putIfAbsent(source, () => <InstalledSkill>[]).add(skill);
  }
  final compactNameCounts = <String, int>{};
  for (final source in managed.keys) {
    final compact = _compactRepositorySource(source).toLowerCase();
    compactNameCounts.update(compact, (count) => count + 1, ifAbsent: () => 1);
  }
  final groups =
      managed.entries.map((entry) {
        final compact = _compactRepositorySource(entry.key);
        final hasCollision = compactNameCounts[compact.toLowerCase()]! > 1;
        return _InstalledSkillGroupData(
          source: entry.key,
          label: hasCollision ? entry.key : compact,
          skills: entry.value,
        );
      }).toList()..sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
  if (external.isNotEmpty) {
    groups.add(
      _InstalledSkillGroupData(
        source: context.l10n.externalInstallation,
        label: context.l10n.externalInstallation,
        skills: external,
      ),
    );
  }
  return groups;
}

String _compactRepositorySource(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1 && parts.first.contains('.')) {
    return parts.skip(1).join('/');
  }
  return source;
}

class _InstalledSkillGroup extends StatelessWidget {
  const _InstalledSkillGroup({
    required this.group,
    required this.projects,
    required this.agentLabel,
    required this.onOpen,
    required this.selectedSkillKeys,
    required this.onSelectionChanged,
  });

  final _InstalledSkillGroupData group;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;
  final ValueChanged<InstalledSkill> onOpen;
  final Set<String> selectedSkillKeys;
  final void Function(InstalledSkill, bool) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 11, bottom: 9),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Center(
                  child: RepositoryAvatar(
                    source: group.source,
                    imageUrl: _repositoryAvatarUrl(group.source),
                    size: 42,
                    borderRadius: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.display.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: '${group.skills.length}'),
              const Spacer(),
            ],
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < group.skills.length; index++) ...[
              if (index > 0) const SkillsSeparator.horizontal(),
              _InstalledSkillRow(
                skill: group.skills[index],
                projects: projects,
                selected: selectedSkillKeys.contains(
                  _librarySelectionKey(group.skills[index]),
                ),
                agentLabel: agentLabel,
                onOpen: () => onOpen(group.skills[index]),
                onSelectionChanged: (selected) =>
                    onSelectionChanged(group.skills[index], selected),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String? _repositoryAvatarUrl(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length < 3 || parts.first.toLowerCase() != 'github.com') {
    return null;
  }
  return 'https://github.com/${Uri.encodeComponent(parts[1])}.png?size=84';
}

class _InstalledSkillRow extends StatelessWidget {
  const _InstalledSkillRow({
    required this.skill,
    required this.projects,
    required this.selected,
    required this.agentLabel,
    required this.onOpen,
    required this.onSelectionChanged,
  });

  final InstalledSkill skill;
  final List<AddedProject> projects;
  final bool selected;
  final String Function(String) agentLabel;
  final VoidCallback onOpen;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainer : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: SkillsCheckbox(
                    key: ValueKey('library-select-${skill.inventoryKey}'),
                    value: selected,
                    onChanged: onSelectionChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skill.description.trim().isEmpty
                            ? _installationCoverageLabel(
                                context,
                                skill,
                                projects,
                              )
                            : skill.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LibraryInstallationScopeSummary(
                    skill: skill,
                    projects: projects,
                    agentLabel: agentLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryInstallationScopeSummary extends StatelessWidget {
  const _LibraryInstallationScopeSummary({
    required this.skill,
    required this.projects,
    required this.agentLabel,
  });

  final InstalledSkill skill;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    final groups = _installationScopeGroups(skill, projects);
    if (groups.isEmpty) return const SizedBox.shrink();
    final user = groups.where((group) => group.project == null).firstOrNull;
    final projectGroups = groups
        .where((group) => group.project != null)
        .toList(growable: false);
    return Semantics(
      label: groups.map((group) => group.semanticLabel(agentLabel)).join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: 39,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 18,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: user == null
                    ? const SizedBox.shrink()
                    : _ScopeAgentRow(
                        agents: user.agents,
                        agentLabel: agentLabel,
                      ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 18,
              child: _ProjectScopeLine(
                groups: projectGroups,
                agentLabel: agentLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectScopeLine extends StatelessWidget {
  const _ProjectScopeLine({required this.groups, required this.agentLabel});

  final List<_InstallationScopeGroup> groups;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (groups.isEmpty) return const SizedBox.shrink();
    final visible = groups.take(2).toList(growable: false);
    final hidden = groups.length - visible.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant,
              ),
            ),
          Flexible(
            child: _ProjectScopeSegment(
              group: visible[index],
              agentLabel: agentLabel,
            ),
          ),
        ],
        if (hidden > 0) ...[
          const SizedBox(width: 7),
          Text(
            '+$hidden',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _ProjectScopeSegment extends StatelessWidget {
  const _ProjectScopeSegment({required this.group, required this.agentLabel});

  final _InstallationScopeGroup group;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    final project = group.project!;
    return _ProjectScopePopover(
      project: project,
      agents: group.agents,
      agentLabel: agentLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProjectIdentityIcon(project: project, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              project.name,
              key: ValueKey('library-scope-project-${project.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeAgentRow extends StatelessWidget {
  const _ScopeAgentRow({required this.agents, required this.agentLabel});

  final List<String> agents;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    const gap = 5.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleCount = constraints.maxWidth.isFinite
            ? math.max(
                1,
                math.min(
                  agents.length,
                  ((constraints.maxWidth - 30 + gap) / (size + gap)).floor(),
                ),
              )
            : agents.length;
        final hiddenCount = agents.length - visibleCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visibleCount; index++) ...[
              if (index > 0) const SizedBox(width: gap),
              Tooltip(
                message: agentLabel(agents[index]),
                child: AgentLogo(
                  agentId: agents[index],
                  displayName: agentLabel(agents[index]),
                  size: size,
                ),
              ),
            ],
            if (hiddenCount > 0) ...[
              const SizedBox(width: 7),
              Text(
                '+$hiddenCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProjectScopePopover extends StatelessWidget {
  const _ProjectScopePopover({
    required this.project,
    required this.agents,
    required this.agentLabel,
    required this.child,
  });

  final AddedProject project;
  final List<String> agents;
  final String Function(String) agentLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return JustTooltip(
      direction: TooltipDirection.bottom,
      alignment: TooltipAlignment.endTargetCenter,
      offset: 6,
      screenMargin: 16,
      enableTap: false,
      enableHover: true,
      interactive: true,
      waitDuration: const Duration(milliseconds: 80),
      animation: MediaQuery.disableAnimationsOf(context)
          ? TooltipAnimation.none
          : TooltipAnimation.fade,
      animationDuration: const Duration(milliseconds: 100),
      theme: JustTooltipTheme(
        backgroundColor: context.skillsComponents.controlRest,
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderColor: context.skillsComponents.controlBorder,
        borderWidth: 1,
        textStyle: TextStyle(color: scheme.onSurface),
        elevation: 0,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        showArrow: true,
        arrowBaseWidth: 12,
        arrowLength: 6,
      ),
      tooltipBuilder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(380, MediaQuery.sizeOf(context).width - 52),
          maxHeight: 280,
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.pathLabel,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              _CopyableProjectPath(project: project),
              const SizedBox(height: 8),
              Text(
                context.l10n.agents,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              for (final agent in agents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AgentLogo(
                        agentId: agent,
                        displayName: agentLabel(agent),
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        agentLabel(agent),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}

class _CopyableProjectPath extends StatefulWidget {
  const _CopyableProjectPath({required this.project});

  final AddedProject project;

  @override
  State<_CopyableProjectPath> createState() => _CopyableProjectPathState();
}

class _CopyableProjectPathState extends State<_CopyableProjectPath> {
  Timer? _feedbackTimer;
  bool _copied = false;

  Future<void> _copy() async {
    _feedbackTimer?.cancel();
    setState(() => _copied = true);
    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
    await Clipboard.setData(ClipboardData(text: widget.project.path));
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.project.path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 5),
        IconButton(
          key: ValueKey(
            _copied
                ? 'copy-project-path-copied-${widget.project.id}'
                : 'copy-project-path-${widget.project.id}',
          ),
          tooltip: _copied
              ? context.l10n.projectPathCopied
              : context.l10n.copyProjectPath,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 26, height: 26),
          padding: EdgeInsets.zero,
          onPressed: _copy,
          icon: AnimatedSwitcher(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 140),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: HugeIcon(
              key: ValueKey(_copied),
              icon: _copied
                  ? HugeIcons.strokeRoundedCopyCheck
                  : HugeIcons.strokeRoundedCopy01,
              size: 15,
              strokeWidth: 1.7,
              color: _copied ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallationScopeGroup {
  const _InstallationScopeGroup({required this.project, required this.agents});

  final AddedProject? project;
  final List<String> agents;

  String semanticLabel(String Function(String) agentLabel) =>
      '${project?.name ?? 'User scope'}: ${agents.map(agentLabel).join(', ')}';
}

List<_InstallationScopeGroup> _installationScopeGroups(
  InstalledSkill skill,
  List<AddedProject> projects,
) {
  final userAgents = <String>{};
  final projectAgents = <String, Set<String>>{};
  for (final target in skill.targets) {
    if (target.scope == InstallationScope.user) {
      userAgents.add(target.agent);
    } else {
      projectAgents
          .putIfAbsent(target.projectRoot, () => <String>{})
          .add(target.agent);
    }
  }
  AddedProject projectFor(String root) =>
      projects.where((project) => project.path == root).firstOrNull ??
      AddedProject(
        id: root,
        name: p.basename(root),
        path: root,
        accessState: ProjectAccessState.inaccessible,
      );
  return [
    if (userAgents.isNotEmpty)
      _InstallationScopeGroup(
        project: null,
        agents: userAgents.toList(growable: false),
      ),
    for (final entry in projectAgents.entries)
      _InstallationScopeGroup(
        project: projectFor(entry.key),
        agents: entry.value.toList(growable: false),
      ),
  ];
}

String _librarySelectionKey(InstalledSkill skill) => skill.inventoryKey.isEmpty
    ? '${skill.path}\u0000${skill.name}'
    : skill.inventoryKey;

class _LibrarySelectionBarTransition extends StatefulWidget {
  const _LibrarySelectionBarTransition({
    super.key,
    required this.child,
    required this.disableAnimations,
  });

  final Widget? child;
  final bool disableAnimations;

  @override
  State<_LibrarySelectionBarTransition> createState() =>
      _LibrarySelectionBarTransitionState();
}

class _LibrarySelectionBarTransitionState
    extends State<_LibrarySelectionBarTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _visibleChild;
  late double _target;

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 41,
  );

  @override
  void initState() {
    super.initState();
    _visibleChild = widget.child;
    _target = widget.child == null ? 0 : 1;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
      value: widget.child == null ? 0 : 1,
      vsync: this,
    );
    _controller.addStatusListener(_handleStatusChanged);
  }

  @override
  void didUpdateWidget(_LibrarySelectionBarTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _visibleChild = widget.child;
      _animateTo(1);
    } else if (oldWidget.child != null) {
      _animateTo(0);
    }
  }

  void _animateTo(double target) {
    _target = target;
    if (widget.disableAnimations) {
      _settleAtTarget(
        _controller.animateTo(
          target,
          duration: Duration(milliseconds: target == 1 ? 200 : 160),
          curve: const Cubic(0.23, 1, 0.32, 1),
        ),
        target,
      );
      return;
    }
    _settleAtTarget(
      _controller.animateWith(
        SpringSimulation(
          _spring,
          _controller.value,
          target,
          _controller.velocity,
        ),
      ),
      target,
    );
  }

  void _settleAtTarget(TickerFuture animation, double target) {
    animation.whenCompleteOrCancel(() {
      if (!mounted || _target != target) return;
      _controller.value = target;
    });
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.child != null) return;
    setState(() => _visibleChild = null);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _visibleChild;
    if (child == null) {
      return const SizedBox.shrink(key: ValueKey('selection-bar-empty'));
    }
    final faded = FadeTransition(opacity: _controller, child: child);
    if (widget.disableAnimations) return faded;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .25),
        end: Offset.zero,
      ).animate(_controller),
      child: faded,
    );
  }
}

class _LibrarySelectionBar extends StatelessWidget {
  const _LibrarySelectionBar({
    super.key,
    required this.selectedCount,
    required this.updateableCount,
    required this.operating,
    required this.onClear,
    required this.onUpdate,
    required this.onManage,
    required this.manageLabel,
  });

  final int selectedCount;
  final int updateableCount;
  final bool operating;
  final VoidCallback onClear;
  final VoidCallback onUpdate;
  final VoidCallback onManage;
  final String manageLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destructive = manageLabel == context.l10n.remove;
    return Material(
      key: const Key('library-selection-bar'),
      color: scheme.inverseSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: scheme.shadow.withValues(alpha: .32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.skillsSelected(selectedCount),
              style: TextStyle(
                color: scheme.onInverseSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: context.l10n.clearSelection,
              onPressed: operating ? null : onClear,
              visualDensity: VisualDensity.compact,
              color: scheme.onInverseSurface,
              disabledColor: scheme.onInverseSurface.withValues(alpha: .38),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 17,
                strokeWidth: 1.8,
              ),
            ),
            SizedBox(
              height: 22,
              child: VerticalDivider(
                color: scheme.onInverseSurface.withValues(alpha: .18),
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key('library-update-selected'),
              onPressed: operating || updateableCount == 0 ? null : onUpdate,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
                size: 17,
                strokeWidth: 1.8,
              ),
              label: Text(context.l10n.update),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: scheme.onInverseSurface.withValues(
                  alpha: .12,
                ),
                disabledForegroundColor: scheme.onInverseSurface.withValues(
                  alpha: .38,
                ),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
            TextButton.icon(
              key: const Key('library-manage-selected'),
              onPressed: operating ? null : onManage,
              style: destructive
                  ? TextButton.styleFrom(
                      foregroundColor:
                          context.skillsComponents.statusDangerOnInverse,
                    )
                  : TextButton.styleFrom(
                      foregroundColor: scheme.onInverseSurface,
                      disabledForegroundColor: scheme.onInverseSurface
                          .withValues(alpha: .38),
                    ),
              icon: HugeIcon(
                icon: destructive
                    ? HugeIcons.strokeRoundedDelete02
                    : HugeIcons.strokeRoundedSettings02,
                size: 17,
                strokeWidth: 1.8,
              ),
              label: Text(manageLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _installationCoverageLabel(
  BuildContext context,
  InstalledSkill skill,
  List<AddedProject> projects,
) {
  if (skill.targets.any((target) => target.scope == InstallationScope.user)) {
    return context.l10n.allProjects;
  }
  if (skill.projects.length == 1) {
    final root = skill.projects.single;
    final name =
        projects.where((project) => project.path == root).firstOrNull?.name ??
        p.basename(root);
    return '${context.l10n.specificProject}: $name';
  }
  return context.l10n.projectsSummary(skill.projects.length);
}

String _installedSourceLabel(BuildContext context, InstalledSkill skill) {
  if (skill.skillId.isEmpty) return context.l10n.localSource;
  final separator = skill.skillId.indexOf('/-/');
  return separator < 0 ? skill.skillId : skill.skillId.substring(0, separator);
}

class _LibraryScopeToggle extends StatelessWidget {
  const _LibraryScopeToggle({
    required this.updatesOnly,
    required this.onChanged,
  });

  final bool updatesOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SubscriptionSegmentedSwitch(
      key: const Key('library-update-filter'),
      options: [
        SubscriptionSwitchOption(
          label: context.l10n.all,
          icon: HugeIcons.strokeRoundedLayers01,
        ),
        SubscriptionSwitchOption(
          label: context.l10n.updatesOnly,
          icon: HugeIcons.strokeRoundedArrowReloadVertical,
        ),
      ],
      selectedIndex: updatesOnly ? 1 : 0,
      onChanged: (index) => onChanged(index == 1),
    );
  }
}

class _LibraryAddProjectAction extends StatelessWidget {
  const _LibraryAddProjectAction({
    required this.adding,
    required this.onPressed,
  });

  final bool adding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        key: const Key('library-add-project'),
        onPressed: adding ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          textStyle: context.skillsTypography.bodySecondary,
        ),
        child: Row(
          children: [
            if (adding)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else
              HugeIcon(
                icon: HugeIcons.strokeRoundedFolderAdd,
                size: 18,
                strokeWidth: 1.5,
                color: foreground,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.addProject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryAgentMultiFilter extends StatefulWidget {
  const _LibraryAgentMultiFilter({
    super.key,
    required this.agents,
    required this.selectedAgents,
    required this.agentLabel,
    required this.onChanged,
  });

  final List<String> agents;
  final Set<String> selectedAgents;
  final String Function(String) agentLabel;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_LibraryAgentMultiFilter> createState() =>
      _LibraryAgentMultiFilterState();
}

class _LibraryAgentMultiFilterState extends State<_LibraryAgentMultiFilter> {
  final controller = MultiSelectController<String>();
  bool syncing = false;

  List<DropdownItem<String>> get items => [
    for (final agent in widget.agents)
      DropdownItem(
        label: widget.agentLabel(agent),
        value: agent,
        selected: widget.selectedAgents.contains(agent),
      ),
  ];

  @override
  void didUpdateWidget(covariant _LibraryAgentMultiFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.agents, widget.agents) ||
        !setEquals(oldWidget.selectedAgents, widget.selectedAgents)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.isDisposed) return;
        syncing = true;
        controller.setItems(items);
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _showAllAgents() {
    controller
      ..clearAll()
      ..closeDropdown();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    final labelStyle = const TextStyle(fontSize: 14);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final widestLabel = items.fold<double>(0, (width, item) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: labelStyle),
        textScaler: textScaler,
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      return math.max(width, painter.width);
    });
    final dropdownWidth = (widestLabel + 76).clamp(190.0, 280.0);
    final semanticLabel = widget.selectedAgents.isEmpty
        ? context.l10n.allAgents
        : widget.selectedAgents.length == 1
        ? widget.agentLabel(widget.selectedAgents.first)
        : '× ${widget.selectedAgents.length}';
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 168,
        height: 36,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: dropdownWidth,
                maxWidth: dropdownWidth,
                child: MultiDropdown<String>(
                  controller: controller,
                  items: items,
                  closeOnBackButton: false,
                  fieldDecoration: FieldDecoration(
                    hintText: '',
                    showClearIcon: false,
                    animateSuffixIcon: false,
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.surfaceMuted.withValues(alpha: 0),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixIcon: null,
                  ),
                  dropdownDecoration: DropdownDecoration(
                    backgroundColor: colors.surfaceMuted,
                    elevation: 5,
                    maxHeight: 360,
                    marginTop: 6,
                    borderRadius: BorderRadius.circular(14),
                    listPadding: const EdgeInsets.symmetric(vertical: 6),
                    header: _AgentFilterAllRow(
                      selected: widget.selectedAgents.isEmpty,
                      onPressed: _showAllAgents,
                    ),
                    noItemsFoundText: context.l10n.noInstalledAgentsTitle,
                    animationDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    animationCurve: Curves.easeOutCubic,
                  ),
                  itemBuilder: (item, index, onTap) => _AgentFilterOptionRow(
                    agent: item.value,
                    label: item.label,
                    selected: item.selected,
                    onPressed: onTap,
                  ),
                  selectedItemBuilder: (_) => const SizedBox.shrink(),
                  chipDecoration: const ChipDecoration(
                    padding: EdgeInsets.zero,
                    spacing: 0,
                    runSpacing: 0,
                  ),
                  onSelectionChange: (values) {
                    if (syncing) return;
                    widget.onChanged(values.toSet());
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderMuted),
                ),
              ),
            ),
            Positioned.fill(
              right: 24,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AgentFilterSummary(
                      selectedAgents: widget.selectedAgents,
                      agentLabel: widget.agentLabel,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 10,
              top: 11.5,
              child: IgnorePointer(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  size: 13,
                  strokeWidth: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentFilterSummary extends StatelessWidget {
  const _AgentFilterSummary({
    required this.selectedAgents,
    required this.agentLabel,
  });

  final Set<String> selectedAgents;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    if (selectedAgents.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedRobot01,
            size: 16,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              context.l10n.allAgents,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    if (selectedAgents.length == 1) {
      final agent = selectedAgents.first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AgentLogo(agentId: agent, displayName: agentLabel(agent), size: 17),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              agentLabel(agent),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    const countStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    final countLabel = '× ${selectedAgents.length}';
    return LayoutBuilder(
      builder: (context, constraints) {
        const logoSize = 17.0;
        const logoGap = 6.0;
        final expandedLogoWidth =
            selectedAgents.length * logoSize +
            (selectedAgents.length - 1) * logoGap;
        if (expandedLogoWidth <= constraints.maxWidth) {
          return _AgentLogoStrip(
            agents: selectedAgents.toList(),
            step: logoSize + logoGap,
          );
        }
        final countPainter = TextPainter(
          text: TextSpan(text: countLabel, style: countStyle),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final availableForLogos = constraints.maxWidth - countPainter.width - 7;
        final visibleCount = availableForLogos < 17
            ? 1
            : (1 + ((availableForLogos - 17) / 10).floor()).clamp(
                1,
                selectedAgents.length,
              );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AgentLogoStrip(
              agents: selectedAgents.take(visibleCount).toList(),
              step: 10,
            ),
            const SizedBox(width: 7),
            Text(countLabel, style: countStyle),
          ],
        );
      },
    );
  }
}

class _AgentLogoStrip extends StatelessWidget {
  const _AgentLogoStrip({required this.agents, required this.step});

  final List<String> agents;
  final double step;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 17 + (agents.length - 1) * step,
    height: 19,
    child: Stack(
      children: [
        for (var index = 0; index < agents.length; index++)
          PositionedDirectional(
            start: index * step,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.skillsColors.surfaceMuted),
              ),
              child: AgentLogo(
                agentId: agents[index],
                displayName: agents[index],
                size: 17,
              ),
            ),
          ),
      ],
    ),
  );
}

class _AgentFilterAllRow extends StatelessWidget {
  const _AgentFilterAllRow({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.allAgents,
    button: true,
    selected: selected,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedRobot01,
                size: 18,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(context.l10n.allAgents)),
              if (selected)
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick01,
                  size: 18,
                  strokeWidth: 1.8,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AgentFilterOptionRow extends StatelessWidget {
  const _AgentFilterOptionRow({
    required this.agent,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String agent;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    selected: selected,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              AgentLogo(agentId: agent, displayName: label, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick01,
                  size: 18,
                  strokeWidth: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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

class LocalDetailScreen extends ConsumerStatefulWidget {
  const LocalDetailScreen({
    super.key,
    required this.gateway,
    required this.skill,
    required this.projects,
    required this.initialUpdateState,
    required this.onBack,
    required this.onRemoved,
  });
  final SkillsGateway gateway;
  final InstalledSkill skill;
  final List<AddedProject> projects;
  final UpdateState initialUpdateState;
  final VoidCallback onBack;
  final Future<void> Function() onRemoved;
  @override
  ConsumerState<LocalDetailScreen> createState() => _LocalDetailScreenState();
}

class _LocalDetailScreenState extends ConsumerState<LocalDetailScreen> {
  final detailScrollController = ScrollController();
  late InstalledSkill skill;
  SkillDetail? detail;
  SkillDetail? remoteIdentity;
  late UpdateState updateState;
  Object? error;
  bool managing = false;
  bool updating = false;
  bool installingMore = false;
  bool exporting = false;
  CommandResult? result;
  @override
  void initState() {
    super.initState();
    detailScrollController.addListener(_detailScrollChanged);
    skill = widget.skill;
    updateState = widget.initialUpdateState;
    unawaited(load());
    if (skill.provenance == LibraryProvenance.hub &&
        updateState != UpdateState.available &&
        updateState != UpdateState.upToDate) {
      unawaited(_checkUpdateState());
    }
  }

  void _detailScrollChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    detailScrollController
      ..removeListener(_detailScrollChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _checkUpdateState() async {
    if (skill.provenance != LibraryProvenance.hub) return;
    if (mounted) setState(() => updateState = UpdateState.checking);
    try {
      final states = await widget.gateway.checkUpdates([skill]);
      if (!mounted) return;
      setState(
        () => updateState =
            states[_libraryUpdateKey(skill)] ?? UpdateState.failed,
      );
    } on Object {
      if (mounted) setState(() => updateState = UpdateState.failed);
    }
  }

  Future<void> load() async {
    setState(() {
      error = null;
    });
    try {
      detail = await widget.gateway.loadLocalDetail(skill);
      if (mounted) setState(() {});
      unawaited(_loadRemoteIdentity());
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadRemoteIdentity() async {
    if (skill.provenance != LibraryProvenance.hub || skill.skillId.isEmpty) {
      return;
    }
    try {
      final value = await widget.gateway.loadRemoteDetail(
        SkillSummary(
          id: skill.skillId,
          installName: skill.name,
          name: skill.name,
          source: skill.skillId,
          installs: 0,
          latestVersion: skill.versions.firstOrNull ?? '',
          description: skill.description,
          riskAssessment: skill.riskAssessment,
          localTargetCount: skill.targetCount,
        ),
      );
      if (mounted) setState(() => remoteIdentity = value);
    } on Object {
      // Local content remains usable when optional Hub identity is unavailable.
    }
  }

  Future<void> manage([
    SkillInstallationTarget? target,
    TargetManagementAction? initialAction,
  ]) async {
    if (managing) return;
    setState(() {
      managing = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightTargetManagement(
        skill,
        target == null ? skill.targets : [target],
      );
      if (!mounted) return;
      final execution = await showSkillsDialog<TargetManagementExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _TargetManagementDialog(
          gateway: widget.gateway,
          plan: plan,
          initialAction: initialAction,
        ),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
        final projects = await widget.gateway.loadAddedProjects();
        final entries = await widget.gateway.listInstalled(projects: projects);
        final refreshed = entries.where(
          (entry) => entry.inventoryKey == skill.inventoryKey,
        );
        if (!mounted) return;
        if (refreshed.isEmpty) {
          await widget.onRemoved();
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

  Future<void> manageTargetInline(
    SkillInstallationTarget target,
    TargetManagementAction action,
  ) async {
    if (managing) return;
    setState(() {
      managing = true;
      result = null;
    });
    try {
      await _executeInlineTargetAction(
        gateway: widget.gateway,
        skill: skill,
        target: target,
        action: action,
      );
      unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
      final projects = await widget.gateway.loadAddedProjects();
      final entries = await widget.gateway.listInstalled(projects: projects);
      final refreshed = entries.where(
        (entry) => entry.inventoryKey == skill.inventoryKey,
      );
      if (!mounted) return;
      if (refreshed.isEmpty) {
        await widget.onRemoved();
        return;
      }
      skill = refreshed.first;
      await load();
    } finally {
      if (mounted) setState(() => managing = false);
    }
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
        unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
        final projects = await widget.gateway.loadAddedProjects();
        final entries = await widget.gateway.listInstalled(projects: projects);
        final refreshed = entries.where(
          (entry) => entry.inventoryKey == skill.inventoryKey,
        );
        if (refreshed.isNotEmpty) {
          skill = refreshed.first;
          await load();
          await _checkUpdateState();
        }
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => updating = false);
  }

  Future<void> installMore(InstallLocationMenuPresenter present) async {
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
        ref.read(agentCatalogProvider.notifier).ensureLoaded(),
        widget.gateway.loadAddedProjects(),
        widget.gateway.loadRiskPolicy(),
      ]);
      if (!mounted) return;
      var projects = values[1] as List<AddedProject>;
      final summary = SkillSummary(
        id: skill.skillId,
        installName: skill.name,
        name: skill.name,
        source: currentDetail.source,
        imageUrl: currentDetail.imageUrl,
        installs: 0,
        latestVersion: currentDetail.immutableVersion,
        description: currentDetail.description,
        riskAssessment: skill.riskAssessment,
        localTargetCount: skill.targetCount,
      );
      await present(
        InstallLocationMenuRequest(
          gateway: widget.gateway,
          catalog: values[0] as AgentCatalog,
          detail: currentDetail,
          projects: projects,
          onProjectAdded: (project) {
            projects = [...projects, project];
          },
        ),
        (choice) async {
          try {
            await operation.installTargets(
              widget.gateway,
              summary,
              currentDetail.immutableVersion,
              choice.selections,
              confirmRisk: true,
              allowCritical:
                  (values[2] as PersonalRiskPolicy).allowCriticalOverride,
            );
            if (!(operation.execution?.hasSuccess ?? false)) {
              if (!mounted) {
                return const InstallLocationSubmission.success();
              }
              final error =
                  operation.error ?? StateError('Installation failed.');
              final copy = _failureCopy(context, error);
              return InstallLocationSubmission.failure(
                title: context.l10n.installationFailed,
                message: copy.message,
              );
            }
            await _refreshManagedSkill(skillId: skill.skillId);
            unawaited(
              ref.read(agentCatalogProvider.notifier).refreshSilently(),
            );
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
    required String skillId,
    String? targetPath,
  }) async {
    final projects = await widget.gateway.loadAddedProjects();
    final entries = await widget.gateway.listInstalled(projects: projects);
    final refreshed = entries.where(
      (entry) =>
          entry.skillId == skillId &&
          (targetPath == null ||
              entry.targets.any((target) => target.path == targetPath)),
    );
    if (!mounted || refreshed.isEmpty) return;
    skill = refreshed.first;
    await load();
  }

  Widget _actions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (skill.provenance == LibraryProvenance.external) ...[
        SecondaryCapsuleButton(
          label: context.l10n.remove,
          icon: HugeIcons.strokeRoundedDelete02,
          onPressed: managing ? null : manage,
        ),
      ] else ...[
        if (skill.provenance == LibraryProvenance.hub &&
            updateState == UpdateState.available) ...[
          SecondaryCapsuleButton(
            label: context.l10n.update,
            icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
            onPressed: updating || managing ? null : update,
          ),
          const SizedBox(width: 8),
        ],
        if (detail?.immutableVersion.isNotEmpty ?? false) ...[
          InstallLocationMenuAnchor(
            builder: (context, present) => PrimaryCapsuleButton(
              label: context.l10n.installMoreTargets,
              height: 40,
              horizontalPadding: 18,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              onPressed: installingMore || managing || updating
                  ? null
                  : () => installMore(present),
              busy: installingMore,
            ),
          ),
        ],
        if (skill.provenance == LibraryProvenance.local) ...[
          const SizedBox(width: 8),
          SecondaryCapsuleButton(
            label: context.l10n.exportLocalSkill,
            icon: HugeIcons.strokeRoundedShare08,
            onPressed: exporting ? null : exportLocal,
          ),
        ],
      ],
    ],
  );

  Widget _detailToolbar() {
    final scheme = Theme.of(context).colorScheme;
    final offset = detailScrollController.hasClients
        ? detailScrollController.offset
        : 0.0;
    final materialProgress = ((offset - 12) / 52).clamp(0.0, 1.0);
    final compactProgress = ((offset - 72) / 56).clamp(0.0, 1.0);
    final source =
        remoteIdentity?.source ??
        (skill.skillId.isNotEmpty ? skill.skillId : skill.name);
    return SizedBox(
      key: const Key('installed-detail-sticky-toolbar'),
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
                  label: context.l10n.backToLibrary,
                  button: true,
                  child: Material(
                    color: scheme.surfaceContainerHigh.withValues(alpha: .82),
                    elevation: 3,
                    shadowColor: scheme.shadow.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      key: const Key('installed-detail-back'),
                      tooltip: context.l10n.backToLibrary,
                      onPressed: widget.onBack,
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
                if (compactProgress > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      key: const Key('installed-detail-compact-identity'),
                      opacity: compactProgress,
                      child: IgnorePointer(
                        ignoring: compactProgress < .95,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RepositoryAvatar(
                              source: source,
                              imageUrl: remoteIdentity?.imageUrl,
                              size: 26,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                skill.name,
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
                if (compactProgress > 0)
                  Opacity(
                    key: const Key('installed-detail-compact-actions'),
                    opacity: compactProgress,
                    child: IgnorePointer(
                      ignoring: compactProgress < .95,
                      child: _actions(),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    body: Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SkillDetailPageBody(
            scrollKey: const Key('installed-detail-scroll-view'),
            controller: detailScrollController,
            hero: _SkillDetailHero(
              name: skill.name,
              source:
                  remoteIdentity?.source ??
                  (skill.skillId.isNotEmpty ? skill.skillId : skill.name),
              description: remoteIdentity?.description ?? skill.description,
              imageUrl: remoteIdentity?.imageUrl,
              avatarKey: const Key('installed-detail-skill-avatar'),
              actions: _actions(),
            ),
            contextArea: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result != null) ...[
                  OperationPanel(result: result!),
                  const SizedBox(height: 14),
                ],
                _InstallationScopePanel(
                  targets: skill.targets,
                  projects: widget.projects,
                  onManageTarget: manageTargetInline,
                ),
              ],
            ),
            document: error != null
                ? EmptyState(
                    title: context.l10n.localReadFailed,
                    message: context.l10n.localReadFailedMessage,
                    action: PrimaryCapsuleButton(
                      label: context.l10n.retry,
                      onPressed: load,
                    ),
                  )
                : detail == null
                ? const SkillsSkeletonBox(height: 280, borderRadius: 14)
                : SkillMarkdownView(
                    key: const Key('installed-detail-instructions'),
                    data: detail!.markdown,
                    scrollable: false,
                    stripFrontMatter: true,
                  ),
          ),
          Align(alignment: Alignment.topCenter, child: _detailToolbar()),
        ],
      ),
    ),
  );
}
