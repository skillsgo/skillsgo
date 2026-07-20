/*
 * [INPUT]: Depends on the Library journey library, local/remote Skill identity, gateway operations, update state, and detail navigation.
 * [OUTPUT]: Provides the public LocalDetailScreen plus loading, refresh, update, target-management, install-more, export, and root rendering behavior.
 * [POS]: Serves as the state-owning core of the local Skill detail journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

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
        () =>
            updateState = states[libraryUpdateKey(skill)] ?? UpdateState.failed,
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
        builder: (context) => TargetManagementDialog(
          gateway: widget.gateway,
          plan: plan,
          initialAction: initialAction,
        ),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await _refreshManagedSkill(removeWhenMissing: true);
      }
    } catch (caught) {
      result = exceptionResult(caught);
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
      await executeInlineTargetAction(
        gateway: widget.gateway,
        skill: skill,
        target: target,
        action: action,
      );
      await _refreshManagedSkill(removeWhenMissing: true);
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
        builder: (context) =>
            UpdatePlanDialog(gateway: widget.gateway, skill: skill, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await _refreshManagedSkill(checkUpdateState: true);
      }
    } catch (caught) {
      result = exceptionResult(caught);
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
    final operation = ref.read(
      installOperationProvider(
        skill.skillId.isEmpty ? skill.inventoryKey : skill.skillId,
      ),
    );
    late List<Object> values;
    try {
      values = await Future.wait([
        ref.read(agentCatalogProvider.notifier).ensureLoaded(),
        widget.gateway.loadAddedProjects(),
        widget.gateway.loadRiskPolicy(),
      ]);
    } catch (caught) {
      if (mounted) {
        setState(() {
          installingMore = false;
          result = exceptionResult(caught);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => installingMore = false);
    try {
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
          existingTargets: skill.targets,
          onProjectAdded: (project) {
            projects = [...projects, project];
          },
        ),
        (choice) async {
          final submission = await submitInstallationRequest(
            context,
            operation,
            InstallationSubmissionRequest(
              choice: choice,
              skill: summary,
              immutableVersion: currentDetail.immutableVersion,
              repositorySkills: [summary],
              riskPolicy: values[2] as PersonalRiskPolicy,
            ),
          );
          if (submission.succeeded) {
            await _refreshManagedSkill();
          }
          return submission;
        },
      );
    } catch (caught) {
      result = exceptionResult(caught);
    }
    if (mounted) setState(() {});
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
      result = exceptionResult(caught);
    }
    if (mounted) setState(() => exporting = false);
  }

  Future<bool> _refreshManagedSkill({
    bool removeWhenMissing = false,
    bool checkUpdateState = false,
  }) async {
    final refreshed = await ref
        .read(libraryProvider.notifier)
        .refreshEntry(LibraryEntryQuery.byInventoryKey(skill.inventoryKey));
    if (!mounted) return false;
    final entry = refreshed.entry;
    if (entry == null) {
      if (removeWhenMissing) await widget.onRemoved();
      return false;
    }
    skill = entry;
    await load();
    if (checkUpdateState) await _checkUpdateState();
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    body: Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SkillDetailPageBody(
            scrollKey: const Key('installed-detail-scroll-view'),
            controller: detailScrollController,
            hero: SkillDetailHero(
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
                InstallationScopePanel(
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
