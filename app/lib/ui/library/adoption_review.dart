/*
 * [INPUT]: Depends on visible External Library entries, CLI-mediated batch Find, localized management copy, the SkillsGo logo asset, native buttons, the vendored Portal Labs split interaction, and semantic theme roles.
 * [OUTPUT]: Provides the feature-gated inline Adoption Review with one exact-name bounded batch match, App-ranked Source candidates, latest eligible version selection, and persistent morphing actions.
 * [POS]: Serves as the user-reviewed matching presentation inside the Library journey while leaving Hub transport and filesystem mutation to the Gateway and CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

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

  @override
  State<_AdoptionReviewShell> createState() => _AdoptionReviewShellState();
}

class _AdoptionReviewShellState extends State<_AdoptionReviewShell> {
  final selectedSkillKeys = <String>{};
  final optedOutSkillKeys = <String>{};
  final matches = <String, _AdoptionMatch>{};
  int matchGeneration = 0;

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
    if (!oldWidget.expanded && widget.expanded) {
      _startMatching();
    } else if (oldWidget.expanded && !widget.expanded) {
      matchGeneration++;
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
    final queryIDs = <String, String>{};
    final queries = <SourceFindQuery>[];
    for (final skill in widget.skills) {
      final signature =
          '${skill.name.trim().toLowerCase()}\u0000${skill.repositoryId}';
      queryIDs.putIfAbsent(signature, () {
        final id = 'find:${queryIDs.length}';
        queries.add(
          SourceFindQuery(id: id, name: skill.name, source: skill.repositoryId),
        );
        return id;
      });
    }
    try {
      final results = await widget.gateway.findSources(queries, limit: 10);
      if (!mounted || generation != matchGeneration) return;
      final byID = {for (final result in results) result.id: result.skills};
      setState(() {
        for (final skill in widget.skills) {
          final signature =
              '${skill.name.trim().toLowerCase()}\u0000${skill.repositoryId}';
          _applyCandidates(skill, byID[queryIDs[signature]] ?? const []);
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

  void _applyCandidates(InstalledSkill skill, List<SkillSummary> skills) {
    final key = _librarySelectionKey(skill);
    final candidates =
        skills
            .where(
              (candidate) =>
                  candidate.name.toLowerCase() == skill.name.toLowerCase(),
            )
            .map(
              (candidate) => _AdoptionCandidate(
                skill: candidate,
                similarity: _descriptionSimilarity(
                  skill.description,
                  candidate.description,
                ),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.similarity.compareTo(a.similarity));
    final selected = candidates.firstOrNull;
    matches[key] = _AdoptionMatch.content(
      candidates: candidates,
      selected: selected,
    );
    if (selected != null &&
        selected.skill.latestVersion.isNotEmpty &&
        !optedOutSkillKeys.contains(key)) {
      selectedSkillKeys.add(key);
    }
  }

  Future<void> _retryMatch(InstalledSkill skill) async {
    final key = _librarySelectionKey(skill);
    setState(() => matches[key] = const _AdoptionMatch.loading());
    try {
      final results = await widget.gateway.findSources([
        SourceFindQuery(id: key, name: skill.name, source: skill.repositoryId),
      ]);
      if (!mounted) return;
      setState(
        () => _applyCandidates(skill, results.firstOrNull?.skills ?? []),
      );
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
      if (candidate.skill.latestVersion.isNotEmpty &&
          !optedOutSkillKeys.contains(key)) {
        selectedSkillKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedSkillKeys.length;
    final buttonForeground = context.skillsComponents.primaryForeground;
    final scheme = Theme.of(context).colorScheme;
    final contrastCandidate =
        (scheme.surface.computeLuminance() -
                    buttonForeground.computeLuminance())
                .abs() >
            (scheme.inverseSurface.computeLuminance() -
                    buttonForeground.computeLuminance())
                .abs()
        ? scheme.surface
        : scheme.inverseSurface;
    final shimmerHighlight =
        Color.lerp(buttonForeground, contrastCandidate, .32) ??
        buttonForeground;
    return Semantics(
      key: const Key('library-adoption-review'),
      container: true,
      label: context.l10n.batchTakeoverTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 11, bottom: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.asset(
                        'assets/branding/skillsgo-logo.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PortalMorphingAdoptionButton(
                  height: 48,
                  expanded: widget.expanded,
                  collapsedLabel: context.l10n
                      .handExternalSkillsToSkillsGoManagementCount(
                        widget.skills.length,
                      ),
                  collapsedLabelWidget: ShimmerText(
                    text: context.l10n
                        .handExternalSkillsToSkillsGoManagementCount(
                          widget.skills.length,
                        ),
                    style: context.skillsTypography.label.copyWith(
                      color: buttonForeground,
                      fontWeight: FontWeight.w600,
                    ),
                    baseColor: buttonForeground,
                    highlightColor: shimmerHighlight,
                    duration: const Duration(milliseconds: 2600),
                    repeat: !widget.expanded,
                  ),
                  collapsedTrailing: const _IdleMagicSelectionIcon(),
                  cancelLabel: context.l10n.cancel,
                  confirmLabel: context.l10n.confirmSkillsGoManagementCount(
                    selectedCount,
                  ),
                  confirmEnabled: selectedCount > 0,
                  onExpand: widget.onEnter,
                  onCollapseComplete: widget.onExit,
                  onConfirm: () {},
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: widget.expanded
                ? Column(
                    key: const ValueKey('adoption-configured-rows'),
                    children: [
                      const _AdoptionReviewColumnHeader(),
                      for (
                        var index = 0;
                        index < widget.skills.length;
                        index++
                      ) ...[
                        if (index > 0) const SkillsSeparator.horizontal(),
                        _AdoptionReviewRow(
                          skill: widget.skills[index],
                          match:
                              matches[_librarySelectionKey(
                                widget.skills[index],
                              )],
                          selected: selectedSkillKeys.contains(
                            _librarySelectionKey(widget.skills[index]),
                          ),
                          onSelectionChanged: (selected) {
                            setState(() {
                              final key = _librarySelectionKey(
                                widget.skills[index],
                              );
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
                          onRetry: () => _retryMatch(widget.skills[index]),
                        ),
                      ],
                    ],
                  )
                : Column(
                    key: const ValueKey('adoption-installed-rows'),
                    children: [
                      for (
                        var index = 0;
                        index < widget.skills.length;
                        index++
                      ) ...[
                        if (index > 0) const SkillsSeparator.horizontal(),
                        _InstalledSkillRow(
                          skill: widget.skills[index],
                          projects: widget.projects,
                          selected: widget.selectedSkillKeys.contains(
                            _librarySelectionKey(widget.skills[index]),
                          ),
                          agentLabel: widget.agentLabel,
                          onOpen: () => widget.onOpen(widget.skills[index]),
                          onSelectionChanged: (selected) =>
                              widget.onSelectionChanged(
                                widget.skills[index],
                                selected,
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

class _AdoptionReviewColumnHeader extends StatelessWidget {
  const _AdoptionReviewColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 10, 6),
      child: Row(
        children: [
          const SizedBox(width: 44),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.skillColumnLabel, style: style)),
          const SizedBox(width: 16),
          SizedBox(
            width: 280,
            child: Text(context.l10n.repositorySourceColumnLabel, style: style),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 148,
            child: Text(context.l10n.versionColumnLabel, style: style),
          ),
        ],
      ),
    );
  }
}

class _AdoptionReviewRow extends StatelessWidget {
  const _AdoptionReviewRow({
    required this.skill,
    required this.match,
    required this.selected,
    required this.onSelectionChanged,
    required this.onCandidateSelected,
    required this.onRetry,
  });

  final InstalledSkill skill;
  final _AdoptionMatch? match;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<_AdoptionCandidate> onCandidateSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCandidate = match?.selected;
    final ready =
        selectedCandidate != null &&
        selectedCandidate.skill.latestVersion.isNotEmpty;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: BorderDirectional(
          start: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 10, 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: SkillsCheckbox(
                key: ValueKey('library-adoption-select-${skill.inventoryKey}'),
                value: selected,
                enabled: ready,
                onChanged: onSelectionChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    textDirection: contentTextDirection(skill.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 280,
              child: _AdoptionSourceSelector(
                match: match,
                onSelected: onCandidateSelected,
                onRetry: onRetry,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 148,
              child: Text(
                selectedCandidate?.skill.latestVersion ??
                    context.l10n.versionPendingSelection,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ready ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptionSourceSelector extends StatelessWidget {
  const _AdoptionSourceSelector({
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
        context.l10n.repositoryMatching,
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
    return MenuAnchor(
      menuChildren: [
        for (final candidate in match!.candidates)
          MenuItemButton(
            onPressed: () => onSelected(candidate),
            child: SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _compactRepositorySource(
                            candidate.skill.repositoryId,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        context.l10n.sourceMatchPercent(
                          (candidate.similarity * 100).round(),
                        ),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (candidate.skill.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      candidate.skill.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: controller.isOpen ? controller.close : controller.open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _compactRepositorySource(match!.selected!.skill.repositoryId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                size: 15,
                strokeWidth: 1.8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdoptionCandidate {
  const _AdoptionCandidate({required this.skill, required this.similarity});

  final SkillSummary skill;
  final double similarity;
}

class _AdoptionMatch {
  const _AdoptionMatch._({
    this.loading = false,
    this.candidates = const [],
    this.selected,
    this.error,
  });

  const _AdoptionMatch.loading() : this._(loading: true);
  const _AdoptionMatch.content({
    required List<_AdoptionCandidate> candidates,
    required _AdoptionCandidate? selected,
  }) : this._(candidates: candidates, selected: selected);
  const _AdoptionMatch.error(Object error) : this._(error: error);

  final bool loading;
  final List<_AdoptionCandidate> candidates;
  final _AdoptionCandidate? selected;
  final Object? error;

  _AdoptionMatch select(_AdoptionCandidate candidate) =>
      _AdoptionMatch.content(candidates: candidates, selected: candidate);
}

double _descriptionSimilarity(String local, String remote) {
  final left = _descriptionTerms(local);
  final right = _descriptionTerms(remote);
  if (left.isEmpty || right.isEmpty) return 0;
  final intersection = left.intersection(right).length;
  return (2 * intersection) / (left.length + right.length);
}

Set<String> _descriptionTerms(String value) => value
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((term) => term.length > 1)
    .toSet();
