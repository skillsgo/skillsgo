/*
 * [INPUT]: Depends on the menu contracts, full-width responsive toast overlay, focus/keyboard state, animation, and async request presentation.
 * [OUTPUT]: Provides the public anchored menu widget and overlay lifecycle that presents one Installation Request surface at a time, preserves the selection when a destructive confirmation is cancelled, and exposes interactive responsive operation feedback.
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
  final toastController = StackedToastController();
  OverlayEntry? toastOverlay;
  Timer? toastCleanupTimer;
  bool preserveToastAfterClose = false;
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
    toastCleanupTimer?.cancel();
    result?.complete(null);
    final completer = Completer<bool?>();
    setState(() {
      request = next;
      submit = nextSubmit;
      result = completer;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    _ensureToastOverlay();
    controller.open();
    return completer.future;
  }

  void _ensureToastOverlay() {
    if (toastOverlay != null) return;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 320,
        child: Material(
          color: Colors.transparent,
          child: StackedToastInteraction(
            controller: toastController,
            style: const StackedToastStyle(topMargin: 16, maxStackedItems: 3),
          ),
        ),
      ),
    );
    toastOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  Future<void> _complete(InstallLocationChoice choice) async {
    final execute = submit;
    if (execute == null || submitting) return;
    setState(() => submitting = true);
    late InstallLocationSubmission outcome;
    try {
      outcome = await execute(choice);
    } on Object catch (error) {
      if (!mounted) return;
      outcome = InstallLocationSubmission.failure(
        title: AppLocalizations.of(context).installationFailed,
        message: error.toString(),
      );
    }
    if (!mounted) return;
    setState(() => submitting = false);
    if (outcome.succeeded) {
      preserveToastAfterClose = true;
      toastController.show(
        StackedToastItem(
          id: 'install-success-${DateTime.now().microsecondsSinceEpoch}',
          type: StackedToastType.success,
          title: AppLocalizations.of(context).installationSucceeded,
          message: AppLocalizations.of(context).installationSucceededMessage,
          duration: const Duration(seconds: 4),
          actionLabel: MaterialLocalizations.of(context).closeButtonLabel,
        ),
      );
      toastCleanupTimer?.cancel();
      toastCleanupTimer = Timer(const Duration(milliseconds: 4500), () {
        toastOverlay?.remove();
        toastOverlay = null;
      });
      result?.complete(true);
      result = null;
      controller.close();
      return;
    }
    if (outcome.cancelled) return;
    toastController.show(
      StackedToastItem(
        id: 'install-error-${DateTime.now().microsecondsSinceEpoch}',
        type: StackedToastType.error,
        title: outcome.title!,
        message: outcome.message!,
        duration: const Duration(seconds: 6),
        actionLabel: MaterialLocalizations.of(context).closeButtonLabel,
      ),
    );
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
    if (preserveToastAfterClose) {
      preserveToastAfterClose = false;
    } else {
      toastOverlay?.remove();
      toastOverlay = null;
    }
  }

  @override
  void dispose() {
    toastCleanupTimer?.cancel();
    toastOverlay?.remove();
    toastOverlay = null;
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
