/*
 * [INPUT]: Depends on one Added Project identity, hover/focus state, exact remove callback, and project icon presentation.
 * [OUTPUT]: Provides the accessible removable project item used by the Onboarding project strip.
 * [POS]: Serves as the project-item presentation segment of Mandatory Onboarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../onboarding_screen.dart';

class _OnboardingProjectItem extends StatefulWidget {
  const _OnboardingProjectItem({
    super.key,
    required this.project,
    required this.onRemove,
  });

  final AddedProject project;
  final VoidCallback onRemove;

  @override
  State<_OnboardingProjectItem> createState() => _OnboardingProjectItemState();
}

class _OnboardingProjectItemState extends State<_OnboardingProjectItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showRemove = _hovered || _focused;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Row(
          children: [
            ProjectIdentityIcon(project: widget.project, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Tooltip(
                message: '${widget.project.name}\n${widget.project.path}',
                child: Text(
                  widget.project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.label,
                ),
              ),
            ),
            const SizedBox(width: 3),
            AnimatedOpacity(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              opacity: showRemove ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showRemove,
                child: SkillsTooltip(
                  builder: (_) => Text(l10n.removeFromList),
                  child: Semantics(
                    label: l10n.removeProjectTitle(widget.project.name),
                    button: true,
                    child: ExcludeSemantics(
                      child: IconButton(
                        key: ValueKey(
                          'onboarding-remove-project-${widget.project.id}',
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        style: const ButtonStyle(
                          shape: WidgetStatePropertyAll(CircleBorder()),
                        ),
                        onPressed: widget.onRemove,
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 13,
                          strokeWidth: 1.8,
                          color: context.skillsColors.foregroundMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
