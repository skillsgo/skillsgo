/*
 * [INPUT]: Depends on exact installation targets, reviewed removal operations, localized status copy, and confirmation controls.
 * [OUTPUT]: Provides inline removal execution plus expandable exact-target detail and confirmation UI.
 * [POS]: Serves as the exact-target action segment of detail journeys.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

class _InstallationTargetDetail extends StatefulWidget {
  const _InstallationTargetDetail({required this.target, this.onRemove});
  final SkillInstallationTarget target;
  final Future<void> Function()? onRemove;

  @override
  State<_InstallationTargetDetail> createState() =>
      _InstallationTargetDetailState();
}

class _InstallationTargetDetailState extends State<_InstallationTargetDetail> {
  bool confirmingRemoval = false;
  bool operating = false;
  Object? actionError;

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null || operating) return;
    setState(() {
      operating = true;
      actionError = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => actionError = error);
    } finally {
      if (mounted) {
        setState(() {
          operating = false;
          confirmingRemoval = false;
        });
      }
    }
  }

  Widget _actionButton(
    BuildContext context, {
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    bool danger = false,
    bool busy = false,
  }) {
    final color = danger
        ? context.skillsComponents.statusDangerSolid
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return TextButton(
      key: key,
      onPressed: busy ? null : onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 26)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 7),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStatePropertyAll(color),
        overlayColor: WidgetStatePropertyAll(color.withValues(alpha: .07)),
        textStyle: WidgetStatePropertyAll(context.skillsTypography.metadata),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
      child: busy
          ? SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 1.3, color: color),
            )
          : Text(label),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: AgentLogo(
                agentId: widget.target.agent,
                displayName: agentDisplayLabel(widget.target.agent),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    agentDisplayLabel(widget.target.agent),
                    textDirection: contentTextDirection(widget.target.agent),
                    style: context.skillsTypography.bodySecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tooltip(
                      message: widget.target.path,
                      child: Text(
                        widget.target.path,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.skillsTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (widget.target.health != InstallationHealth.healthy) ...[
              installationHealthChip(context, widget.target.health),
              const SizedBox(width: 7),
            ],
            if (widget.target.health == InstallationHealth.healthy &&
                widget.onRemove != null) ...[
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    alignment: AlignmentDirectional.centerEnd,
                    child: child,
                  ),
                ),
                child: confirmingRemoval
                    ? Row(
                        key: const ValueKey('confirm-removal-actions'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(
                            context,
                            label: context.l10n.cancel,
                            onPressed: () =>
                                setState(() => confirmingRemoval = false),
                          ),
                          const SizedBox(width: 2),
                          _actionButton(
                            context,
                            key: ValueKey(
                              'confirm-remove-installation-target-${widget.target.path}',
                            ),
                            label: context.l10n.confirmRemoveTarget,
                            onPressed: () => _run(widget.onRemove),
                            danger: true,
                            busy: operating,
                          ),
                        ],
                      )
                    : _actionButton(
                        context,
                        key: ValueKey(
                          'remove-installation-target-${widget.target.path}',
                        ),
                        label: context.l10n.remove,
                        onPressed: () =>
                            setState(() => confirmingRemoval = true),
                        danger: true,
                      ),
              ),
            ],
            const SizedBox(width: 18),
          ],
        ),
        if (actionError != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 34,
              top: 4,
              end: 18,
            ),
            child: Text(
              failureCopy(context, actionError!).message,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: context.skillsComponents.statusDanger,
                fontSize: 11,
              ),
            ),
          ),
      ],
    ),
  );
}
