/*
 * [INPUT]: Depends on Library selection identity, selected entries, removal/update callbacks, motion preferences, and scope toggle state.
 * [OUTPUT]: Provides scope grouping, a removal-only stable selection bar, source labels, and the All/SkillsGo Managed/Other Installation/Updates filter dropdown with Package update count.
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
  const _LibrarySelectionBarTransition({super.key, required this.child});

  final Widget? child;

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
    required this.operating,
    required this.confirmingRemoval,
    required this.onClear,
    required this.onRequestRemove,
    required this.onCancelRemove,
    required this.onConfirmRemove,
  });

  final int selectedCount;
  final bool operating;
  final bool confirmingRemoval;
  final VoidCallback onClear;
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
                        duration: const Duration(milliseconds: 220),
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

class _LibraryScopeToggle extends StatefulWidget {
  const _LibraryScopeToggle({
    required this.filter,
    required this.updateCount,
    required this.onChanged,
  });

  final _LibraryFilter filter;
  final int updateCount;
  final ValueChanged<_LibraryFilter> onChanged;

  @override
  State<_LibraryScopeToggle> createState() => _LibraryScopeToggleState();
}

class _LibraryScopeToggleState extends State<_LibraryScopeToggle> {
  final controller = MultiSelectController<_LibraryFilter>();
  bool syncing = false;

  List<DropdownItem<_LibraryFilter>> get items => [
    DropdownItem(
      label: context.l10n.all,
      value: _LibraryFilter.all,
      selected: widget.filter == _LibraryFilter.all,
    ),
    DropdownItem(
      label: context.l10n.libraryImportedSkills,
      value: _LibraryFilter.managed,
      selected: widget.filter == _LibraryFilter.managed,
    ),
    DropdownItem(
      label: context.l10n.libraryLocalSkills,
      value: _LibraryFilter.otherInstallation,
      selected: widget.filter == _LibraryFilter.otherInstallation,
    ),
    DropdownItem(
      label: context.l10n.updatesOnly,
      value: _LibraryFilter.updates,
      selected: widget.filter == _LibraryFilter.updates,
    ),
  ];

  String _label(_LibraryFilter filter) => switch (filter) {
    _LibraryFilter.all => context.l10n.all,
    _LibraryFilter.managed => context.l10n.libraryImportedSkills,
    _LibraryFilter.otherInstallation => context.l10n.libraryLocalSkills,
    _LibraryFilter.updates => context.l10n.updatesOnly,
  };

  String _tooltip(_LibraryFilter filter) => switch (filter) {
    _LibraryFilter.all => context.l10n.libraryFilterTooltip,
    _LibraryFilter.managed => context.l10n.libraryFilterManagedTooltip,
    _LibraryFilter.otherInstallation => context.l10n.libraryFilterOtherTooltip,
    _LibraryFilter.updates => context.l10n.libraryFilterUpdatesTooltip,
  };

  List<List<dynamic>> _icon(_LibraryFilter filter) => switch (filter) {
    _LibraryFilter.all => HugeIcons.strokeRoundedLayers01,
    _LibraryFilter.managed => HugeIcons.strokeRoundedCheckmarkCircle02,
    _LibraryFilter.otherInstallation => HugeIcons.strokeRoundedFolderOpen,
    _LibraryFilter.updates => HugeIcons.strokeRoundedArrowReloadVertical,
  };

  @override
  void didUpdateWidget(covariant _LibraryScopeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter ||
        oldWidget.updateCount != widget.updateCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.isDisposed) return;
        syncing = true;
        controller.setItems(items);
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    final selected = widget.filter;
    return _LibraryFilterHoverDescription(
      message: _tooltip(selected),
      child: Semantics(
        key: const Key('library-update-filter'),
        label: _label(selected),
        button: true,
        excludeSemantics: true,
        child: SizedBox(
          width: 192,
          height: 36,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: OverflowBox(
                  alignment: AlignmentDirectional.centerStart,
                  minWidth: 252,
                  maxWidth: 252,
                  child: MultiDropdown<_LibraryFilter>(
                    controller: controller,
                    items: items,
                    singleSelect: true,
                    closeOnBackButton: false,
                    fieldDecoration: FieldDecoration(
                      hintText: '',
                      showClearIcon: false,
                      animateSuffixIcon: false,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      suffixIcon: null,
                    ),
                    dropdownDecoration: DropdownDecoration(
                      backgroundColor: colors.surfaceMuted,
                      elevation: 5,
                      maxHeight: 240,
                      marginTop: 6,
                      borderRadius: BorderRadius.circular(14),
                      listPadding: const EdgeInsets.symmetric(vertical: 6),
                      animationDuration: const Duration(milliseconds: 180),
                      animationCurve: Curves.easeOutCubic,
                    ),
                    itemBuilder: (item, index, onTap) =>
                        _LibraryFilterHoverDescription(
                          message: _tooltip(item.value),
                          child: Semantics(
                            label: item.label,
                            button: true,
                            selected: item.selected,
                            child: ExcludeSemantics(
                              child: InkWell(
                                onTap: onTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    children: [
                                      HugeIcon(
                                        icon: _icon(item.value),
                                        size: 17,
                                        strokeWidth: 1.8,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.value ==
                                              _LibraryFilter.updates &&
                                          widget.updateCount > 0) ...[
                                        const SizedBox(width: 10),
                                        _LibraryFilterCountBadge(
                                          count: widget.updateCount,
                                        ),
                                      ],
                                      const SizedBox(width: 12),
                                      AnimatedOpacity(
                                        opacity: item.selected ? 1 : 0,
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        child: const HugeIcon(
                                          icon: HugeIcons.strokeRoundedTick01,
                                          size: 18,
                                          strokeWidth: 1.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    selectedItemBuilder: (_) => const SizedBox.shrink(),
                    chipDecoration: const ChipDecoration(
                      padding: EdgeInsets.zero,
                      spacing: 0,
                      runSpacing: 0,
                    ),
                    onSelectionChange: (values) {
                      if (syncing || values.isEmpty) return;
                      widget.onChanged(values.first);
                    },
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.borderMuted),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                end: 28,
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: _icon(selected),
                          size: 16,
                          strokeWidth: 1.8,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _label(selected),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (selected == _LibraryFilter.updates &&
                            widget.updateCount > 0) ...[
                          const SizedBox(width: 6),
                          _LibraryFilterCountBadge(
                            key: ValueKey(
                              'subscription-switch-badge-${_label(selected)}',
                            ),
                            count: widget.updateCount,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 10,
                top: 11.5,
                child: IgnorePointer(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 13,
                    strokeWidth: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryFilterHoverDescription extends StatefulWidget {
  const _LibraryFilterHoverDescription({
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<_LibraryFilterHoverDescription> createState() =>
      _LibraryFilterHoverDescriptionState();
}

class _LibraryFilterHoverDescriptionState
    extends State<_LibraryFilterHoverDescription> {
  OverlayEntry? _entry;
  Offset _position = Offset.zero;

  OverlayState? get _overlay => Overlay.maybeOf(context, rootOverlay: true);

  void _updatePosition(Offset globalPosition) {
    final overlay = _overlay;
    if (overlay == null) return;
    final renderObject = overlay.context.findRenderObject();
    _position = renderObject is RenderBox
        ? renderObject.globalToLocal(globalPosition)
        : globalPosition;
    if (_entry == null) {
      _entry = OverlayEntry(builder: _buildOverlay);
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _handleEnter(PointerEnterEvent event) => _updatePosition(event.position);

  void _handleHover(PointerHoverEvent event) => _updatePosition(event.position);

  void _handleExit(PointerExitEvent event) => _removeEntry();

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const width = 320.0;
    final maxLeft = math.max(8.0, size.width - width - 8);
    final left = (_position.dx + 14).clamp(8.0, maxLeft).toDouble();
    final top = (_position.dy + 18)
        .clamp(8.0, math.max(8.0, size.height - 80))
        .toDouble();
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          color: scheme.inverseSurface,
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: width),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                widget.message,
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _handleEnter,
    onHover: _handleHover,
    onExit: _handleExit,
    child: widget.child,
  );
}

class _LibraryFilterCountBadge extends StatelessWidget {
  const _LibraryFilterCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
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
