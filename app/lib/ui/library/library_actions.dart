/*
 * [INPUT]: Depends on LibraryScreen state, SkillsGateway operations, reviewed update/management dialogs, the localized Batch Takeover story, reminders, and navigation animation.
 * [OUTPUT]: Provides Library loading, shared-refresh state reconciliation, selection, Added Project, one-time automatic takeover introduction, representative illustration data, inline-console plan-authorized Batch Takeover execution, update, target-management, and detail-transition actions.
 * [POS]: Serves as the mutation and orchestration implementation of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

extension _LibraryActions on _LibraryScreenState {
  Future<void> load() async {
    if (actionError != null) updateState(() => actionError = null);
    await ref.read(libraryProvider.notifier).refresh();
    if (!mounted) return;
    _reconcileLibraryState();
  }

  void _reconcileLibraryState() {
    if (!mounted) return;
    final currentKeys = (skills ?? const <InstalledSkill>[])
        .map(_librarySelectionKey)
        .toSet();
    final removedSkillKeys = selectedSkillKeys.difference(currentKeys);
    final availableAgents = _agents.toSet();
    final removedAgents = selectedAgents.difference(availableAgents);
    final resetLocation =
        selectedLocation.kind == _LibraryLocationKind.project &&
        _selectedProject == null;
    if (removedSkillKeys.isEmpty && removedAgents.isEmpty && !resetLocation) {
      return;
    }
    updateState(() {
      selectedSkillKeys.removeAll(removedSkillKeys);
      selectedAgents.removeAll(removedAgents);
      if (resetLocation) {
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
    updateState(() {
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
    updateState(() {
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
          (skill) => updates[libraryUpdateKey(skill)] == UpdateState.available,
        )
        .toList(growable: false);
    for (final skill in selected) {
      if (!mounted) return;
      await update(skill);
    }
    if (mounted) updateState(selectedSkillKeys.clear);
  }

  Future<void> _manageSelectedSkills() async {
    final selected = _selectedSkills;
    for (final skill in selected) {
      if (!mounted) return;
      await manage(skill);
    }
    if (mounted) updateState(selectedSkillKeys.clear);
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
      if (mounted) updateState(() => actionError = caught);
    }
  }

  Future<void> _addProject() async {
    if (addingProject) return;
    updateState(() {
      addingProject = true;
      actionError = null;
    });
    try {
      final addedProjects = await widget.gateway.addProjects();
      if (addedProjects.isEmpty || !mounted) return;
      await load();
      if (!mounted) return;
      updateState(() {
        selectedLocation =
            addedProjects.length == 1 &&
                projects.any((item) => item.id == addedProjects.single.id)
            ? _LibraryLocationRoute.project(addedProjects.single.id)
            : _LibraryLocationRoute.all;
      });
    } on Object catch (caught) {
      if (mounted) updateState(() => actionError = caught);
    } finally {
      if (mounted) updateState(() => addingProject = false);
    }
  }

  Future<void> _initializeTakeoverPrompt() async {
    try {
      final seen = await widget.gateway.loadBatchTakeoverPromptSeen();
      if (!mounted) return;
      updateState(() {
        takeoverPromptSeen = seen;
        takeoverPromptPreferenceLoaded = true;
      });
    } on Object {
      if (!mounted) return;
      updateState(() {
        takeoverPromptSeen = true;
        takeoverPromptPreferenceLoaded = true;
      });
    }
  }

  void _scheduleAutomaticTakeoverPrompt(int? eligible) {
    if (!TickerMode.valuesOf(context).enabled ||
        !takeoverPromptPreferenceLoaded ||
        takeoverPromptSeen ||
        takeoverPromptScheduled ||
        takingOver ||
        selectedDetailSkill != null ||
        eligible == null ||
        eligible == 0) {
      return;
    }
    takeoverPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_executeBatchTakeover(automatic: true));
    });
  }

  Future<void> _markTakeoverPromptSeen() async {
    if (takeoverPromptSeen) return;
    updateState(() => takeoverPromptSeen = true);
    try {
      await widget.gateway.markBatchTakeoverPromptSeen();
    } on Object {
      // The explicit takeover decision must not depend on preference storage.
    }
  }

  Future<void> _executeBatchTakeover({bool automatic = false}) async {
    if (takingOver || takeoverConsoleVisible) return;
    final plan = takeoverPlan;
    final scope = _currentTakeoverScope;
    final eligible = _currentTakeoverEligible;
    if (plan == null || scope == null || eligible == null || eligible == 0) {
      if (automatic) takeoverPromptScheduled = false;
      return;
    }
    updateState(() {
      takeoverConsoleVisible = true;
      takeoverConsoleAutomatic = automatic;
      activeTakeoverPlan = plan;
      activeTakeoverScope = scope;
      activeTakeoverEligible = eligible;
      activeTakeoverPreviews = _takeoverPreviews;
      takeoverExecutionAttempts = 0;
    });
  }

  Future<BatchTakeoverResult> _confirmActiveBatchTakeover() async {
    var plan = activeTakeoverPlan;
    final scope = activeTakeoverScope;
    if (plan == null || scope == null) {
      throw StateError('The active Batch Takeover plan is unavailable.');
    }
    if (takeoverExecutionAttempts > 0) {
      plan = await widget.gateway.planBatchTakeover(
        projectRoots: projects
            .where((project) => project.isAccessible)
            .map((project) => project.path)
            .toList(growable: false),
      );
      activeTakeoverPlan = plan;
    }
    takeoverExecutionAttempts++;
    updateState(() {
      takingOver = true;
      actionError = null;
    });
    try {
      final result = await widget.gateway.executeBatchTakeover(plan, scope);
      await load();
      return result;
    } finally {
      if (mounted) updateState(() => takingOver = false);
    }
  }

  Future<void> _finishBatchTakeover(_BatchTakeoverDialogOutcome outcome) async {
    final automatic = takeoverConsoleAutomatic;
    updateState(() {
      takeoverConsoleVisible = false;
      takeoverConsoleAutomatic = false;
      activeTakeoverPlan = null;
      activeTakeoverScope = null;
      activeTakeoverEligible = 0;
      activeTakeoverPreviews = const [];
      takeoverExecutionAttempts = 0;
    });
    if (automatic) await _markTakeoverPromptSeen();
    takeoverPromptScheduled = false;
  }

  List<BatchTakeoverPreview> get _takeoverPreviews {
    final location = selectedLocation;
    final plan = takeoverPlan;
    if (plan == null) return const [];
    return plan.previews
        .where((preview) {
          if (location.kind == _LibraryLocationKind.all) return true;
          if (location.kind == _LibraryLocationKind.global) {
            return preview.scope == InstallationScope.user;
          }
          return _selectedProject != null &&
              preview.projectRoot == _selectedProject!.path;
        })
        .toList(growable: false);
  }

  Future<void> checkUpdates() async {
    if (skills == null || checking) return;
    updateState(() {
      checking = true;
      updateCheckError = null;
      updates = {
        for (final skill in skills!)
          libraryUpdateKey(skill): skill.provenance == LibraryProvenance.hub
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
          libraryUpdateKey(skill): UpdateState.failed,
      };
    }
    if (mounted) updateState(() => checking = false);
  }

  Future<void> _initializeReminders() async {
    final settings = await widget.gateway.loadReminderSettings();
    if (!mounted) return;
    updateState(() => reminderSettings = settings);
    if (settings.updateAvailable) await checkUpdates();
  }

  Future<void> update(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    updateState(() => operatingSkills.add(skill.name));
    updateState(() => result = null);
    try {
      final plan = await widget.gateway.preflightUpdate(skill, skill.targets);
      if (!mounted) return;
      final execution = await showSkillsDialog<UpdateExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            UpdatePlanDialog(gateway: widget.gateway, skill: skill, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = exceptionResult(caught);
    }
    if (mounted) updateState(() => operatingSkills.remove(skill.name));
  }

  Future<void> manage(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    updateState(() => operatingSkills.add(skill.name));
    updateState(() => result = null);
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
            TargetManagementDialog(gateway: widget.gateway, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = exceptionResult(caught);
    }
    if (mounted) updateState(() => operatingSkills.remove(skill.name));
  }

  Future<void> _openDetail(InstalledSkill skill) async {
    updateState(() {
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
    updateState(() => detailTransitioning = false);
  }

  Future<void> _closeDetail() async {
    if (selectedDetailSkill == null) return;
    updateState(() => detailTransitioning = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      detailTransition.value = 0;
    } else {
      await detailTransition.reverse();
    }
    if (!mounted) return;
    updateState(() {
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
          (left, right) =>
              compareNatural(_agentLabel(left), _agentLabel(right)),
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
          updates[libraryUpdateKey(skill)] != UpdateState.available) {
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
}
