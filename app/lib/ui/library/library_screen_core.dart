/*
 * [INPUT]: Depends on the Library journey library, Riverpod Library and App-scoped update-check state, navigation routes, selection state, and shared layout widgets.
 * [OUTPUT]: Provides the public LibraryScreen, Global/Project location routes, composable management/usage filters, selection-column-aligned All Skills / Needs Attention content navigation with resident-budget insights and restoration state, 45/90-day usage sorting, an inline empty-project add link, local-inventory refresh, privacy-settings recovery feedback, coordinated update rendering, reviewed Adoption execution state, selection-safety reset, and root desktop rendering.
 * [POS]: Serves as the state-owning core of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

enum _LibraryLocationKind { global, project }

enum _LibraryManagementFilter { all, managed, otherInstallation }

enum _LibraryUsageFilter { all, unused45Days, unused90Days }

enum _LibraryUsageSort { none, hits45Days, hits90Days }

enum _LibraryContentMode {
  allSkills,
  needsAttention,
  unused45Days,
  otherInstallation,
  updates,
}

class _LibraryLocationRoute {
  const _LibraryLocationRoute._(this.kind, [this.projectId]);

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

  void _updateLibraryQuery(VoidCallback change) {
    setState(() {
      removalConfirming = false;
      selectedSkillKeys.clear();
      change();
    });
  }

  Object? actionError;
  bool privacySettingsOpenFailed = false;
  CommandResult? result;
  final operatingSkills = <String>{};
  final scrollController = ScrollController();
  final librarySearchController = TextEditingController();
  final librarySearchFocusNode = FocusNode();
  final selectedSkillKeys = <String>{};
  bool removalConfirming = false;
  int removalFinishedTargets = 0;
  int removalTotalTargets = 0;
  _LibraryManagementFilter managementFilter = _LibraryManagementFilter.all;
  _LibraryUsageFilter usageFilter = _LibraryUsageFilter.all;
  _LibraryUsageSort usageSort = _LibraryUsageSort.none;
  bool usageSortDescending = true;
  _LibraryContentMode contentMode = _LibraryContentMode.allSkills;
  double allSkillsScrollOffset = 0;
  final selectedAgents = <String>{};
  _LibraryLocationRoute selectedLocation = _LibraryLocationRoute.global;
  bool addingProject = false;
  bool adopting = false;
  bool adoptionReviewVisible = false;
  bool adoptionConsoleVisible = false;
  int activeAdoptionEligible = 0;
  List<BatchAdoptionPreview> activeAdoptionPreviews = const [];
  List<_AdoptionReviewSelection> activeAdoptionSelections = const [];
  InstalledSkill? selectedDetailSkill;
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

  UpdateCheckState get _updateCheck =>
      ref.read(updateCheckProvider).value ?? const UpdateCheckState();
  bool get checking => _updateCheck.checking;
  Object? get updateCheckError => _updateCheck.error;
  Map<String, UpdateAvailability> get updates => _updateCheck.results;

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    ref.watch(updateCheckProvider);
    ref.listen(libraryProvider, (_, next) {
      if (next.value != null) _reconcileLibraryState();
    });
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
    final detailSkill = selectedDetailSkill;
    return SkillsDestinationLayout(
      bodyTransitionKey: selectedLocation,
      overlay: Positioned(
        left: 0,
        right: 0,
        bottom: 18,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _LibrarySelectionBarTransition(
            key: const Key('library-selection-bar-switcher'),
            child: selected.isEmpty || adoptionReviewVisible
                ? null
                : _LibrarySelectionBar(
                    key: const ValueKey('selection-bar-visible'),
                    selectedCount: selected.length,
                    operating: selected.any(
                      (skill) => operatingSkills.contains(skill.name),
                    ),
                    confirmingRemoval: removalConfirming,
                    onClear: () => setState(() {
                      removalConfirming = false;
                      selectedSkillKeys.clear();
                    }),
                    onRequestRemove: _requestSelectedRemoval,
                    onCancelRemove: _cancelSelectedRemoval,
                    onConfirmRemove: _confirmSelectedRemoval,
                  ),
          ),
        ),
      ),
      foreground: adoptionConsoleVisible
          ? _BatchAdoptionConsole(
              eligibleCount: activeAdoptionEligible,
              initiallyCompleted: activeAdoptionEligible == 0,
              skillPreviews: activeAdoptionPreviews,
              onConfirm: _confirmActiveAdoption,
              onExit: _finishBatchAdoption,
            )
          : null,
      rail: SkillsSideRail<_LibraryLocationRoute>(
        key: const Key('library-location-rail'),
        semanticLabel: context.l10n.libraryNavigation,
        selected: selectedLocation,
        onSelected: (location) => _updateLibraryQuery(() {
          adoptionReviewVisible = false;
          selectedLocation = location;
        }),
        sectionDividers: true,
        sectionLabel: context.l10n.projects,
        fixedItems: [
          SkillsRailItem(
            value: _LibraryLocationRoute.global,
            label: context.l10n.libraryGlobalScope,
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
              image: ProjectIdentityIcon(project: projects[index], size: 18),
            ),
        ],
        emptySection: _LibraryEmptyProjectAction(
          adding: addingProject,
          onPressed: () => unawaited(_addProject()),
        ),
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
                          padding: const EdgeInsetsDirectional.only(start: 11),
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
                                  child:
                                      adoptionReviewVisible ||
                                          contentMode !=
                                              _LibraryContentMode.allSkills
                                      ? const SizedBox.shrink()
                                      : SkillsCheckbox(
                                          key: const Key(
                                            'library-select-visible',
                                          ),
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
                            onCleared: () => _updateLibraryQuery(
                              librarySearchController.clear,
                            ),
                            onChanged: (_) => _updateLibraryQuery(() {}),
                            height: 45,
                            appearance: SkillSearchAppearance.leaderboard,
                            hintText: context.l10n.searchLibrary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _LibraryFilterControl(
                          managementFilter: managementFilter,
                          usageFilter: usageFilter,
                          onManagementChanged: (filter) => _updateLibraryQuery(
                            () => managementFilter = filter,
                          ),
                          onUsageChanged: (filter) =>
                              _updateLibraryQuery(() => usageFilter = filter),
                        ),
                        const SizedBox(width: 4),
                        _LibraryAgentMultiFilter(
                          key: const Key('library-agent-filter'),
                          agents: _agents,
                          selectedAgents: selectedAgents,
                          agentLabel: _agentLabel,
                          onChanged: (agents) => _updateLibraryQuery(() {
                            selectedAgents
                              ..clear()
                              ..addAll(agents);
                          }),
                        ),
                        const SizedBox(width: 4),
                        SizedBox.square(
                          dimension: 36,
                          child: Tooltip(
                            message: context.l10n.refresh,
                            child: IconButton(
                              key: const Key('library-refresh'),
                              padding: EdgeInsets.zero,
                              onPressed: loading
                                  ? null
                                  : () => unawaited(load()),
                              icon: loading
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                      ),
                                    )
                                  : const HugeIcon(
                                      icon: HugeIcons.strokeRoundedRefresh,
                                      size: 18,
                                      strokeWidth: 1.8,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 21),
                      child: _LibraryContentSwitcher(
                        mode: contentMode,
                        resultCount: _visibleSkills.length,
                        attentionCount: _needsAttentionCount,
                        updatesAvailable: _availableUpdatePackageCount > 0,
                        budget: skills == null
                            ? null
                            : _LibraryResidentBudget.fromSkills(
                                _locationAndAgentProjectedSkills,
                              ),
                        analyticsProgress: _library.value?.analyticsProgress,
                        unusedBudgetSelected:
                            usageFilter == _LibraryUsageFilter.unused45Days,
                        onAllSkills: _showAllSkills,
                        onNeedsAttention: _showNeedsAttention,
                        onUnusedBudget: _toggleUnusedBudgetFilter,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
          ),
          if (detailSkill != null)
            SlideTransition(
              key: const Key('library-detail-surface'),
              position:
                  Tween<Offset>(
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
                  initialUpdate:
                      updates[libraryScopeUpdateKey(detailSkill)] ??
                      const UpdateAvailability(state: UpdateState.unknown),
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

class _LibraryEmptyProjectAction extends StatelessWidget {
  const _LibraryEmptyProjectAction({
    required this.adding,
    required this.onPressed,
  });

  final bool adding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: const Key('library-empty-add-project'),
      onPressed: adding ? null : onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: context.skillsTypography.caption.copyWith(
          fontSize: 11,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(context.l10n.libraryEmptyAddProject),
    ),
  );
}
