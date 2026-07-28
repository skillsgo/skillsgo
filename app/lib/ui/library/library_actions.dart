/*
 * [INPUT]: Depends on LibraryScreen state, direct SkillsGateway Package updates, inline removal state, the localized Adoption story, reminders, and navigation animation.
 * [OUTPUT]: Provides Library loading, shared-refresh reconciliation, target projection, selection, Added Project, reviewed adoption, one-card-at-a-time Package update with inventory refresh, inline-confirmed removal, and detail transitions.
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
        selectedLocation = _LibraryLocationRoute.global;
      }
    });
  }

  List<InstalledSkill> get _selectedSkills {
    final selected = selectedSkillKeys;
    return _locationAndAgentProjectedSkills
        .where((skill) => selected.contains(_librarySelectionKey(skill)))
        .toList(growable: false);
  }

  void _toggleSkillSelection(InstalledSkill skill, bool selected) {
    updateState(() {
      removalConfirming = false;
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
      removalConfirming = false;
      final visibleKeys = visibleSkills.map(_librarySelectionKey);
      if (selected) {
        selectedSkillKeys.addAll(visibleKeys);
      } else {
        selectedSkillKeys.removeAll(visibleKeys);
      }
    });
  }

  Future<void> _updatePackageCard(_PackageUpdateCardData package) async {
    if (operatingSkills.contains(package.packagePath)) return;
    updateState(() => operatingSkills.add(package.packagePath));
    updateState(() => result = null);
    try {
      await widget.gateway.updatePackage(
        package.skill,
        toVersion: package.toVersion,
      );
      await load();
      await checkUpdates();
    } catch (caught) {
      result = exceptionResult(caught);
      try {
        await load();
        await checkUpdates();
      } on Object {
        // Preserve the original mutation failure; refresh is best effort.
      }
    } finally {
      if (mounted) {
        updateState(() => operatingSkills.remove(package.packagePath));
      }
    }
  }

  void _requestSelectedRemoval() => updateState(() => removalConfirming = true);

  void _cancelSelectedRemoval() => updateState(() => removalConfirming = false);

  Future<void> _confirmSelectedRemoval() async {
    final selected = _selectedSkills;
    updateState(() {
      removalConfirming = false;
      removalFinishedTargets = 0;
      removalTotalTargets = selected.fold(
        0,
        (total, skill) => total + skill.targets.length,
      );
    });
    await _removeSkills(selected);
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
            : _LibraryLocationRoute.global;
      });
    } on Object catch (caught) {
      if (mounted) updateState(() => actionError = caught);
    } finally {
      if (mounted) updateState(() => addingProject = false);
    }
  }

  void _enterAdoptionReview() {
    if (adoptionReviewVisible) return;
    updateState(() {
      selectedSkillKeys.clear();
      adoptionReviewVisible = true;
    });
  }

  void _exitAdoptionReview() {
    if (!adoptionReviewVisible) return;
    updateState(() => adoptionReviewVisible = false);
  }

  void _openAdoptionAdoptionConsole(List<_AdoptionReviewSelection> selections) {
    if (selections.isEmpty || adopting || adoptionConsoleVisible) return;
    updateState(() {
      adoptionConsoleVisible = true;
      activeAdoptionSelections = selections;
      activeAdoptionEligible = selections.length;
      activeAdoptionPreviews = [
        for (final selection in selections)
          BatchAdoptionPreview(
            name: selection.installed.name,
            skillId:
                '${selection.candidate.packagePath}:${selection.candidate.path}',
            scope:
                selection.installed.targets.firstOrNull?.scope ??
                InstallationScope.global,
            projectRoot:
                selection.installed.targets.firstOrNull?.projectRoot ?? '',
          ),
      ];
    });
  }

  Future<BatchAdoptionResult> _confirmActiveAdoption() async {
    final selections = activeAdoptionSelections;
    if (selections.isEmpty) {
      throw StateError('The reviewed Adoption selection is unavailable.');
    }
    updateState(() {
      adopting = true;
      actionError = null;
    });
    try {
      if (selections.any((selection) => selection.installed.targets.isEmpty)) {
        throw StateError(
          'Every reviewed External Skill must retain its installation targets.',
        );
      }
      final result = await widget.gateway.adopt([
        for (final selection in selections)
          AdoptionRequestItem(
            inventoryKey: selection.installed.inventoryKey,
            name: selection.installed.name,
            packagePath: selection.candidate.packagePath,
            version: selection.version,
            skillPath: selection.candidate.path,
            targets: [
              for (final target in selection.installed.targets)
                AdoptionTarget(
                  agent: target.agent,
                  scope: target.scope,
                  projectRoot: target.projectRoot,
                  path: target.path,
                ),
            ],
          ),
      ]);
      unawaited(_refreshAfterActiveAdoption());
      return result;
    } finally {
      if (mounted) updateState(() => adopting = false);
    }
  }

  Future<void> _refreshAfterActiveAdoption() async {
    try {
      await load();
    } on Object catch (caught) {
      if (mounted) updateState(() => actionError = caught);
    }
  }

  Future<void> _finishBatchAdoption(_BatchAdoptionDialogOutcome outcome) async {
    updateState(() {
      adoptionConsoleVisible = false;
      activeAdoptionEligible = 0;
      activeAdoptionPreviews = const [];
      activeAdoptionSelections = const [];
    });
  }

  Future<void> checkUpdates() async {
    if (skills == null || checking) return;
    updateState(() {
      checking = true;
      updateCheckError = null;
      updates = {
        for (final skill in skills!)
          for (final target in skill.targets)
            packageScopeUpdateKey(
              skill.packagePath,
              target.scope,
              target.projectRoot,
            ): UpdateAvailability(
              state: skill.provenance == LibraryProvenance.hub
                  ? UpdateState.checking
                  : UpdateState.unsupported,
            ),
      };
    });
    try {
      updates = await widget.gateway.checkUpdates(skills!);
    } catch (caught) {
      updateCheckError = caught;
      updates = {
        for (final skill in skills!)
          for (final target in skill.targets)
            packageScopeUpdateKey(
              skill.packagePath,
              target.scope,
              target.projectRoot,
            ): const UpdateAvailability(
              state: UpdateState.failed,
            ),
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

  Future<void> _removeSkills(List<InstalledSkill> selected) async {
    if (selected.isEmpty ||
        selected.any((skill) => operatingSkills.contains(skill.name))) {
      return;
    }
    updateState(
      () => operatingSkills.addAll(selected.map((skill) => skill.name)),
    );
    updateState(() => result = null);
    try {
      final plans = await Future.wait([
        for (final skill in selected)
          widget.gateway.preflightTargetManagement(skill, skill.targets),
      ]);
      final targets = [for (final plan in plans) ...plan.targets];
      final plan = TargetManagementPlan(
        targets: List.unmodifiable(targets),
        summary: TargetManagementPlanSummary(removable: targets.length),
      );
      final selectedPlan = plan.selectActions({
        for (final item in plan.targets)
          installationTargetKey(item.target): TargetManagementAction.remove,
      });
      final execution = await widget.gateway.executeTargetManagement(
        selectedPlan,
        onProgress: (progress) {
          if (!mounted ||
              progress.state != InstallationProgressState.finished) {
            return;
          }
          updateState(() => removalFinishedTargets++);
        },
      );
      if (execution.summary.succeeded > 0) {
        final succeeded = <String>{};
        for (final skill in selected) {
          final relatedResults = execution.results
              .where(
                (result) =>
                    result.name == skill.name &&
                    result.packagePath == skill.packagePath,
              )
              .toList(growable: false);
          if (relatedResults.isNotEmpty &&
              relatedResults.every(
                (result) => result.outcome == TargetManagementOutcome.succeeded,
              )) {
            succeeded.add(_librarySelectionKey(skill));
          }
        }
        updateState(() => selectedSkillKeys.removeAll(succeeded));
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = exceptionResult(caught);
    }
    if (mounted) {
      updateState(() {
        operatingSkills.removeAll(selected.map((skill) => skill.name));
        removalFinishedTargets = 0;
        removalTotalTargets = 0;
      });
    }
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

  List<InstalledSkill> get _locationAndAgentProjectedSkills {
    final current = skills ?? const <InstalledSkill>[];
    final projected = <InstalledSkill>[];
    for (final skill in current) {
      final project = _selectedProject;
      final visibleTargets = skill.targets
          .where((target) {
            final matchesLocation = project == null
                ? target.scope == InstallationScope.global
                : target.scope == InstallationScope.project &&
                      target.projectRoot == project.path;
            final matchesAgent =
                selectedAgents.isEmpty || selectedAgents.contains(target.agent);
            return matchesLocation && matchesAgent;
          })
          .toList(growable: false);
      if (visibleTargets.isEmpty) continue;
      projected.add(skill.withTargets(visibleTargets));
    }
    return projected;
  }

  List<InstalledSkill> get _visibleSkills {
    final visible = <InstalledSkill>[];
    for (final visibleSkill in _locationAndAgentProjectedSkills) {
      if (updatesOnly &&
          updates[libraryScopeUpdateKey(visibleSkill)]?.state !=
              UpdateState.available) {
        continue;
      }
      final query = librarySearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final searchable = [
          visibleSkill.name,
          visibleSkill.description,
          visibleSkill.packagePath,
          ...visibleSkill.agents,
          ...visibleSkill.projects,
          ...visibleSkill.versions,
        ].join('\n').toLowerCase();
        if (!searchable.contains(query)) continue;
      }
      visible.add(visibleSkill);
    }
    return visible;
  }
}
