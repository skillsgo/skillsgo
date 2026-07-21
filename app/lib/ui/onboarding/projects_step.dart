/*
 * [INPUT]: Depends on Added Projects, project identities, add/remove callbacks, Installed navigation preview, loading/error states, and localized copy.
 * [OUTPUT]: Provides the cumulative Projects step, add-project action, installed-path preview, and responsive project strip.
 * [POS]: Serves as the second step of Mandatory Onboarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../onboarding_screen.dart';

class _ProjectsStep extends StatelessWidget {
  const _ProjectsStep({
    required this.projects,
    required this.loaded,
    required this.loadError,
    required this.notice,
    required this.noticeIsError,
    required this.busy,
    required this.onRetry,
    required this.onAddProject,
    required this.onRemoveProject,
  });

  final List<AddedProject> projects;
  final bool loaded;
  final Object? loadError;
  final String? notice;
  final bool noticeIsError;
  final bool busy;
  final Future<bool> Function() onRetry;
  final VoidCallback onAddProject;
  final ValueChanged<AddedProject> onRemoveProject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.onboardingProjectsTitle,
          style: context.skillsTypography.display,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingProjectsDescription,
          style: context.skillsTypography.bodySecondary,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            SkillsButton.ghost(
              height: 40,
              backgroundColor: context.skillsComponents.controlRest,
              enabled: loaded && loadError == null && !busy,
              onPressed: onAddProject,
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedFolderOpen,
                size: 18,
                strokeWidth: 1.8,
              ),
              child: Text(l10n.onboardingAddProject),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.onboardingAddProjectLater,
                    style: context.skillsTypography.bodySecondary,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(child: _InstalledAddProjectPreview()),
                ],
              ),
            ),
          ],
        ),
        if (projects.isNotEmpty) ...[
          const SizedBox(height: 18),
          _OnboardingProjectStrip(
            projects: projects,
            onRemoveProject: onRemoveProject,
          ),
        ],
        if (!loaded && loadError == null) ...[
          const SizedBox(height: 18),
          Semantics(
            liveRegion: true,
            label: l10n.loading,
            child: const SkillsSkeletonBox(height: 16, borderRadius: 8),
          ),
        ],
        if (!loaded && loadError != null) ...[
          const SizedBox(height: 18),
          SkillsAlert.destructive(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 18,
              strokeWidth: 1.8,
            ),
            title: Text(l10n.onboardingProjectsLoadError),
            description: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SkillsButton.ghost(
                onPressed: () => unawaited(onRetry()),
                size: SkillsButtonSize.sm,
                child: Text(l10n.retry),
              ),
            ),
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: 18),
          Text(
            notice!,
            style: context.skillsTypography.bodySecondary.copyWith(
              color: noticeIsError
                  ? context.skillsComponents.statusDanger
                  : context.skillsComponents.statusSuccess,
            ),
          ),
        ],
      ],
    );
  }
}

class _InstalledAddProjectPreview extends StatelessWidget {
  const _InstalledAddProjectPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.skillsColors;
    return Semantics(
      label: '${l10n.library}, ${l10n.addProject}',
      child: ExcludeSemantics(
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.skillsComponents.controlRest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.library, style: context.skillsTypography.label),
              const SizedBox(width: 7),
              Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 13,
                  strokeWidth: 1.6,
                  color: colors.foregroundMuted,
                ),
              ),
              const SizedBox(width: 7),
              HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 15,
                strokeWidth: 1.8,
                color: colors.foregroundDefault,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.addProject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingProjectStrip extends StatelessWidget {
  const _OnboardingProjectStrip({
    required this.projects,
    required this.onRemoveProject,
  });

  final List<AddedProject> projects;
  final ValueChanged<AddedProject> onRemoveProject;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160),
    alignment: AlignmentDirectional.centerStart,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const columns = 5;
        final itemWidth = constraints.maxWidth / columns;
        return Wrap(
          runSpacing: 8,
          children: [
            for (var index = 0; index < projects.length; index++)
              Container(
                width: itemWidth,
                padding: EdgeInsets.only(
                  left: index % columns == 0 ? 0 : 10,
                  right: 10,
                ),
                child: _OnboardingProjectItem(
                  key: ValueKey('onboarding-project-${projects[index].id}'),
                  project: projects[index],
                  onRemove: () => onRemoveProject(projects[index]),
                ),
              ),
          ],
        );
      },
    ),
  );
}
