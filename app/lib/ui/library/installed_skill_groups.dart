/*
 * [INPUT]: Depends on unified InstalledSkill entries, repository identity, the SkillsGo logo asset, selection visibility and callbacks, update state, and an optional External Adoption Review entry action.
 * [OUTPUT]: Provides grouping data, deterministic repository grouping, compact source identity, and installed Skill group cards with conditionally hidden selection controls plus an optional left-aligned External Skills management action and reduced-motion-aware idle guidance.
 * [POS]: Serves as the repository grouping segment of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _InstalledSkillGroupData {
  const _InstalledSkillGroupData({
    required this.source,
    required this.label,
    required this.skills,
  });

  final String source;
  final String label;
  final List<InstalledSkill> skills;
}

List<_InstalledSkillGroupData> _groupInstalledSkills(
  BuildContext context,
  List<InstalledSkill> skills,
) {
  final managed = <String, List<InstalledSkill>>{};
  final external = <InstalledSkill>[];
  for (final skill in skills) {
    if (skill.provenance == LibraryProvenance.external) {
      external.add(skill);
      continue;
    }
    final source = _installedSourceLabel(context, skill);
    managed.putIfAbsent(source, () => <InstalledSkill>[]).add(skill);
  }
  final compactNameCounts = <String, int>{};
  for (final source in managed.keys) {
    final compact = _compactRepositorySource(source).toLowerCase();
    compactNameCounts.update(compact, (count) => count + 1, ifAbsent: () => 1);
  }
  final groups =
      managed.entries.map((entry) {
        final compact = _compactRepositorySource(entry.key);
        final hasCollision = compactNameCounts[compact.toLowerCase()]! > 1;
        return _InstalledSkillGroupData(
          source: entry.key,
          label: hasCollision ? entry.key : compact,
          skills: entry.value,
        );
      }).toList()..sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
  if (external.isNotEmpty) {
    groups.add(
      _InstalledSkillGroupData(
        source: context.l10n.externalInstallation,
        label: context.l10n.externalInstallation,
        skills: external,
      ),
    );
  }
  return groups;
}

String _compactRepositorySource(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1 && parts.first.contains('.')) {
    return parts.skip(1).join('/');
  }
  return source;
}

class _InstalledSkillGroup extends StatelessWidget {
  const _InstalledSkillGroup({
    required this.group,
    required this.projects,
    required this.agentLabel,
    required this.onOpen,
    required this.selectedSkillKeys,
    required this.onSelectionChanged,
    this.selectionVisible = true,
    this.onAdoptionReview,
  });

  final _InstalledSkillGroupData group;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;
  final ValueChanged<InstalledSkill> onOpen;
  final Set<String> selectedSkillKeys;
  final void Function(InstalledSkill, bool) onSelectionChanged;
  final bool selectionVisible;
  final VoidCallback? onAdoptionReview;

  @override
  Widget build(BuildContext context) {
    final buttonForeground = context.skillsComponents.primaryForeground;
    final scheme = Theme.of(context).colorScheme;
    final surfaceDelta =
        (scheme.surface.computeLuminance() -
                buttonForeground.computeLuminance())
            .abs();
    final inverseSurfaceDelta =
        (scheme.inverseSurface.computeLuminance() -
                buttonForeground.computeLuminance())
            .abs();
    final contrastCandidate = surfaceDelta > inverseSurfaceDelta
        ? scheme.surface
        : scheme.inverseSurface;
    final shimmerHighlight =
        Color.lerp(buttonForeground, contrastCandidate, .32) ??
        buttonForeground;
    final header = Row(
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: RepositoryAvatar(
              source: group.source,
              imageUrl: _repositoryAvatarUrl(group.source),
              size: 42,
              borderRadius: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            group.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.skillsTypography.display.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(label: '${group.skills.length}'),
        const Spacer(),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 11, bottom: 9),
          child: onAdoptionReview == null
              ? header
              : Align(
                  alignment: AlignmentDirectional.centerStart,
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
                              key: const Key('library-external-skills-logo'),
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
                      SizedBox(
                        height: 48,
                        child: PrimaryCapsuleButton(
                          key: const Key('library-adoption-review-enter'),
                          label: context.l10n
                              .handExternalSkillsToSkillsGoManagementCount(
                                group.skills.length,
                              ),
                          height: 48,
                          horizontalPadding: 18,
                          labelWidget: ShimmerText(
                            text: context.l10n
                                .handExternalSkillsToSkillsGoManagementCount(
                                  group.skills.length,
                                ),
                            style: context.skillsTypography.label.copyWith(
                              color: buttonForeground,
                              fontWeight: FontWeight.w600,
                            ),
                            baseColor: buttonForeground,
                            highlightColor: shimmerHighlight,
                            duration: const Duration(milliseconds: 2600),
                            repeat: true,
                          ),
                          trailingWidget: const _IdleMagicSelectionIcon(),
                          onPressed: onAdoptionReview,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Column(
          children: [
            for (var index = 0; index < group.skills.length; index++) ...[
              if (index > 0) const SkillsSeparator.horizontal(),
              _InstalledSkillRow(
                skill: group.skills[index],
                selectionVisible: selectionVisible,
                projects: projects,
                selected: selectedSkillKeys.contains(
                  _librarySelectionKey(group.skills[index]),
                ),
                agentLabel: agentLabel,
                onOpen: () => onOpen(group.skills[index]),
                onSelectionChanged: (selected) =>
                    onSelectionChanged(group.skills[index], selected),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _IdleMagicSelectionIcon extends StatefulWidget {
  const _IdleMagicSelectionIcon();

  @override
  State<_IdleMagicSelectionIcon> createState() =>
      _IdleMagicSelectionIconState();
}

class _IdleMagicSelectionIconState extends State<_IdleMagicSelectionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> emphasis;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    emphasis = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 72),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 6),
    ]).animate(controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller
        ..stop()
        ..value = 0;
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: emphasis,
    child: const HugeIcon(
      icon: HugeIcons.strokeRoundedCursorMagicSelection04,
      size: 17,
      strokeWidth: 1.8,
    ),
    builder: (context, child) {
      final value = emphasis.value;
      return Transform.translate(
        offset: Offset(0, -1.2 * value),
        child: Transform.rotate(
          angle: .045 * value,
          child: Transform.scale(scale: 1 + .04 * value, child: child),
        ),
      );
    },
  );
}

String? _repositoryAvatarUrl(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length < 3 || parts.first.toLowerCase() != 'github.com') {
    return null;
  }
  return 'https://github.com/${Uri.encodeComponent(parts[1])}.png?size=84';
}
