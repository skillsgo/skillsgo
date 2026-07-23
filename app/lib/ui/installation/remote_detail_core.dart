/*
 * [INPUT]: Depends on the Installation journey library, gateway, operation controller, detail state, and navigation callbacks.
 * [OUTPUT]: Provides the public RemoteDetailScreen plus loading, install, target-management, lifecycle, and root build behavior.
 * [POS]: Serves as the state-owning core of the remote Skill detail journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

class RemoteDetailScreen extends ConsumerStatefulWidget {
  const RemoteDetailScreen({
    super.key,
    required this.gateway,
    required this.skill,
    required this.operation,
    required this.onBack,
    required this.onViewLibrary,
    this.openPlanOnLoad = false,
  });
  final SkillsGateway gateway;
  final SkillSummary skill;
  final InstallOperationController operation;
  final Future<void> Function({required bool installed}) onBack;
  final VoidCallback onViewLibrary;
  final bool openPlanOnLoad;

  @override
  ConsumerState<RemoteDetailScreen> createState() => RemoteDetailScreenState();
}

class RemoteDetailScreenState extends ConsumerState<RemoteDetailScreen> {
  final detailScrollController = ScrollController();
  SkillDetail? detail;
  Object? error;
  bool loading = true;
  bool loadingCatalog = false;
  bool managingTarget = false;
  CliStatus? cliStatus;
  List<AddedProject> addedProjects = const [];
  List<SkillSummary> repositorySkills = const [];
  PersonalRiskPolicy riskPolicy = const PersonalRiskPolicy();
  bool didOpenInitialPlan = false;
  bool get operating => widget.operation.operating;
  InstallationExecution? get execution => widget.operation.execution;

  @override
  void initState() {
    super.initState();
    widget.operation.addListener(_operationChanged);
    detailScrollController.addListener(_detailScrollChanged);
    unawaited(load());
  }

  void _detailScrollChanged() {
    if (mounted) setState(() {});
  }

  void _operationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.operation.removeListener(_operationChanged);
    detailScrollController
      ..removeListener(_detailScrollChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final detailRequest = widget.gateway.loadRemoteDetail(widget.skill);
    final cliRequest = widget.gateway.detectCli();
    final projectsRequest = widget.gateway.loadAddedProjects();
    final policyRequest = widget.gateway.loadRiskPolicy();
    try {
      detail = await detailRequest;
    } catch (caught) {
      error = caught;
      if (mounted) setState(() => loading = false);
      return;
    }
    if (!mounted) return;
    setState(() => loading = false);
    try {
      final values = await Future.wait([
        cliRequest,
        projectsRequest,
        policyRequest,
      ]);
      cliStatus = values[0] as CliStatus;
      addedProjects = values[1] as List<AddedProject>;
      riskPolicy = values[2] as PersonalRiskPolicy;
      if (mounted) setState(() {});
      repositorySkills = await loadRepositorySkills(
        widget.gateway,
        widget.skill,
        detail!,
      );
    } on Object {
      repositorySkills = [widget.skill];
    }
    if (mounted) setState(() {});
  }

  Future<void> install(InstallLocationMenuPresenter present) async {
    if (detail == null || loadingCatalog) return;
    setState(() => loadingCatalog = true);
    late AgentCatalog catalog;
    try {
      catalog = await ref.read(agentCatalogProvider.notifier).ensureLoaded();
    } finally {
      if (mounted) setState(() => loadingCatalog = false);
    }
    if (!mounted) return;
    await present(
      InstallLocationMenuRequest(
        gateway: widget.gateway,
        catalog: catalog,
        detail: detail!,
        projects: addedProjects,
        repositorySkills: repositorySkills,
        onProjectAdded: (project) {
          final index = addedProjects.indexWhere(
            (item) => item.id == project.id,
          );
          if (index < 0) {
            addedProjects = [...addedProjects, project];
          } else {
            addedProjects = [...addedProjects]..[index] = project;
          }
        },
      ),
      (choice) async {
        final submission = await submitInstallationRequest(
          context,
          widget.operation,
          InstallationSubmissionRequest(
            choice: choice,
            skill: widget.skill,
            immutableVersion: widget.skill.latestVersion,
            repositorySkills: repositorySkills,
            riskPolicy: riskPolicy,
          ),
        );
        if (submission.succeeded && mounted) {
          ref.invalidate(libraryProvider);
          unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
          setState(() {});
        }
        return submission;
      },
    );
  }

  Future<void> manageTargetInline(
    SkillInstallationTarget target,
    TargetManagementAction action,
  ) async {
    if (managingTarget) return;
    setState(() => managingTarget = true);
    try {
      final query = LibraryEntryQuery.byCoordinate(
        repositoryId: widget.skill.repositoryId,
        skillName: widget.skill.name,
        targetPath: target.path,
        agent: target.agent,
      );
      final before = await ref
          .read(libraryProvider.notifier)
          .refreshEntry(query, refreshAgents: false);
      final installed = before.entry;
      if (installed == null) {
        throw StateError('The installed Skill is no longer available.');
      }
      await executeInlineTargetAction(
        gateway: widget.gateway,
        skill: installed,
        target: target,
        action: action,
      );
      final after = await ref
          .read(libraryProvider.notifier)
          .refreshEntry(
            LibraryEntryQuery.byCoordinate(
              repositoryId: widget.skill.repositoryId,
              skillName: widget.skill.name,
            ),
          );
      final refreshed = await widget.gateway.loadRemoteDetail(widget.skill);
      if (!mounted) return;
      setState(() {
        detail = refreshed;
        addedProjects = after.projects;
      });
    } finally {
      if (mounted) setState(() => managingTarget = false);
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          widget.onBack(installed: execution?.hasSuccess == true),
      const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () =>
          widget.onBack(installed: execution?.hasSuccess == true),
    },
    child: Focus(
      autofocus: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _content(),
            Align(alignment: Alignment.topCenter, child: _detailToolbar()),
          ],
        ),
      ),
    ),
  );
}
