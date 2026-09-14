/*
 * [INPUT]: Depends on the menu contracts, App-scoped installation task presentation, focus/keyboard state, animation, and async request presentation.
 * [OUTPUT]: Provides the public anchored menu widget and overlay lifecycle that presents one Installation Request surface at a time, closes after accepted submission, and lets the non-blocking App task stack own subsequent execution feedback.
 * [POS]: Serves as the overlay and focus owner of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

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
    result?.complete(null);
    final completer = Completer<bool?>();
    setState(() {
      request = next;
      submit = nextSubmit;
      result = completer;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    controller.open();
    return completer.future;
  }

  void _complete(InstallLocationChoice choice) {
    final execute = submit;
    if (execute == null || submitting) return;
    final summary = request?.summary;
    final taskController = InstallationTaskScope.of(context);
    final taskId = summary == null ? null : taskController.start(summary);
    final failureTitle = AppLocalizations.of(context).installationFailed;
    setState(() => submitting = true);
    result?.complete(null);
    result = null;
    controller.close();
    unawaited(
      _runSubmission(execute, choice, taskController, taskId, failureTitle),
    );
  }

  Future<void> _runSubmission(
    Future<InstallLocationSubmission> Function(InstallLocationChoice choice)
    execute,
    InstallLocationChoice choice,
    InstallationTaskController taskController,
    String? taskId,
    String failureTitle,
  ) async {
    late InstallLocationSubmission outcome;
    try {
      outcome = await execute(choice);
    } on Object catch (error) {
      outcome = InstallLocationSubmission.failure(
        title: failureTitle,
        message: error.toString(),
      );
    }
    if (outcome.succeeded) {
      if (taskId != null) taskController.succeed(taskId);
      return;
    }
    if (outcome.cancelled) {
      if (taskId != null) taskController.dismiss(taskId);
      return;
    }
    if (taskId != null) {
      taskController.fail(taskId, outcome.message!);
    }
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
  }

  @override
  void dispose() {
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
                            submitting: submitting,
                          )
                        : _InstallLocationCard(
                            summary: current.summary!,
                            gateway: current.gateway!,
                            catalog: current.catalog!,
                            detail: current.detail!,
                            moduleSkills: current.moduleSkills!,
                            moduleSkillsFuture: current.moduleSkillsFuture,
                            preferredAction: current.preferredAction,
                            initialProjects: current.projects!,
                            onProjectAdded: current.onProjectAdded!,
                            onSubmit: _complete,
                            submitting: submitting,
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
