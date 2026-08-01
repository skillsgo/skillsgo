/*
 * [INPUT]: Depends on Portal Labs 0.34.0 SplitButtonInteraction, HugeIcons, SkillsGo semantic component and typography tokens, and the controlled External Adoption callbacks.
 * [OUTPUT]: Provides a controlled handoff button that uses the Portal Labs split morph while preserving localized labels, stable test hooks, and the review flow's externally owned expanded state.
 * [POS]: Serves as the Library-local adapter between Portal Labs' split interaction and the External Adoption Review header.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _PortalMorphingAdoptionButton extends StatefulWidget {
  const _PortalMorphingAdoptionButton({
    required this.expanded,
    required this.height,
    required this.collapsedLabel,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmEnabled,
    required this.onExpand,
    required this.onCollapseComplete,
    required this.onConfirm,
  });

  final bool expanded;
  final double height;
  final String collapsedLabel;
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmEnabled;
  final VoidCallback onExpand;
  final VoidCallback onCollapseComplete;
  final VoidCallback onConfirm;

  @override
  State<_PortalMorphingAdoptionButton> createState() =>
      _PortalMorphingAdoptionButtonState();
}

class _PortalMorphingAdoptionButtonState
    extends State<_PortalMorphingAdoptionButton> {
  late final portal.SplitButtonController controller;
  bool synchronizing = false;
  late bool lastNotifiedExpanded;

  @override
  void initState() {
    super.initState();
    controller = portal.SplitButtonController();
    lastNotifiedExpanded = widget.expanded;
    controller.addListener(_handleControllerChanged);
    if (widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.expanded && !controller.isExpanded) {
          synchronizing = true;
          controller.expand();
          synchronizing = false;
        }
      });
    }
  }

  void _handleControllerChanged() {
    final nextExpanded = controller.isExpanded;
    if (nextExpanded == lastNotifiedExpanded) return;
    lastNotifiedExpanded = nextExpanded;
    if (synchronizing || !mounted) return;
    if (nextExpanded) {
      widget.onExpand();
    } else {
      widget.onCollapseComplete();
    }
  }

  @override
  void didUpdateWidget(covariant _PortalMorphingAdoptionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == controller.isExpanded) return;
    synchronizing = true;
    if (widget.expanded) {
      controller.expand();
    } else {
      controller.collapse();
    }
    synchronizing = false;
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    controller.dispose();
    super.dispose();
  }

  Widget _tapRegion({
    required Key key,
    required String label,
    required VoidCallback onTap,
    required bool enabled,
    Widget? visual,
  }) {
    return Semantics(
      key: key,
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: visual ?? const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final foreground = components.primaryForeground;
    final splitButton = portal.SplitButtonInteraction(
      key: const Key('library-adoption-review-split-button'),
      initialLabel: widget.collapsedLabel,
      controller: controller,
      spacing: 8,
      actions: [
        portal.SplitAction(
          label: widget.confirmLabel,
          closeOnTap: false,
          onTap: () {},
        ),
      ],
      style: portal.SplitButtonStyle(
        backgroundColor: components.primaryRest,
        foregroundColor: foreground,
        activeBackgroundColor: components.primaryRest,
        activeForegroundColor: foreground,
        borderRadius: BorderRadius.circular(widget.height / 2),
        height: widget.height,
        textStyle: context.skillsTypography.label.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          clipBehavior: Clip.antiAlias,
          child: ExcludeSemantics(child: splitButton),
        ),
        if (widget.expanded) ...[
          PositionedDirectional(
            start: 0,
            width: 56,
            top: 0,
            bottom: 0,
            child: _tapRegion(
              key: const Key('library-adoption-review-exit'),
              label: widget.cancelLabel,
              onTap: controller.toggle,
              enabled: true,
              visual: DecoratedBox(
                decoration: BoxDecoration(
                  color: components.primaryRest,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
                child: Center(
                  child: HugeIcon(
                    key: const Key('library-adoption-review-cancel-icon'),
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 20,
                    strokeWidth: 1.8,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 64,
            end: 0,
            top: 0,
            bottom: 0,
            child: _tapRegion(
              key: const Key('library-adoption-review-confirm'),
              label: widget.confirmLabel,
              onTap: widget.onConfirm,
              enabled: widget.confirmEnabled,
            ),
          ),
        ] else
          Positioned.fill(
            child: _tapRegion(
              key: const Key('library-adoption-review-enter'),
              label: widget.collapsedLabel,
              onTap: controller.toggle,
              enabled: true,
            ),
          ),
      ],
    );
  }
}
