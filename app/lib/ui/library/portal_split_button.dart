/*
 * [INPUT]: Depends on Flutter animation, blur, reduced-motion settings, native SkillsGo buttons, and Portal Labs SplitButtonInteraction motion values.
 * [OUTPUT]: Provides the persistent management-to-confirm morph that reveals Cancel while preserving one primary button identity.
 * [POS]: Serves as the Library-local vendored adaptation of Portal Labs 0.34.0 SplitButtonInteraction for External Adoption Review.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _PortalMorphingAdoptionButton extends StatefulWidget {
  const _PortalMorphingAdoptionButton({
    required this.expanded,
    required this.height,
    required this.collapsedLabel,
    required this.collapsedLabelWidget,
    required this.collapsedTrailing,
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
  final Widget collapsedLabelWidget;
  final Widget collapsedTrailing;
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
    extends State<_PortalMorphingAdoptionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 360),
    value: widget.expanded ? 1 : 0,
  );
  late final Animation<double> expansion = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInOutCubic,
  );
  bool collapsing = false;

  @override
  void didUpdateWidget(covariant _PortalMorphingAdoptionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded || collapsing) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = widget.expanded ? 1 : 0;
    } else if (widget.expanded) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  Future<void> collapse() async {
    if (collapsing) return;
    collapsing = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 0;
    } else {
      await controller.reverse();
    }
    if (mounted) widget.onCollapseComplete();
    collapsing = false;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final factor = expansion.value < 0 ? 0.0 : expansion.value;
        final visual = controller.value.clamp(0.0, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                widthFactor: factor,
                child: Opacity(
                  opacity: visual,
                  child: SizedBox(
                    height: widget.height,
                    child: PrimaryCapsuleButton(
                      key: const Key('library-adoption-review-exit'),
                      label: widget.cancelLabel,
                      height: widget.height,
                      horizontalPadding: 18,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                      hoverBackgroundColor: Color.alphaBlend(
                        Theme.of(context).colorScheme.onSecondaryContainer
                            .withValues(alpha: .08),
                        Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      onPressed: collapse,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * visual),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                height: widget.height,
                child: PrimaryCapsuleButton(
                  key: widget.expanded
                      ? const Key('library-adoption-review-confirm')
                      : const Key('library-adoption-review-enter'),
                  label: widget.expanded
                      ? widget.confirmLabel
                      : widget.collapsedLabel,
                  height: widget.height,
                  horizontalPadding: 18,
                  labelWidget: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: widget.expanded
                        ? Text(
                            widget.confirmLabel,
                            key: const ValueKey('adoption-confirm-label'),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('adoption-entry-label'),
                            child: widget.collapsedLabelWidget,
                          ),
                  ),
                  trailingWidget: widget.expanded
                      ? null
                      : widget.collapsedTrailing,
                  disabledBackgroundColor: context.skillsComponents.primaryRest,
                  disabledForegroundColor: context
                      .skillsComponents
                      .primaryForeground
                      .withValues(alpha: .78),
                  onPressed: widget.expanded
                      ? (widget.confirmEnabled ? widget.onConfirm : null)
                      : widget.onExpand,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
