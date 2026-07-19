/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, HugeIcons, Riverpod Library state, gateway mutations, localization, and shared operation dialogs.
 * [OUTPUT]: Provides the unified Library destination, one-confirmation Batch Takeover with next-frame progress and aggregate results, cold/stale loading UI, composable update, project and Agent filtering, exact External removal, Local detail, export, and installation-target views.
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
  Object? actionError;
  bool checking = false;
  bool takingOver = false;
  Object? updateCheckError;
  Map<String, UpdateState> updates = const {};
  CommandResult? result;
  final operatingSkills = <String>{};
  final scrollController = ScrollController();
  final librarySearchController = TextEditingController();
  final librarySearchFocusNode = FocusNode();
  final selectedSkillKeys = <String>{};
  bool updatesOnly = false;
  String? selectedAgent;
  String? selectedProjectId;

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
    setState(() {
      final currentKeys = (skills ?? const <InstalledSkill>[])
          .map(_librarySelectionKey)
          .toSet();
      selectedSkillKeys.removeWhere((key) => !currentKeys.contains(key));
      if (selectedAgent != null && !_agents.contains(selectedAgent)) {
        selectedAgent = null;
      }
      if (selectedProjectId != null && _selectedProject == null) {
        selectedProjectId = null;
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
    final id = selectedProjectId;
    if (id == null) return null;
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Future<void> _addProject() async {
    try {
      final project = await widget.gateway.addProject();
      if (project == null || !mounted) return;
      setState(() => selectedProjectId = project.id);
      await load();
    } on Object catch (caught) {
      if (mounted) setState(() => actionError = caught);
    }
  }

  Future<void> _takeoverExistingSkills() async {
    if (takingOver) return;
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
        projectRoot: _selectedProject?.path,
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
    setState(() => selectedProjectId = null);
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

  Future<void> _openDetail(InstalledSkill skill) async {
    final appTheme = Theme.of(context);
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: appTheme,
          child: LocalDetailScreen(gateway: widget.gateway, skill: skill),
        ),
      ),
    );
    if (removed == true) await load();
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

  List<InstalledSkill> get _visibleSkills {
    final current = skills ?? const <InstalledSkill>[];
    final visible = <InstalledSkill>[];
    for (final skill in current) {
      if (updatesOnly &&
          updates[_libraryUpdateKey(skill)] != UpdateState.available) {
        continue;
      }
      if (selectedAgent != null &&
          !skill.targets.any((target) => target.agent == selectedAgent)) {
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
    final selected = _selectedSkills;
    final updateableSelected = selected.where(
      (skill) => updates[_libraryUpdateKey(skill)] == UpdateState.available,
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return SkillsContentFrame(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkillsEditorialTitle(context.l10n.yourLibrary),
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
                        SecondaryCapsuleButton(
                          key: const Key('library-add-project'),
                          label: context.l10n.addProject,
                          icon: HugeIcons.strokeRoundedFolderAdd,
                          onPressed: _addProject,
                        ),
                        SecondaryCapsuleButton(
                          key: const Key('library-batch-takeover'),
                          label: takingOver
                              ? context.l10n.batchTakeoverPending
                              : context.l10n.batchTakeoverAction,
                          icon: HugeIcons.strokeRoundedFolderTransfer,
                          onPressed: takingOver
                              ? null
                              : _takeoverExistingSkills,
                        ),
                        if (_selectedProject != null) ...[
                          SecondaryCapsuleButton(
                            label: context.l10n.relocateProject,
                            icon: HugeIcons.strokeRoundedFolderMoveTo,
                            onPressed: () =>
                                _relocateProject(_selectedProject!),
                          ),
                          SecondaryCapsuleButton(
                            label: context.l10n.removeFromList,
                            icon: HugeIcons.strokeRoundedRemoveCircle,
                            onPressed: () => _removeProject(_selectedProject!),
                          ),
                        ],
                        SecondaryCapsuleButton(
                          label: checking
                              ? context.l10n.checking
                              : context.l10n.checkUpdates,
                          icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
                          onPressed: checking || !_hasUpdateableSkills
                              ? null
                              : checkUpdates,
                        ),
                        SecondaryCapsuleButton(
                          label: context.l10n.refresh,
                          icon: HugeIcons.strokeRoundedRefresh,
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
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefreshCwOff,
                    strokeWidth: 1.8,
                  ),
                  title: Text(_failureCopy(context, error!).title),
                  description: Text(_failureCopy(context, error!).message),
                ),
              ],
              if (updateCheckError != null) ...[
                const SizedBox(height: 14),
                SkillsAlert(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCloudOff,
                    strokeWidth: 1.8,
                  ),
                  title: Text(_failureCopy(context, updateCheckError!).title),
                  description: Text(
                    _failureCopy(context, updateCheckError!).message,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SkillsInput(
                      key: const Key('library-search'),
                      controller: librarySearchController,
                      focusNode: librarySearchFocusNode,
                      onChanged: (_) => setState(() {}),
                      leading: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        strokeWidth: 1.8,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      placeholder: Text(context.l10n.searchLibrary),
                      placeholderStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LibraryScopeToggle(
                    updatesOnly: updatesOnly,
                    onChanged: (value) => setState(() => updatesOnly = value),
                  ),
                  const SizedBox(width: 10),
                  _LibraryFilterMenu(
                    key: const Key('library-agent-filter'),
                    label: selectedAgent == null
                        ? context.l10n.allAgents
                        : _agentLabel(selectedAgent!),
                    icon: HugeIcons.strokeRoundedRobot01,
                    entries: [
                      _LibraryFilterEntry(
                        value: null,
                        label: context.l10n.allAgents,
                      ),
                      for (final agent in _agents)
                        _LibraryFilterEntry(
                          value: agent,
                          label: _agentLabel(agent),
                        ),
                    ],
                    selected: selectedAgent,
                    onSelected: (value) =>
                        setState(() => selectedAgent = value),
                  ),
                  const SizedBox(width: 10),
                  _LibraryFilterMenu(
                    key: const Key('library-project-filter'),
                    label: _selectedProject == null
                        ? context.l10n.allProjects
                        : _selectedProject!.name,
                    icon: HugeIcons.strokeRoundedFolderOpen,
                    entries: [
                      _LibraryFilterEntry(
                        value: null,
                        label: context.l10n.allProjects,
                      ),
                      for (final project in projects)
                        _LibraryFilterEntry(
                          value: project.id,
                          label: project.isAccessible
                              ? project.name
                              : context.l10n.projectRailUnavailable(
                                  project.name,
                                ),
                        ),
                    ],
                    selected: selectedProjectId,
                    onSelected: (value) =>
                        setState(() => selectedProjectId = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _body()),
            ],
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
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: _LibraryCoverageIcons(
                    skill: skill,
                    projects: const [],
                    agentLabel: agentLabel,
                    includeProjects: false,
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

class _LibraryCoverageIcons extends StatelessWidget {
  const _LibraryCoverageIcons({
    required this.skill,
    required this.projects,
    required this.agentLabel,
    this.includeProjects = true,
  });

  final InstalledSkill skill;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;
  final bool includeProjects;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final agent in skill.agents)
        _CoverageBadge(
          tooltip: agentLabel(agent),
          semanticLabel: agentLabel(agent),
          child: AgentLogo(
            agentId: agent,
            displayName: agentLabel(agent),
            size: 17,
          ),
        ),
      if (includeProjects)
        for (final root in skill.projects)
          _CoverageBadge(
            tooltip: _projectName(root),
            semanticLabel: _projectName(root),
            child: Text(
              _projectInitials(_projectName(root)),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
    ];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: items,
    );
  }

  String _projectName(String root) {
    for (final project in projects) {
      if (project.path == root) return project.name;
    }
    return p.basename(root);
  }
}

class _CoverageBadge extends StatelessWidget {
  const _CoverageBadge({
    required this.tooltip,
    required this.semanticLabel,
    required this.child,
  });

  final String tooltip;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      label: semanticLabel,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(7),
        ),
        child: child,
      ),
    ),
  );
}

String _projectInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s_-]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    return words.first.characters.take(2).toString().toUpperCase();
  }
  return '${words.first.characters.first}${words.last.characters.first}'
      .toUpperCase();
}

