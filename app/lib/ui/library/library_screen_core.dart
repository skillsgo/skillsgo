/*
 * [INPUT]: Depends on the Library journey library, Riverpod Library state, navigation routes, selection state, and shared layout widgets.
 * [OUTPUT]: Provides the public LibraryScreen, route-local state ownership, lifecycle, one-time takeover-introduction and inline-console state, filtering getters, selected-scope and project takeover counts, and root desktop rendering.
 * [POS]: Serves as the state-owning core of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

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
  void updateState(VoidCallback change) => setState(change);
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
  bool takeoverConsoleVisible = false;
  bool takeoverConsoleAutomatic = false;
  BatchTakeoverPlan? activeTakeoverPlan;
  BatchTakeoverScope? activeTakeoverScope;
  int activeTakeoverEligible = 0;
  List<BatchTakeoverPreview> activeTakeoverPreviews = const [];
  int takeoverExecutionAttempts = 0;
  bool takeoverPromptPreferenceLoaded = false;
  bool takeoverPromptSeen = false;
  bool takeoverPromptScheduled = false;
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
    unawaited(_initializeTakeoverPrompt());
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

  BatchTakeoverPlan? get takeoverPlan => _library.value?.takeoverPlan;

  BatchTakeoverScope? get _currentTakeoverScope =>
      switch (selectedLocation.kind) {
        _LibraryLocationKind.all => BatchTakeoverScope.all,
        _LibraryLocationKind.global => BatchTakeoverScope.user,
        _LibraryLocationKind.project =>
          _selectedProject == null
              ? null
              : BatchTakeoverScope.project(_selectedProject!.path),
      };

  int? get _currentTakeoverEligible {
    final plan = takeoverPlan;
    final scope = _currentTakeoverScope;
    return plan == null || scope == null ? null : plan.eligibleCount(scope);
  }

  Object? get error =>
      actionError ?? _library.value?.refreshError ?? _library.error;

  bool get loading =>
      _library.isLoading || (_library.value?.refreshing ?? false);

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    ref.listen(libraryProvider, (_, next) {
      if (next.value != null) _reconcileLibraryState();
    });
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
      (skill) => updates[libraryUpdateKey(skill)] == UpdateState.available,
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
    final plan = takeoverPlan;
    final planning = _library.value?.takeoverPlanning ?? false;
    final planError = _library.value?.takeoverPlanError;
    final takeoverEligible = _currentTakeoverEligible;
    _scheduleAutomaticTakeoverPrompt(takeoverEligible);
    final String takeoverActionLabel;
    final VoidCallback? takeoverAction;
    if (takingOver) {
      takeoverActionLabel = context.l10n.batchTakeoverPending;
      takeoverAction = null;
    } else if (planning || plan == null && planError == null) {
      takeoverActionLabel = context.l10n.batchTakeoverChecking;
      takeoverAction = null;
    } else if (planError != null) {
      takeoverActionLabel = context.l10n.batchTakeoverRetry;
      takeoverAction = () =>
          unawaited(ref.read(libraryProvider.notifier).refreshTakeoverPlan());
    } else {
      takeoverActionLabel = context.l10n.batchTakeoverActionCount(
        takeoverEligible ?? 0,
      );
      takeoverAction = takeoverEligible == null || takeoverEligible == 0
          ? null
          : () => unawaited(_executeBatchTakeover());
    }
    return SkillsDestinationLayout(
      foreground: takeoverConsoleVisible
          ? _BatchTakeoverConsole(
              eligibleCount: activeTakeoverEligible,
              skillPreviews: activeTakeoverPreviews,
              onConfirm: _confirmActiveBatchTakeover,
              onExit: _finishBatchTakeover,
            )
          : null,
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
              count: projects[index].isAccessible && plan != null
                  ? plan.eligibleForProject(projects[index].path)
                  : null,
              countLabel: projects[index].isAccessible && plan != null
                  ? context.l10n.batchTakeoverEligibleCount(
                      plan.eligibleForProject(projects[index].path),
                    )
                  : null,
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
                        title: Text(failureCopy(context, error!).title),
                        description: Text(failureCopy(context, error!).message),
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
                          failureCopy(context, updateCheckError!).title,
                        ),
                        description: Text(
                          failureCopy(context, updateCheckError!).message,
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
                          label: takeoverActionLabel,
                          icon: HugeIcons.strokeRoundedFolderTransfer,
                          onPressed: takeoverAction,
                        ),
                        const SizedBox(width: 4),
                        _LibraryScopeToggle(
                          updatesOnly: updatesOnly,
                          onChanged: (value) {
                            setState(() => updatesOnly = value);
                            if (value) unawaited(checkUpdates());
                          },
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
                      updates[libraryUpdateKey(detailSkill)] ??
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
}
