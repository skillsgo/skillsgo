/*
 * [INPUT]: Depends on Library selection identity, selected entries, removal/update callbacks, motion preferences, and scope toggle state.
 * [OUTPUT]: Provides scope grouping, a stable selection bar with an inline two-click removal action, source labels, and All/Updates toggle.
 * [POS]: Serves as the multi-selection and scope-control segment of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _InstallationScopeGroup {
  const _InstallationScopeGroup({required this.project, required this.agents});

  final AddedProject? project;
  final List<String> agents;

  String semanticLabel(String Function(String) agentLabel) =>
      '${project?.name ?? 'Global'}: ${agents.map(agentLabel).join(', ')}';
}

List<_InstallationScopeGroup> _installationScopeGroups(
  InstalledSkill skill,
  List<AddedProject> projects,
) {
  final userAgents = <String>{};
  final projectAgents = <String, Set<String>>{};
  for (final target in skill.targets) {
    if (target.scope == InstallationScope.global) {
      userAgents.add(target.agent);
    } else {
      projectAgents
          .putIfAbsent(target.projectRoot, () => <String>{})
          .add(target.agent);
    }
  }
  AddedProject projectFor(String root) =>
      projects.where((project) => project.path == root).firstOrNull ??
      AddedProject(
        id: root,
        name: p.basename(root),
        path: root,
        accessState: ProjectAccessState.inaccessible,
      );
  return [
    if (userAgents.isNotEmpty)
      _InstallationScopeGroup(
        project: null,
        agents: userAgents.toList(growable: false),
      ),
    for (final entry in projectAgents.entries)
      _InstallationScopeGroup(
        project: projectFor(entry.key),
        agents: entry.value.toList(growable: false),
      ),
  ];
}

String _librarySelectionKey(InstalledSkill skill) => skill.inventoryKey.isEmpty
    ? '${skill.path}\u0000${skill.name}'
    : skill.inventoryKey;

class _LibrarySelectionBarTransition extends StatefulWidget {
  const _LibrarySelectionBarTransition({
    super.key,
    required this.child,
    required this.disableAnimations,
  });

  final Widget? child;
  final bool disableAnimations;

  @override
  State<_LibrarySelectionBarTransition> createState() =>
      _LibrarySelectionBarTransitionState();
}

class _LibrarySelectionBarTransitionState
    extends State<_LibrarySelectionBarTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _visibleChild;
  late double _target;

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 41,
  );

  @override
  void initState() {
    super.initState();
    _visibleChild = widget.child;
    _target = widget.child == null ? 0 : 1;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
      value: widget.child == null ? 0 : 1,
      vsync: this,
    );
    _controller.addStatusListener(_handleStatusChanged);
  }

  @override
  void didUpdateWidget(_LibrarySelectionBarTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _visibleChild = widget.child;
      _animateTo(1);
    } else if (oldWidget.child != null) {
      _animateTo(0);
    }
  }

  void _animateTo(double target) {
    _target = target;
    if (widget.disableAnimations) {
      _settleAtTarget(
        _controller.animateTo(
          target,
          duration: Duration(milliseconds: target == 1 ? 200 : 160),
          curve: const Cubic(0.23, 1, 0.32, 1),
        ),
        target,
      );
      return;
    }
    _settleAtTarget(
      _controller.animateWith(
        SpringSimulation(
          _spring,
          _controller.value,
          target,
          _controller.velocity,
        ),
      ),
      target,
    );
  }

  void _settleAtTarget(TickerFuture animation, double target) {
    animation.whenCompleteOrCancel(() {
      if (!mounted || _target != target) return;
      _controller.value = target;
    });
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.child != null) return;
    setState(() => _visibleChild = null);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _visibleChild;
    if (child == null) {
      return const SizedBox.shrink(key: ValueKey('selection-bar-empty'));
    }
    final faded = FadeTransition(
      key: const Key('library-selection-bar-fade-transition'),
      opacity: _controller,
      child: child,
    );
    if (widget.disableAnimations) return faded;
    return SlideTransition(
      key: const Key('library-selection-bar-slide-transition'),
      position: Tween<Offset>(
        begin: const Offset(0, .25),
        end: Offset.zero,
      ).animate(_controller),
      child: faded,
    );
  }
}

class _LibrarySelectionBar extends StatelessWidget {
  const _LibrarySelectionBar({
    super.key,
    required this.selectedCount,
    required this.updateableCount,
    required this.operating,
    required this.confirmingRemoval,
    required this.onClear,
    required this.onUpdate,
    required this.onRequestRemove,
    required this.onCancelRemove,
    required this.onConfirmRemove,
  });

  final int selectedCount;
  final int updateableCount;
  final bool operating;
  final bool confirmingRemoval;
  final VoidCallback onClear;
  final VoidCallback onUpdate;
  final VoidCallback onRequestRemove;
  final VoidCallback onCancelRemove;
  final VoidCallback onConfirmRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      onKeyEvent: (_, event) {
        if (confirmingRemoval &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onCancelRemove();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        key: const Key('library-selection-bar'),
        color: scheme.inverseSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: scheme.shadow.withValues(alpha: .32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.skillsSelected(selectedCount),
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('library-clear-selection'),
                tooltip: context.l10n.clearSelection,
                onPressed: operating ? null : onClear,
                visualDensity: VisualDensity.compact,
                color: scheme.onInverseSurface,
                disabledColor: scheme.onInverseSurface.withValues(alpha: .38),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 17,
                  strokeWidth: 1.8,
                ),
              ),
              SizedBox(
                height: 22,
                child: VerticalDivider(
                  color: scheme.onInverseSurface.withValues(alpha: .18),
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('library-update-selected'),
                onPressed: operating || updateableCount == 0 ? null : onUpdate,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
                  size: 17,
                  strokeWidth: 1.8,
                ),
                label: Text(context.l10n.update),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  disabledBackgroundColor: scheme.onInverseSurface.withValues(
                    alpha: .12,
                  ),
                  disabledForegroundColor: scheme.onInverseSurface.withValues(
                    alpha: .38,
                  ),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              TextButton(
                key: const Key('library-remove-selected'),
                onPressed: operating
                    ? null
                    : confirmingRemoval
                    ? onConfirmRemove
                    : onRequestRemove,
                style: TextButton.styleFrom(
                  foregroundColor:
                      context.skillsComponents.statusDangerOnInverse,
                  disabledForegroundColor: scheme.onInverseSurface.withValues(
                    alpha: .38,
                  ),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  visualDensity: VisualDensity.compact,
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox.square(
                      key: Key('library-remove-icon'),
                      dimension: 20,
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          size: 17,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 20,
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final incoming =
                              child.key ==
                              ValueKey(
                                confirmingRemoval
                                    ? 'library-confirm-remove'
                                    : 'library-remove-label',
                              );
                          final slide = Tween<Offset>(
                            begin: Offset(0, incoming ? .55 : -.55),
                            end: Offset.zero,
                          ).animate(animation);
                          return ClipRect(
                            child: FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          confirmingRemoval
                              ? context.l10n.confirmRemoveSkillsAction
                              : context.l10n.remove,
                          key: ValueKey(
                            confirmingRemoval
                                ? 'library-confirm-remove'
                                : 'library-remove-label',
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _installedSourceLabel(BuildContext context, InstalledSkill skill) {
  if (skill.packagePath.isEmpty) return context.l10n.localSource;
  return skill.packagePath;
}

class _LibraryScopeToggle extends StatelessWidget {
  const _LibraryScopeToggle({
    required this.updatesOnly,
    required this.onChanged,
  });

  final bool updatesOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SubscriptionSegmentedSwitch(
      key: const Key('library-update-filter'),
      options: [
        SubscriptionSwitchOption(
          label: context.l10n.all,
          icon: HugeIcons.strokeRoundedLayers01,
        ),
        SubscriptionSwitchOption(
          label: context.l10n.updatesOnly,
          icon: HugeIcons.strokeRoundedArrowReloadVertical,
        ),
      ],
      selectedIndex: updatesOnly ? 1 : 0,
      onChanged: (index) => onChanged(index == 1),
    );
  }
}

class _LibraryAddProjectAction extends StatelessWidget {
  const _LibraryAddProjectAction({
    required this.adding,
    required this.onPressed,
  });

  final bool adding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        key: const Key('library-add-project'),
        onPressed: adding ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: AlignmentDirectional.centerStart,
          textStyle: context.skillsTypography.bodySecondary,
        ),
        child: Row(
          children: [
            if (adding)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else
              HugeIcon(
                icon: HugeIcons.strokeRoundedFolderAdd,
                size: 18,
                strokeWidth: 1.5,
                color: foreground,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.addProject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
