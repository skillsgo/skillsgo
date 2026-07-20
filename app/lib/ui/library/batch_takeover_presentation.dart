/*
 * [INPUT]: Depends on the Library screen library, vendored Archive Folder and collision physics, current-theme design tokens, repository avatars, localized takeover copy, and caller-provided preflight Skill identities and exact eligible count.
 * [OUTPUT]: Provides the responsive, accessible Batch Takeover dialog and Before/After story with truthful post-transaction card flight, orderly managed layout, retry, and reduced-motion behavior.
 * [POS]: Serves as the visual product-story and operation-feedback segment of the Library Batch Takeover journey while delegated callbacks retain mutation ownership.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

const _takeoverIllustrationFallbackNames = <String>[
  'my-review',
  'commit-helper',
  'docs-writer',
  'release-check',
  'test-runner',
  'api-guide',
  'release-notes',
  'project-audit',
];

typedef _TakeoverIllustratedSkill = ({String name, String skillId});

const _takeoverPaperColor = Color(0xfffffdf8);
const _takeoverPaperTextColor = Color(0xff28251f);
const _takeoverPaperMutedColor = Color(0xff746e63);
const _takeoverAvatarBackgroundColor = Color(0xffeee9df);

enum _BatchTakeoverDialogOutcome { skipped, completed }

class _BatchTakeoverDialog extends StatefulWidget {
  const _BatchTakeoverDialog({
    required this.eligibleCount,
    required this.skillPreviews,
    required this.onConfirm,
  });

  final int eligibleCount;
  final List<BatchTakeoverPreview> skillPreviews;
  final Future<BatchTakeoverResult> Function() onConfirm;

  @override
  State<_BatchTakeoverDialog> createState() => _BatchTakeoverDialogState();
}

class _BatchTakeoverDialogState extends State<_BatchTakeoverDialog> {
  final Set<String> _managedSkillKeys = {};
  bool _executing = false;
  bool _operationStarted = false;
  bool _leftFolderOpen = false;
  bool _rightFolderOpen = false;
  bool _completed = false;
  Object? _error;
  BatchTakeoverResult? _result;
  String? _flyingSkillKey;

  Future<void> _confirm() async {
    if (_executing) return;
    setState(() {
      _executing = true;
      _operationStarted = true;
      _leftFolderOpen = true;
      _rightFolderOpen = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (!mounted) return;
      final successful = result.items
          .where((item) => item.status == BatchTakeoverItemStatus.takenOver)
          .map((item) => _takeoverSkillKey(item.name, item.skillId))
          .toList(growable: false);
      setState(() => _result = result);
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      for (final key in successful) {
        if (!mounted) return;
        if (reduceMotion) {
          setState(() => _managedSkillKeys.add(key));
          continue;
        }
        setState(() => _flyingSkillKey = key);
        await Future<void>.delayed(const Duration(milliseconds: 520));
        if (!mounted) return;
        setState(() {
          _managedSkillKeys.add(key);
          _flyingSkillKey = null;
        });
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (!mounted) return;
      setState(() {
        _executing = false;
        _completed = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _executing = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final error = _error;
    final failure = error == null ? null : failureCopy(context, error);
    return RepaintBoundary(
      key: const Key('batch-takeover-dialog'),
      child: SkillsDialog(
        constraints: const BoxConstraints(maxWidth: 980),
        title: Text(context.l10n.batchTakeoverStoryTitle),
        description: Text(
          _completed && result != null
              ? context.l10n.batchTakeoverSummary(
                  result.takenOver,
                  result.skipped,
                )
              : failure?.message ??
                    context.l10n.batchTakeoverStoryDescription(
                      widget.eligibleCount,
                    ),
        ),
        actions: _completed
            ? [
                SkillsButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _BatchTakeoverDialogOutcome.completed,
                  ),
                  child: Text(context.l10n.batchTakeoverClose),
                ),
              ]
            : [
                SkillsButton.outline(
                  enabled: !_executing,
                  onPressed: _executing
                      ? null
                      : () => Navigator.pop(
                          context,
                          _BatchTakeoverDialogOutcome.skipped,
                        ),
                  child: Text(context.l10n.batchTakeoverSkip),
                ),
                SkillsButton(
                  key: const Key('batch-takeover-confirm'),
                  enabled: !_executing,
                  onPressed: _executing ? null : _confirm,
                  child: Text(
                    _executing
                        ? context.l10n.batchTakeoverPending
                        : error == null
                        ? context.l10n.batchTakeoverConfirm
                        : context.l10n.batchTakeoverExecutionRetry,
                  ),
                ),
              ],
        child: _BatchTakeoverStory(
          eligibleCount: widget.eligibleCount,
          skillPreviews: widget.skillPreviews,
          managedSkillKeys: _managedSkillKeys,
          flyingSkillKey: _flyingSkillKey,
          operationStarted: _operationStarted,
          leftFolderOpen: _leftFolderOpen,
          rightFolderOpen: _rightFolderOpen,
          onLeftFolderToggle: (open) => setState(() => _leftFolderOpen = open),
          onRightFolderToggle: (open) =>
              setState(() => _rightFolderOpen = open),
        ),
      ),
    );
  }
}

class _BatchTakeoverStory extends StatelessWidget {
  const _BatchTakeoverStory({
    required this.eligibleCount,
    required this.skillPreviews,
    this.managedSkillKeys = const {},
    this.flyingSkillKey,
    this.operationStarted = false,
    required this.leftFolderOpen,
    required this.rightFolderOpen,
    required this.onLeftFolderToggle,
    required this.onRightFolderToggle,
  });

  final int eligibleCount;
  final List<BatchTakeoverPreview> skillPreviews;
  final Set<String> managedSkillKeys;
  final String? flyingSkillKey;
  final bool operationStarted;
  final bool leftFolderOpen;
  final bool rightFolderOpen;
  final ValueChanged<bool> onLeftFolderToggle;
  final ValueChanged<bool> onRightFolderToggle;

  List<_TakeoverIllustratedSkill> get _orderedSkills {
    final candidates = <_TakeoverIllustratedSkill>[];
    final seenSkills = <String>{};
    for (final preview in skillPreviews) {
      final name = preview.name.trim();
      if (name.isEmpty) continue;
      final identity = '${preview.skillId}\u0000$name';
      if (!seenSkills.add(identity)) continue;
      candidates.add((name: name, skillId: preview.skillId));
    }
    final selected = <_TakeoverIllustratedSkill>[];
    final deferred = <_TakeoverIllustratedSkill>[];
    final seenRepositories = <String>{};
    for (final candidate in candidates) {
      final repository = _takeoverRepositoryIdentity(candidate);
      if (seenRepositories.add(repository)) {
        selected.add(candidate);
      } else {
        deferred.add(candidate);
      }
    }
    selected.addAll(deferred);
    return selected;
  }

  List<_TakeoverIllustratedSkill> get _illustratedSkills {
    final illustratedCount = math.min(eligibleCount, 8);
    final selected = _orderedSkills.take(illustratedCount).toList();
    for (final fallback in _takeoverIllustrationFallbackNames) {
      if (selected.length >= illustratedCount) break;
      selected.add((name: fallback, skillId: ''));
    }
    return selected.take(illustratedCount).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final skills = _illustratedSkills;
    final pinnableSkills = _orderedSkills.isEmpty ? skills : _orderedSkills;
    final remainingCount = math.max(0, eligibleCount - 8);
    final archivedSkills = _orderedSkills
        .skip(8)
        .take(math.min(remainingCount, 6))
        .toList();
    final hiddenArchivedCount = math.max(
      0,
      remainingCount - archivedSkills.length,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 720;
              final flyingSkill = flyingSkillKey == null
                  ? null
                  : pinnableSkills
                        .cast<_TakeoverIllustratedSkill?>()
                        .firstWhere(
                          (skill) =>
                              skill != null &&
                              _takeoverSkillKey(skill.name, skill.skillId) ==
                                  flyingSkillKey,
                          orElse: () => null,
                        );
              if (constraints.maxWidth >= 720) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 440,
                            child: _TakeoverBeforePanel(
                              skills: skills,
                              archivedSkills: archivedSkills,
                              hiddenArchivedCount: hiddenArchivedCount,
                              managedSkillKeys: managedSkillKeys,
                              motionEnabled: !operationStarted,
                              isOpen: leftFolderOpen,
                              toggleEnabled: !operationStarted,
                              onToggle: onLeftFolderToggle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 70,
                          child: _TakeoverTransition(vertical: false),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 440,
                            child: _TakeoverAfterPanel(
                              skills: pinnableSkills,
                              eligibleCount: eligibleCount,
                              managedSkillKeys: managedSkillKeys,
                              operationStarted: operationStarted,
                              isOpen: rightFolderOpen,
                              onToggle: onRightFolderToggle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (flyingSkill != null)
                      Positioned.fill(
                        child: _TakeoverFlyingSkill(
                          key: ValueKey(flyingSkillKey),
                          skill: flyingSkill,
                          vertical: vertical,
                        ),
                      ),
                  ],
                );
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      _TakeoverBeforePanel(
                        skills: skills,
                        archivedSkills: archivedSkills,
                        hiddenArchivedCount: hiddenArchivedCount,
                        managedSkillKeys: managedSkillKeys,
                        motionEnabled: !operationStarted,
                        isOpen: leftFolderOpen,
                        toggleEnabled: !operationStarted,
                        onToggle: onLeftFolderToggle,
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(
                        height: 62,
                        child: _TakeoverTransition(vertical: true),
                      ),
                      const SizedBox(height: 10),
                      _TakeoverAfterPanel(
                        skills: pinnableSkills,
                        eligibleCount: eligibleCount,
                        managedSkillKeys: managedSkillKeys,
                        operationStarted: operationStarted,
                        isOpen: rightFolderOpen,
                        onToggle: onRightFolderToggle,
                      ),
                    ],
                  ),
                  if (flyingSkill != null)
                    Positioned.fill(
                      child: _TakeoverFlyingSkill(
                        key: ValueKey(flyingSkillKey),
                        skill: flyingSkill,
                        vertical: vertical,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const _TakeoverPreservationNote(),
        ],
      ),
    );
  }
}

String _takeoverRepositoryIdentity(_TakeoverIllustratedSkill skill) {
  final skillId = skill.skillId.trim();
  if (skillId.isEmpty) return 'unresolved:${skill.name}';
  final separator = skillId.indexOf('/-/');
  return separator < 0 ? skillId : skillId.substring(0, separator);
}

String _takeoverSkillKey(String name, String skillId) =>
    '${skillId.trim()}\u0000${name.trim()}';

class _TakeoverBeforePanel extends StatelessWidget {
  const _TakeoverBeforePanel({
    required this.skills,
    required this.archivedSkills,
    required this.hiddenArchivedCount,
    required this.managedSkillKeys,
    required this.motionEnabled,
    required this.isOpen,
    required this.toggleEnabled,
    required this.onToggle,
  });

  final List<_TakeoverIllustratedSkill> skills;
  final List<_TakeoverIllustratedSkill> archivedSkills;
  final int hiddenArchivedCount;
  final Set<String> managedSkillKeys;
  final bool motionEnabled;
  final bool isOpen;
  final bool toggleEnabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visibleSkills = skills
        .where(
          (skill) => !managedSkillKeys.contains(
            _takeoverSkillKey(skill.name, skill.skillId),
          ),
        )
        .toList(growable: false);
    final visibleArchivedSkills = archivedSkills
        .where(
          (skill) => !managedSkillKeys.contains(
            _takeoverSkillKey(skill.name, skill.skillId),
          ),
        )
        .toList(growable: false);
    final pains = [
      context.l10n.batchTakeoverPainLocation,
      context.l10n.batchTakeoverPainFreshness,
      context.l10n.batchTakeoverPainRecovery,
      context.l10n.batchTakeoverPainVersionDrift,
    ];
    return Semantics(
      key: const Key('batch-takeover-before'),
      container: true,
      label: context.l10n.batchTakeoverBeforeSemantics,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Transform.translate(
                  key: const Key('batch-takeover-folder-offset'),
                  offset: const Offset(0, -24),
                  child: ArchiveFolder(
                    key: const Key('batch-takeover-archive-folder'),
                    minimumCanvasHeight: 452,
                    title: context.l10n.batchTakeoverFolderTitle,
                    subtitles: [
                      for (final pain in pains)
                        ArchiveFolderSubtitle(
                          label: pain,
                          dotColor: const Color(0xffff5f5f),
                        ),
                    ],
                    style: ArchiveFolderStyle(
                      folderColor: const Color(0xffff8a1f),
                      titleStyle: const ArchiveFolderStyle().titleStyle
                          .copyWith(color: Colors.white),
                      subtitleStyle: const ArchiveFolderStyle().subtitleStyle
                          .copyWith(color: Colors.white),
                      orientation: ArchiveFolderOrientation.horizontal,
                      folderWidth: 281,
                      folderHeight: 375,
                      itemRevealDistance: 26,
                      itemSpacing: 60,
                      itemWidth: 68,
                      itemHeight: 68,
                      enableItemRotation: true,
                      itemBaseRotation: -.15,
                      itemBaseScale: .85,
                      glassBlur: 15,
                      borderRadius: 12,
                      animationCurve: Curves.easeOutQuart,
                      animationDuration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 700),
                      enableHaptics: !reduceMotion,
                    ),
                    items: [
                      for (
                        var index = 0;
                        index < visibleArchivedSkills.length;
                        index++
                      )
                        _TakeoverSkillTile(
                          key: Key('batch-takeover-archive-skill-$index'),
                          skill: visibleArchivedSkills[index],
                        ),
                      if (hiddenArchivedCount > 0)
                        _TakeoverRemainingArchiveItem(
                          key: const Key('batch-takeover-archive-more'),
                          count: hiddenArchivedCount,
                        ),
                    ],
                    isOpen: isOpen,
                    toggleEnabled: toggleEnabled,
                    onToggle: onToggle,
                    frontChild: LayoutBuilder(
                      builder: (context, frontConstraints) {
                        final width = frontConstraints.maxWidth;
                        final height = frontConstraints.maxHeight;
                        final positions = <Offset>[
                          Offset(width * .18, height * .24),
                          Offset(width * .47, height * .3),
                          Offset(width * .78, height * .22),
                          Offset(width * .27, height * .58),
                          Offset(width * .62, height * .62),
                          Offset(width * .84, height * .52),
                          Offset(width * .42, height * .78),
                          Offset(width * .72, height * .8),
                        ];
                        final velocities = <Offset>[
                          const Offset(80, 0),
                          const Offset(-55, 30),
                          const Offset(-90, 10),
                          const Offset(45, -20),
                          const Offset(-40, -15),
                          const Offset(-70, 15),
                          const Offset(35, -25),
                          const Offset(-30, -20),
                        ];
                        return PhysicsCollisionField(
                          key: const Key('batch-takeover-collision-field'),
                          height: height,
                          motionEnabled: motionEnabled,
                          interactionEnabled: motionEnabled,
                          style: const PhysicsCollisionFieldStyle(
                            decoration: BoxDecoration(),
                            itemDecoration: BoxDecoration(),
                            gravity: Offset(0, 720),
                            restitution: .28,
                            damping: .82,
                            showGrid: false,
                            gridColor: Colors.transparent,
                          ),
                          items: [
                            for (
                              var index = 0;
                              index < visibleSkills.length;
                              index++
                            )
                              PhysicsCollisionFieldItem(
                                id: _takeoverSkillKey(
                                  visibleSkills[index].name,
                                  visibleSkills[index].skillId,
                                ),
                                collisionSize: const Size.square(68),
                                initialPosition: positions[index],
                                initialVelocity: velocities[index],
                                decoration: const BoxDecoration(),
                                clipToCircle: false,
                                child: _TakeoverSkillTile(
                                  skill: visibleSkills[index],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TakeoverRemainingArchiveItem extends StatelessWidget {
  const _TakeoverRemainingArchiveItem({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final typography = context.skillsTypography;
    return ArchiveItem(
      width: 68,
      height: 68,
      borderRadius: 4,
      padding: const EdgeInsets.all(5),
      labelHeight: 28,
      labelMaxLines: 2,
      label: context.l10n.batchTakeoverMoreSkills(count),
      color: _takeoverPaperColor,
      labelStyle: typography.caption.copyWith(
        color: _takeoverPaperTextColor,
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedZap,
        size: 20,
        color: _takeoverPaperMutedColor,
        strokeWidth: 1.8,
      ),
    );
  }
}

class _TakeoverAfterPanel extends StatelessWidget {
  const _TakeoverAfterPanel({
    required this.skills,
    required this.eligibleCount,
    required this.managedSkillKeys,
    required this.operationStarted,
    required this.isOpen,
    required this.onToggle,
  });

  final List<_TakeoverIllustratedSkill> skills;
  final int eligibleCount;
  final Set<String> managedSkillKeys;
  final bool operationStarted;
  final bool isOpen;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final managedSkills = skills
        .where(
          (skill) => managedSkillKeys.contains(
            _takeoverSkillKey(skill.name, skill.skillId),
          ),
        )
        .toList(growable: false);
    return Semantics(
      key: const Key('batch-takeover-after'),
      container: true,
      explicitChildNodes: true,
      label: context.l10n.batchTakeoverAfterSemantics(eligibleCount),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: ArchiveFolder(
              key: const Key('batch-takeover-after-folder'),
              minimumCanvasHeight: 452,
              title: context.l10n.batchTakeoverLibraryTitle,
              subtitles: [
                ArchiveFolderSubtitle(
                  label: context.l10n.batchTakeoverBenefitLocation,
                  dotColor: const Color(0xff36e59f),
                ),
                ArchiveFolderSubtitle(
                  label: context.l10n.batchTakeoverBenefitFreshness,
                  dotColor: const Color(0xff36e59f),
                ),
                ArchiveFolderSubtitle(
                  label: context.l10n.batchTakeoverBenefitRecovery,
                  dotColor: const Color(0xff36e59f),
                ),
                ArchiveFolderSubtitle(
                  label: context.l10n.batchTakeoverBenefitVersions,
                  dotColor: const Color(0xff36e59f),
                ),
              ],
              items: const [],
              isOpen: isOpen,
              toggleEnabled: !operationStarted,
              onToggle: onToggle,
              style: ArchiveFolderStyle(
                folderColor: const Color(0xff0082f4),
                titleStyle: const ArchiveFolderStyle().titleStyle.copyWith(
                  color: Colors.white,
                ),
                orientation: ArchiveFolderOrientation.horizontal,
                folderWidth: 281,
                folderHeight: 375,
                itemRevealDistance: 26,
                itemSpacing: 60,
                itemWidth: 68,
                itemHeight: 68,
                glassBlur: 15,
                borderRadius: 12,
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                enableHaptics: false,
              ),
              frontChild: Padding(
                padding: const EdgeInsets.fromLTRB(18, 112, 18, 14),
                child: _TakeoverManagedGrid(
                  key: const Key('batch-takeover-managed-grid'),
                  skills: managedSkills,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TakeoverTransition extends StatelessWidget {
  const _TakeoverTransition({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final typography = context.skillsTypography;
    return Semantics(
      label: context.l10n.batchTakeoverTransitionSemantics,
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: components.primaryRest,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: HugeIcon(
                  icon: vertical
                      ? HugeIcons.strokeRoundedArrowDown01
                      : HugeIcons.strokeRoundedArrowRight01,
                  size: 17,
                  strokeWidth: 2,
                  color: components.primaryForeground,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.batchTakeoverTransitionLabel,
              textAlign: TextAlign.center,
              style: typography.caption.copyWith(
                color: components.primaryRest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeoverSkillTile extends StatelessWidget {
  const _TakeoverSkillTile({super.key, required this.skill});

  final _TakeoverIllustratedSkill skill;

  @override
  Widget build(BuildContext context) {
    final typography = context.skillsTypography;
    final source = skill.skillId;
    final imageUrl = _repositoryAvatarUrl(source);
    return ArchiveItem(
      width: 68,
      height: 68,
      borderRadius: 4,
      padding: const EdgeInsets.all(5),
      labelHeight: 28,
      labelMaxLines: 2,
      color: _takeoverPaperColor,
      label: skill.name,
      labelStyle: typography.caption.copyWith(
        color: _takeoverPaperTextColor,
        fontSize: 8,
        fontWeight: FontWeight.w800,
      ),
      child: source.isEmpty
          ? Icon(
              Icons.description_outlined,
              size: 20,
              color: _takeoverPaperMutedColor,
            )
          : RepositoryAvatar(
              source: source,
              imageUrl: imageUrl,
              size: 22,
              borderRadius: 11,
              backgroundColor: _takeoverAvatarBackgroundColor,
              fallbackForegroundColor: _takeoverPaperTextColor,
            ),
    );
  }
}

class _TakeoverManagedGrid extends StatefulWidget {
  const _TakeoverManagedGrid({super.key, required this.skills});

  final List<_TakeoverIllustratedSkill> skills;

  @override
  State<_TakeoverManagedGrid> createState() => _TakeoverManagedGridState();
}

class _TakeoverManagedGridState extends State<_TakeoverManagedGrid> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(_TakeoverManagedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.skills.length <= oldWidget.skills.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _controller,
      key: const Key('batch-takeover-managed-grid-scroll'),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: widget.skills.length,
      itemBuilder: (context, index) => TweenAnimationBuilder<double>(
        key: ValueKey(
          _takeoverSkillKey(
            widget.skills[index].name,
            widget.skills[index].skillId,
          ),
        ),
        tween: Tween(begin: .86, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Semantics(
          label: context.l10n.batchTakeoverItemManaged(
            widget.skills[index].name,
          ),
          child: _TakeoverSkillTile(skill: widget.skills[index]),
        ),
      ),
    );
  }
}

class _TakeoverFlyingSkill extends StatelessWidget {
  const _TakeoverFlyingSkill({
    super.key,
    required this.skill,
    required this.vertical,
  });

  final _TakeoverIllustratedSkill skill;
  final bool vertical;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, child) {
        final travel = vertical
            ? Offset(0, 390 * progress)
            : Offset(500 * progress, 0);
        final arc = math.sin(progress * math.pi) * -72;
        return Align(
          alignment: vertical
              ? const Alignment(0, -.52)
              : const Alignment(-.66, .2),
          child: Transform.translate(
            offset: travel + (vertical ? Offset(arc, 0) : Offset(0, arc)),
            child: Transform.rotate(
              angle: -.12 * (1 - progress),
              child: Transform.scale(
                scale: 1 - (.08 * math.sin(progress * math.pi)),
                child: child,
              ),
            ),
          ),
        );
      },
      child: _TakeoverSkillTile(skill: skill),
    ),
  );
}

class _TakeoverPreservationNote extends StatelessWidget {
  const _TakeoverPreservationNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.skillsColors;
    final components = context.skillsComponents;
    return Semantics(
      key: const Key('batch-takeover-preservation-note'),
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: components.statusAccentContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: components.statusAccent.withValues(alpha: .22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedShield01,
                size: 18,
                strokeWidth: 1.8,
                color: components.statusAccent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.batchTakeoverPreservation,
                      style: context.skillsTypography.metadata.copyWith(
                        color: colors.foregroundDefault,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.batchTakeoverLaterHint,
                      style: context.skillsTypography.caption.copyWith(
                        color: colors.foregroundMuted,
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
