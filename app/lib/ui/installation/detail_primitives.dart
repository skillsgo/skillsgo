/*
 * [INPUT]: Depends on the Installation journey library, domain detail models, InstallOperationController, localized status copy, and SkillsGo presentation primitives.
 * [OUTPUT]: Provides shared failure details, card skeletons, exact-version Package enumeration, one direct presentation-facing Installation submission seam, completion feedback, Skill hero with inline context actions, and detail-page layout.
 * [POS]: Serves as the reusable detail and Installation Request presentation primitives.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

Widget _targetFailureDetails(BuildContext context, TargetFailure failure) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(switch (failure.code) {
        'installation.target_failed' =>
          context.l10n.installationTargetFailureMessage,
        'workspace.persistence_failed' =>
          context.l10n.workspacePersistenceFailureMessage,
        'installation.state_changed' =>
          context.l10n.installationStateChangedMessage,
        'update.target_failed' => context.l10n.updateTargetFailureMessage,
        'management.target_failed' =>
          context.l10n.managementTargetFailureMessage,
        _ =>
          failure.retryable
              ? context.l10n.targetFailureRetryable
              : context.l10n.targetFailureNeedsAttention,
      }, style: TextStyle(color: context.skillsComponents.statusDanger)),
      if (failure.diagnostic.isNotEmpty)
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              context.l10n.technicalDetails,
              style: context.skillsTypography.metadata,
            ),
            children: [
              SelectableText(
                failure.diagnostic,
                style: context.skillsTypography.caption.copyWith(
                  color: context.skillsComponents.statusDanger,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class SkillCardSkeleton extends StatelessWidget {
  const SkillCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.skillsComponents.cardRest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Padding(
      padding: EdgeInsets.fromLTRB(16, 15, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkillsSkeletonBox(height: 38, width: 38, borderRadius: 10),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkillsSkeletonBox(height: 15, width: 150),
                    SizedBox(height: 8),
                    SkillsSkeletonBox(height: 11, width: 110),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          SkillsSkeletonBox(height: 12),
          SizedBox(height: 8),
          SkillsSkeletonBox(height: 12, width: 220),
          Spacer(),
          SkillsSkeletonBox(height: 11, width: 96),
        ],
      ),
    ),
  );
}

Future<List<SkillSummary>> loadPackageSkills(
  SkillsGateway gateway,
  SkillSummary current,
  SkillDetail detail,
) async {
  final packagePath = detail.packagePath.trim();
  if (packagePath.isEmpty) return [current];
  try {
    final skills = <String, SkillSummary>{};
    var pageNumber = 0;
    while (true) {
      final page = await gateway.discover(
        DiscoveryCollection.search,
        query: '$packagePath@${current.latestVersion}',
        page: pageNumber,
        perPage: 100,
      );
      for (final skill in page.skills) {
        if (skill.packagePath == packagePath) {
          skills[skill.coordinateKey] = skill;
        }
      }
      final next = page.pagination.nextPage;
      if (next == null || next <= pageNumber) break;
      pageNumber = next;
    }
    skills[current.coordinateKey] = current;
    final values = skills.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return values;
  } on Object {
    return [current];
  }
}

class InstallationSubmissionRequest {
  const InstallationSubmissionRequest({
    required this.choice,
    required this.skill,
    required this.immutableVersion,
    required this.moduleSkills,
    required this.riskPolicy,
  });

  final InstallLocationChoice choice;
  final SkillSummary skill;
  final String immutableVersion;
  final List<SkillSummary> moduleSkills;
  final PersonalRiskPolicy riskPolicy;
}

Future<InstallLocationSubmission> submitInstallationRequest(
  BuildContext context,
  InstallOperationController operation,
  InstallationSubmissionRequest request,
) async {
  final failureTitle = context.l10n.installationFailed;
  final fallbackMessage = context.l10n.installationPlanFailed;
  if (request.choice.selections.isEmpty) {
    return InstallLocationSubmission.failure(
      title: failureTitle,
      message: fallbackMessage,
    );
  }
  final operationRequest =
      request.choice.action == InstallLocationAction.moduleSkills
      ? InstallationRequest.module(
          request.moduleSkills,
          selections: request.choice.selections,
          riskPolicy: request.riskPolicy,
        )
      : InstallationRequest.skill(
          request.skill,
          request.immutableVersion,
          selections: request.choice.selections,
          riskPolicy: request.riskPolicy,
        );
  try {
    final outcome = await operation.submit(operationRequest);
    if (outcome.succeeded) return const InstallLocationSubmission.success();
    if (!context.mounted) {
      return InstallLocationSubmission.failure(
        title: failureTitle,
        message: fallbackMessage,
      );
    }
    final copy = failureCopy(
      context,
      outcome.error ?? StateError('Installation failed.'),
    );
    return InstallLocationSubmission.failure(
      title: failureTitle,
      message: copy.message,
    );
  } on Object catch (error) {
    if (!context.mounted) {
      return InstallLocationSubmission.failure(
        title: failureTitle,
        message: fallbackMessage,
      );
    }
    final copy = failureCopy(context, error);
    return InstallLocationSubmission.failure(
      title: failureTitle,
      message: copy.message,
    );
  }
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final copy = failureCopy(context, error);
    return SkillsAlert.destructive(
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedAlertCircle,
        strokeWidth: 1.8,
      ),
      title: Text(context.l10n.installationFailed),
      description: Text(copy.message),
    );
  }
}

class _InstallationCompletionBanner extends StatelessWidget {
  const _InstallationCompletionBanner({required this.execution});
  final InstallationExecution execution;

  @override
  Widget build(BuildContext context) => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.installationResults),
    description: Text(
      context.l10n.installationResultSummary(
        execution.summary.succeeded,
        execution.summary.failed,
      ),
    ),
  );
}

String _targetLabel(BuildContext context, InstallationPlanTarget target) {
  final location = target.scope == InstallationScope.global
      ? context.l10n.globalScope
      : p.basename(target.projectRoot);
  return '$location / ${target.agent}';
}

const _skillDetailSectionGap = 24.0;
const _skillDetailDocumentGap = 24.0;

Widget _skillDetailDivider(BuildContext context) => SkillsSeparator.horizontal(
  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
);

class SkillDetailHero extends StatelessWidget {
  const SkillDetailHero({
    super.key,
    required this.name,
    required this.source,
    required this.description,
    required this.actions,
    this.titleContext,
    this.imageUrl,
    this.avatarKey,
    this.descriptionKey,
  });

  final String name;
  final String source;
  final String description;
  final String? imageUrl;
  final Key? avatarKey;
  final Key? descriptionKey;
  final Widget actions;
  final Widget? titleContext;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PackageAvatar(
        key: avatarKey,
        source: source,
        imageUrl: imageUrl,
        size: 116,
        borderRadius: 24,
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              textDirection: contentTextDirection(name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.skillsTypography.display,
                            ),
                          ),
                          if (titleContext != null) ...[
                            const SizedBox(width: 12),
                            titleContext!,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    actions,
                  ],
                ),
                const SizedBox(height: 8),
                if (description.trim().isNotEmpty)
                  Text(
                    description.trim(),
                    textDirection: contentTextDirection(description),
                    key: descriptionKey,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.skillsTypography.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.42,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class SkillDetailPageBody extends StatelessWidget {
  const SkillDetailPageBody({
    super.key,
    required this.scrollKey,
    required this.hero,
    required this.contextArea,
    required this.document,
    this.controller,
  });

  final Key scrollKey;
  final ScrollController? controller;
  final Widget hero;
  final Widget contextArea;
  final Widget document;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: scrollKey,
    controller: controller,
    padding: const EdgeInsets.only(top: 76, bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const SizedBox(height: _skillDetailSectionGap),
        _skillDetailDivider(context),
        contextArea,
        _skillDetailDivider(context),
        const SizedBox(height: _skillDetailDocumentGap),
        document,
      ],
    ),
  );
}
