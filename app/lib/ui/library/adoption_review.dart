/*
 * [INPUT]: Depends on visible External Library entries with optional lock-backed Package hints, CLI-mediated batch Find, localized provenance and management copy, HugeIcons, PackageAvatar, Portal Labs SplitButtonInteraction, single-select MultiDropdown controls, and semantic theme roles.
 * [OUTPUT]: Provides the feature-gated inline Adoption Review with lock-restricted or manual server-ranked exact-name bounded batch matching, a shared structural column grid for headers and rows, avatar-enhanced and match-chip-labeled separated Source options, Package-synchronized single-select Version menus, latest eligible version selection, a side-effect confirmation dialog, reviewed handoff records, and group-bounded sticky morphing actions.
 * [OUTPUT]: Also supports the current External Skills route and native split interaction while leaving Hub transport and filesystem mutation to the Gateway and CLI.
 * [POS]: Serves as the user-reviewed matching presentation inside the Library journey while leaving Hub transport and filesystem mutation to the Gateway and CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

typedef _AdoptionReviewSelection = ({
  InstalledSkill installed,
  AdoptionCandidate candidate,
  String version,
});

class _AdoptionReviewShell extends StatefulWidget {
  const _AdoptionReviewShell({
    required this.skills,
    required this.gateway,
    required this.expanded,
    required this.projects,
    required this.agentLabel,
    required this.onOpen,
    required this.selectedSkillKeys,
    required this.onSelectionChanged,
    required this.onEnter,
    required this.onExit,
    required this.onConfirm,
  });

  final List<InstalledSkill> skills;
  final SkillsGateway gateway;
  final bool expanded;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;
  final ValueChanged<InstalledSkill> onOpen;
  final Set<String> selectedSkillKeys;
  final void Function(InstalledSkill, bool) onSelectionChanged;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final ValueChanged<List<_AdoptionReviewSelection>> onConfirm;

  @override
  State<_AdoptionReviewShell> createState() => _AdoptionReviewShellState();
}

class _AdoptionReviewShellState extends State<_AdoptionReviewShell> {
  final selectedSkillKeys = <String>{};
  final optedOutSkillKeys = <String>{};
  final matches = <String, _AdoptionMatch>{};
  int matchGeneration = 0;
  bool confirmationDialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMatching());
    }
  }

  @override
  void didUpdateWidget(covariant _AdoptionReviewShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSkillKeys = oldWidget.skills.map(_librarySelectionKey).toSet();
    final skillKeys = widget.skills.map(_librarySelectionKey).toSet();
    final inventoryChanged = !setEquals(oldSkillKeys, skillKeys);
    if (!oldWidget.expanded && widget.expanded) {
      _startMatching();
    } else if (oldWidget.expanded && !widget.expanded) {
      matchGeneration++;
    } else if (widget.expanded && inventoryChanged) {
      _startMatching();
    }
  }

  Future<void> _startMatching() async {
    final generation = ++matchGeneration;
    setState(() {
      selectedSkillKeys.clear();
      optedOutSkillKeys.clear();
      matches
        ..clear()
        ..addEntries(
          widget.skills.map(
            (skill) => MapEntry(
              _librarySelectionKey(skill),
              const _AdoptionMatch.loading(),
            ),
          ),
        );
    });
    final queryIndices = <String, int>{};
    final queries = <PackageFindQuery>[];
    for (final skill in widget.skills) {
      final signature =
          '${skill.name.trim().toLowerCase()}\u0000${skill.adoptionPackagePath}';
      queryIndices.putIfAbsent(signature, () {
        final index = queries.length;
        queries.add(
          PackageFindQuery(
            name: skill.name,
            packagePath: skill.adoptionPackagePath,
            description: skill.description,
          ),
        );
        return index;
      });
    }
    try {
      final results = await widget.gateway.findSources(queries, limit: 10);
      if (!mounted || generation != matchGeneration) return;
      setState(() {
        for (final skill in widget.skills) {
          final signature =
              '${skill.name.trim().toLowerCase()}\u0000${skill.adoptionPackagePath}';
          final index = queryIndices[signature];
          _applyCandidates(skill, index == null ? const [] : results[index]);
        }
      });
    } on Object catch (error) {
      if (!mounted || generation != matchGeneration) return;
      setState(() {
        for (final skill in widget.skills) {
          matches[_librarySelectionKey(skill)] = _AdoptionMatch.error(error);
        }
      });
    }
  }

  void _applyCandidates(InstalledSkill skill, List<AdoptionCandidate> skills) {
    final key = _librarySelectionKey(skill);
    final candidates = skills
        .where((candidate) => candidate.name == skill.name)
        .map(
          (candidate) => _AdoptionCandidate(
            skill: candidate,
            matchScore: candidate.matchScore,
          ),
        )
        .toList(growable: false);
    final selected = candidates.firstOrNull;
    matches[key] = _AdoptionMatch.content(
      candidates: candidates,
      selected: selected,
    );
    if (selected != null &&
        selected.skill.versions.isNotEmpty &&
        !optedOutSkillKeys.contains(key)) {
      selectedSkillKeys.add(key);
    }
  }

  Future<void> _retryMatch(InstalledSkill skill) async {
    final key = _librarySelectionKey(skill);
    setState(() => matches[key] = const _AdoptionMatch.loading());
    try {
      final results = await widget.gateway.findSources([
        PackageFindQuery(
          name: skill.name,
          packagePath: skill.adoptionPackagePath,
          description: skill.description,
        ),
      ]);
      if (!mounted) return;
      setState(() => _applyCandidates(skill, results.firstOrNull ?? []));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => matches[key] = _AdoptionMatch.error(error));
    }
  }

  void _selectCandidate(InstalledSkill skill, _AdoptionCandidate candidate) {
    final key = _librarySelectionKey(skill);
    final current = matches[key];
    if (current == null) return;
    setState(() {
      matches[key] = current.select(candidate);
      final selectedVersion = matches[key]?.selectedVersion;
      if (selectedVersion != null) {
        _synchronizePackageVersion(
          candidate.skill.packagePath,
          selectedVersion,
          exceptKey: key,
        );
      }
      if (candidate.skill.versions.isNotEmpty &&
          !optedOutSkillKeys.contains(key)) {
        selectedSkillKeys.add(key);
      }
    });
  }

  void _selectVersion(InstalledSkill skill, String version) {
    final key = _librarySelectionKey(skill);
    final current = matches[key];
    if (current == null) return;
    final packagePath = current.selected?.skill.packagePath;
    setState(() {
      matches[key] = current.selectVersion(version);
      if (packagePath != null) {
        _synchronizePackageVersion(packagePath, version, exceptKey: key);
      }
    });
  }

  void _synchronizePackageVersion(
    String packagePath,
    String version, {
    required String exceptKey,
  }) {
    for (final entry in matches.entries) {
      if (entry.key == exceptKey) continue;
      final match = entry.value;
      final candidate = match.selected?.skill;
      if (candidate?.packagePath != packagePath ||
          candidate == null ||
          !candidate.versions.contains(version)) {
        continue;
      }
      matches[entry.key] = match.selectVersion(version);
    }
  }

  void _confirmSelection() {
    final selections = <_AdoptionReviewSelection>[];
    for (final skill in widget.skills) {
      if (!selectedSkillKeys.contains(_librarySelectionKey(skill))) continue;
      final match = matches[_librarySelectionKey(skill)];
      final candidate = match?.selected?.skill;
      final version = match?.selectedVersion;
      if (candidate == null || version == null) continue;
      selections.add((
        installed: skill,
        candidate: candidate,
        version: version,
      ));
    }
    if (selections.isNotEmpty && !confirmationDialogOpen) {
      unawaited(_requestConfirmation(List.unmodifiable(selections)));
    }
  }

  Future<void> _requestConfirmation(
    List<_AdoptionReviewSelection> selections,
  ) async {
    if (!mounted || confirmationDialogOpen) return;
    confirmationDialogOpen = true;
    try {
      final confirmed = await showSkillsDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const Key('library-adoption-confirmation-dialog'),
          backgroundColor: dialogContext.skillsComponents.overlay,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.l10n.confirmSkillsGoManagementCount(
              selections.length,
              widget.skills.length,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  key: const Key('library-adoption-confirmation-effects'),
                  decoration: BoxDecoration(
                    color:
                        dialogContext.skillsComponents.statusAttentionContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dialogContext.skillsComponents.statusAttention,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          size: 20,
                          strokeWidth: 1.8,
                          color: dialogContext.skillsComponents.statusAttention,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _AdoptionEffectList(
                            key: const Key(
                              'library-adoption-confirmation-message',
                            ),
                            description: context.l10n.batchAdoptionDescription,
                            color:
                                dialogContext.skillsComponents.statusAttention,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('library-adoption-confirmation-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('library-adoption-confirmation-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.batchAdoptionConfirm),
            ),
          ],
        ),
      );
      if (mounted && confirmed == true) {
        widget.onConfirm(selections);
      }
    } finally {
      confirmationDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedSkillKeys.length;
    final scheme = Theme.of(context).colorScheme;
    final actionBar = Semantics(
      key: const Key('library-adoption-review'),
      container: true,
      label: context.l10n.batchAdoptionTitle,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(11, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Center(
                    child: HugeIcon(
                      key: const Key('library-external-skills-icon'),
                      icon: HugeIcons.strokeRoundedFolderOpen,
                      size: 26,
                      strokeWidth: 1.8,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showCount = constraints.maxWidth >= 40;
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.l10n.libraryLocalSkills,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.skillsTypography.display.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                height: 1.05,
                              ),
                            ),
                          ),
                          if (showCount) ...[
                            const SizedBox(width: 8),
                            StatusChip(
                              key: const Key('library-external-skills-count'),
                              label: '${widget.skills.length}',
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _PortalMorphingAdoptionButton(
                      height: 42,
                      expanded: widget.expanded,
                      collapsedLabel: context.l10n.batchAdoptionAction,
                      cancelLabel: context.l10n.cancel,
                      confirmLabel: context.l10n.confirmSkillsGoManagementCount(
                        selectedCount,
                        widget.skills.length,
                      ),
                      confirmEnabled: selectedCount > 0,
                      onExpand: widget.onEnter,
                      onCollapseComplete: widget.onExit,
                      onConfirm: _confirmSelection,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 52),
              child: Text(
                context.l10n.libraryFilterOtherTooltip,
                key: const Key('library-adoption-review-description'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.skillsTypography.metadata.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final rows = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: widget.expanded
          ? Column(
              key: const ValueKey('adoption-configured-rows'),
              children: [
                const _AdoptionReviewColumnHeader(),
                for (var index = 0; index < widget.skills.length; index++) ...[
                  if (index > 0) const SkillsSeparator.horizontal(),
                  _AdoptionReviewRow(
                    skill: widget.skills[index],
                    match: matches[_librarySelectionKey(widget.skills[index])],
                    selected: selectedSkillKeys.contains(
                      _librarySelectionKey(widget.skills[index]),
                    ),
                    onSelectionChanged: (selected) {
                      setState(() {
                        final key = _librarySelectionKey(widget.skills[index]);
                        if (selected) {
                          optedOutSkillKeys.remove(key);
                          selectedSkillKeys.add(key);
                        } else {
                          optedOutSkillKeys.add(key);
                          selectedSkillKeys.remove(key);
                        }
                      });
                    },
                    onCandidateSelected: (candidate) =>
                        _selectCandidate(widget.skills[index], candidate),
                    onVersionSelected: (version) =>
                        _selectVersion(widget.skills[index], version),
                    onRetry: () => _retryMatch(widget.skills[index]),
                  ),
                ],
              ],
            )
          : Column(
              key: const ValueKey('adoption-installed-rows'),
              children: [
                for (var index = 0; index < widget.skills.length; index++) ...[
                  if (index > 0) const SkillsSeparator.horizontal(),
                  _InstalledSkillRow(
                    skill: widget.skills[index],
                    projects: widget.projects,
                    selected: widget.selectedSkillKeys.contains(
                      _librarySelectionKey(widget.skills[index]),
                    ),
                    agentLabel: widget.agentLabel,
                    onOpen: () => widget.onOpen(widget.skills[index]),
                    onSelectionChanged: (selected) => widget.onSelectionChanged(
                      widget.skills[index],
                      selected,
                    ),
                  ),
                ],
              ],
            ),
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: widget.expanded,
          delegate: _AdoptionActionHeaderDelegate(
            backgroundColor: scheme.surface,
            tintColor: scheme.surfaceContainerHighest,
            child: actionBar,
          ),
        ),
        SliverToBoxAdapter(
          child: Semantics(
            container: true,
            label: context.l10n.batchAdoptionTitle,
            child: rows,
          ),
        ),
      ],
    );
  }
}

class _AdoptionEffectList extends StatelessWidget {
  const _AdoptionEffectList({
    super.key,
    required this.description,
    required this.color,
  });

  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final items = description
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final style = context.skillsTypography.bodySecondary.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•', style: style),
              const SizedBox(width: 7),
              Expanded(child: Text(items[index], style: style)),
            ],
          ),
        ],
      ],
    );
  }
}

class _AdoptionActionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _AdoptionActionHeaderDelegate({
    required this.backgroundColor,
    required this.tintColor,
    required this.child,
  });

  static const pinnedExtent = 72.0;
  static const restingExtent = 74.0;

  final Color backgroundColor;
  final Color tintColor;
  final Widget child;

  @override
  double get minExtent => pinnedExtent;

  @override
  double get maxExtent => restingExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pinned = shrinkOffset >= restingExtent - pinnedExtent;
    return ClipRect(
      key: const Key('library-adoption-sticky-clip'),
      child: BackdropFilter(
        enabled: pinned,
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          key: const Key('library-adoption-sticky-action'),
          decoration: BoxDecoration(
            gradient: pinned
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      backgroundColor.withValues(alpha: .56),
                      tintColor.withValues(alpha: .38),
                    ],
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AdoptionActionHeaderDelegate oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.tintColor != tintColor ||
      oldDelegate.child != child;
}

class _AdoptionReviewColumnHeader extends StatelessWidget {
  const _AdoptionReviewColumnHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = context.skillsTypography.metadata.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return DecoratedBox(
      key: const Key('library-adoption-column-header'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: .72),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
      ),
      child: _AdoptionReviewGridRow(
        leading: const SizedBox.shrink(),
        skill: Text(context.l10n.skillColumnLabel, style: style),
        source: Text(context.l10n.packageSourceColumnLabel, style: style),
        version: Text(context.l10n.versionColumnLabel, style: style),
      ),
    );
  }
}

class _AdoptionReviewGridRow extends StatelessWidget {
  const _AdoptionReviewGridRow({
    required this.leading,
    required this.skill,
    required this.source,
    required this.version,
  });

  final Widget leading;
  final Widget skill;
  final Widget source;
  final Widget version;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 10, 8),
    child: Row(
      children: [
        SizedBox(width: 44, child: leading),
        const SizedBox(width: 8),
        Expanded(child: skill),
        const SizedBox(width: 16),
        SizedBox(width: 280, child: source),
        const SizedBox(width: 12),
        SizedBox(width: 148, child: version),
      ],
    ),
  );
}

class _AdoptionReviewRow extends StatelessWidget {
  const _AdoptionReviewRow({
    required this.skill,
    required this.match,
    required this.selected,
    required this.onSelectionChanged,
    required this.onCandidateSelected,
    required this.onVersionSelected,
    required this.onRetry,
  });

  final InstalledSkill skill;
  final _AdoptionMatch? match;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<_AdoptionCandidate> onCandidateSelected;
  final ValueChanged<String> onVersionSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCandidate = match?.selected;
    final ready = selectedCandidate != null && match?.selectedVersion != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: BorderDirectional(
          start: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: _AdoptionReviewGridRow(
        leading: SkillsCheckbox(
          key: ValueKey('library-adoption-select-${skill.inventoryKey}'),
          value: selected,
          enabled: ready,
          onChanged: onSelectionChanged,
        ),
        skill: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.name,
              textDirection: contentTextDirection(skill.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              skill.description.trim().isEmpty
                  ? context.l10n.noDescriptionAvailable
                  : skill.description.trim(),
              textDirection: contentTextDirection(skill.description),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
        source: _AdoptionSourceSelector(
          key: ValueKey('library-adoption-source-${skill.inventoryKey}'),
          match: match,
          onSelected: onCandidateSelected,
          onRetry: onRetry,
        ),
        version: _AdoptionVersionSelector(
          key: ValueKey('library-adoption-version-${skill.inventoryKey}'),
          match: match,
          onSelected: onVersionSelected,
        ),
      ),
    );
  }
}

class _AdoptionVersionSelector extends StatelessWidget {
  const _AdoptionVersionSelector({
    super.key,
    required this.match,
    required this.onSelected,
  });

  final _AdoptionMatch? match;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final versions = match?.selected?.skill.versions ?? const <String>[];
    final selectedVersion = match?.selectedVersion;
    if (versions.isEmpty || selectedVersion == null) {
      return Text(
        context.l10n.versionPendingSelection,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      );
    }
    return _AdoptionSingleSelect<String>(
      key: const ValueKey('adoption-version-dropdown'),
      selected: selectedVersion,
      values: versions,
      label: (version) => version,
      onSelected: onSelected,
      trigger: Text(
        selectedVersion,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AdoptionSingleSelect<T extends Object> extends StatefulWidget {
  const _AdoptionSingleSelect({
    super.key,
    required this.selected,
    required this.values,
    required this.label,
    required this.onSelected,
    required this.trigger,
    this.optionBuilder,
    this.separateOptions = false,
  });

  final T selected;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final Widget trigger;
  final Widget Function(T value)? optionBuilder;
  final bool separateOptions;

  @override
  State<_AdoptionSingleSelect<T>> createState() =>
      _AdoptionSingleSelectState<T>();
}

class _AdoptionSingleSelectState<T extends Object>
    extends State<_AdoptionSingleSelect<T>> {
  final controller = MultiSelectController<T>();
  bool syncing = false;
  bool controllerOpen = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    final nextOpen = controller.isOpen;
    if (nextOpen == controllerOpen) return;
    controllerOpen = nextOpen;
    if (mounted) setState(() {});
  }

  List<DropdownItem<T>> get items => [
    for (final value in widget.values)
      DropdownItem(
        label: widget.label(value),
        value: value,
        selected: value == widget.selected,
      ),
  ];

  @override
  void didUpdateWidget(covariant _AdoptionSingleSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        !listEquals(oldWidget.values, widget.values)) {
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
    controller.removeListener(_handleControllerChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    return Stack(
      children: [
        Positioned.fill(
          child: MultiDropdown<T>(
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
              maxHeight: 360,
              marginTop: 6,
              borderRadius: BorderRadius.circular(14),
              listPadding: const EdgeInsets.symmetric(vertical: 6),
              animationDuration: const Duration(milliseconds: 180),
              animationCurve: Curves.easeOutCubic,
            ),
            itemBuilder: (item, index, onTap) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.separateOptions && index > 0)
                  Divider(
                    key: ValueKey('adoption-dropdown-separator-$index'),
                    height: 1,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                    color: scheme.outlineVariant.withValues(alpha: .55),
                  ),
                InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child:
                              widget.optionBuilder?.call(item.value) ??
                              Text(item.label),
                        ),
                        if (item.selected) ...[
                          const SizedBox(width: 12),
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedTick02,
                            size: 17,
                            strokeWidth: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            selectedItemBuilder: (_) => const SizedBox.shrink(),
            chipDecoration: const ChipDecoration(
              padding: EdgeInsets.zero,
              spacing: 0,
              runSpacing: 0,
            ),
            onSelectionChange: (values) {
              if (syncing) return;
              final value = values.firstOrNull;
              if (value != null && value != widget.selected) {
                widget.onSelected(value);
              }
            },
          ),
        ),
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: 7,
              end: 8,
              bottom: 7,
            ),
            child: Row(
              children: [
                Flexible(child: widget.trigger),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: controllerOpen ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOutCubic,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 14,
                    strokeWidth: 1.7,
                    color: scheme.onSurfaceVariant.withValues(alpha: .7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdoptionSourceSelector extends StatelessWidget {
  const _AdoptionSourceSelector({
    super.key,
    required this.match,
    required this.onSelected,
    required this.onRetry,
  });

  final _AdoptionMatch? match;
  final ValueChanged<_AdoptionCandidate> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (match == null || match!.loading) {
      return Text(
        context.l10n.packageMatching,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      );
    }
    if (match!.error != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            '${context.l10n.sourceMatchUnavailable} · ${context.l10n.retry}',
            style: TextStyle(color: scheme.error, fontSize: 12),
          ),
        ),
      );
    }
    if (match!.candidates.isEmpty) {
      return Text(
        context.l10n.noSourceMatches,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      );
    }
    final selected = match!.selected!;
    return _AdoptionSingleSelect<_AdoptionCandidate>(
      key: const ValueKey('adoption-package-dropdown'),
      selected: selected,
      values: match!.candidates,
      separateOptions: true,
      label: (candidate) => _compactPackagePath(candidate.skill.packagePath),
      onSelected: onSelected,
      trigger: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PackageAvatar(
            key: ValueKey(
              'library-adoption-selected-package-avatar-${selected.skill.packagePath}',
            ),
            source: selected.skill.packagePath,
            imageUrl: selected.skill.imageUrl,
            size: 22,
            borderRadius: 6,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              _compactPackagePath(selected.skill.packagePath),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 7),
          _AdoptionMatchChip(
            key: ValueKey(
              'library-adoption-selected-source-match-${selected.skill.packagePath}',
            ),
            label: context.l10n.sourceMatchPercent(
              (selected.matchScore * 100).round(),
            ),
          ),
        ],
      ),
      optionBuilder: (candidate) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PackageAvatar(
                key: ValueKey(
                  'library-adoption-source-avatar-${candidate.skill.packagePath}',
                ),
                source: candidate.skill.packagePath,
                imageUrl: candidate.skill.imageUrl,
                size: 30,
                borderRadius: 8,
              ),
              const SizedBox(height: 5),
              _AdoptionMatchChip(
                key: ValueKey(
                  'library-adoption-source-match-${candidate.skill.packagePath}',
                ),
                label: context.l10n.sourceMatchPercent(
                  (candidate.matchScore * 100).round(),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _compactPackagePath(candidate.skill.packagePath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (candidate.skill.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    key: ValueKey(
                      'library-adoption-source-description-${candidate.skill.packagePath}',
                    ),
                    candidate.skill.description.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionMatchChip extends StatelessWidget {
  const _AdoptionMatchChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 10,
          height: 1.15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AdoptionCandidate {
  const _AdoptionCandidate({required this.skill, required this.matchScore});

  final AdoptionCandidate skill;
  final double matchScore;
}

class _AdoptionMatch {
  const _AdoptionMatch._({
    this.loading = false,
    this.candidates = const [],
    this.selected,
    this.selectedVersion,
    this.error,
  });

  const _AdoptionMatch.loading() : this._(loading: true);
  _AdoptionMatch.content({
    required List<_AdoptionCandidate> candidates,
    required _AdoptionCandidate? selected,
  }) : this._(
         candidates: candidates,
         selected: selected,
         selectedVersion: selected?.skill.versions.firstOrNull,
       );
  const _AdoptionMatch.error(Object error) : this._(error: error);

  final bool loading;
  final List<_AdoptionCandidate> candidates;
  final _AdoptionCandidate? selected;
  final String? selectedVersion;
  final Object? error;

  _AdoptionMatch select(_AdoptionCandidate candidate) =>
      _AdoptionMatch.content(candidates: candidates, selected: candidate);

  _AdoptionMatch selectVersion(String version) {
    final candidate = selected;
    if (candidate == null || !candidate.skill.versions.contains(version)) {
      return this;
    }
    return _AdoptionMatch._(
      candidates: candidates,
      selected: candidate,
      selectedVersion: version,
    );
  }
}