class _LibraryScopeToggle extends StatelessWidget {
  const _LibraryScopeToggle({
    required this.updatesOnly,
    required this.onChanged,
  });

  final bool updatesOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    key: const Key('library-update-filter'),
    segments: [
      ButtonSegment(value: false, label: Text(context.l10n.all)),
      ButtonSegment(value: true, label: Text(context.l10n.updatesOnly)),
    ],
    selected: {updatesOnly},
    showSelectedIcon: false,
    onSelectionChanged: (selection) => onChanged(selection.single),
  );
}

class _LibraryFilterEntry {
  const _LibraryFilterEntry({required this.value, required this.label});

  final String? value;
  final String label;
}

class _LibraryFilterMenu extends StatelessWidget {
  const _LibraryFilterMenu({
    super.key,
    required this.label,
    required this.icon,
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<List<dynamic>> icon;
  final List<_LibraryFilterEntry> entries;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final entry in entries)
        MenuItemButton(
          leadingIcon: entry.value == selected
              ? const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 18,
                  strokeWidth: 1.8,
                )
              : const SizedBox(width: 18),
          onPressed: () => onSelected(entry.value),
          child: Text(entry.label),
        ),
    ],
    builder: (context, controller, child) => SecondaryCapsuleButton(
      label: label,
      icon: icon,
      onPressed: controller.isOpen ? controller.close : controller.open,
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
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedLock,
                strokeWidth: 1.8,
              ),
              description: Text(context.l10n.adoptionPreservesContent),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              SkillsAlert.destructive(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  strokeWidth: 1.8,
                ),
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
                              HugeIcon(
                                icon: selected
                                    ? HugeIcons.strokeRoundedRadioButton
                                    : HugeIcons.strokeRoundedCircle,
                                strokeWidth: 1.8,
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
    if (managing) return;
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
          (entry) => entry.inventoryKey == skill.inventoryKey,
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
          (entry) => entry.inventoryKey == skill.inventoryKey,
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
          skillId: adopted.skillId,
          targetPath: adopted.target.path,
        );
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => adopting = false);
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
        widget.gateway.inspectAgents(),
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
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    strokeWidth: 1.8,
                  ),
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
                  SecondaryCapsuleButton(
                    label: context.l10n.remove,
                    icon: HugeIcons.strokeRoundedDelete02,
                    onPressed: managing ? null : manage,
                  ),
                ] else ...[
                  if (skill.provenance == LibraryProvenance.hub) ...[
                    SecondaryCapsuleButton(
                      label: context.l10n.update,
                      icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
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
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedSettings02,
                          size: 18,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                  ),
                  if (detail?.immutableVersion.isNotEmpty ?? false) ...[
                    const SizedBox(width: 8),
                    InstallLocationMenuAnchor(
                      builder: (context, present) => SecondaryCapsuleButton(
                        label: context.l10n.installMoreTargets,
                        icon: HugeIcons.strokeRoundedCopy01,
                        onPressed: installingMore || managing || updating
                            ? null
                            : () => installMore(present),
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
                              leading: HugeIcon(
                                icon: file.executable
                                    ? HugeIcons.strokeRoundedFileTerminal
                                    : file.binary
                                    ? HugeIcons.strokeRoundedBinaryCode
                                    : HugeIcons.strokeRoundedFile02,
                                size: 15,
                                strokeWidth: 1.8,
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
