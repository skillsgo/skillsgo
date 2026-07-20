/*
 * [INPUT]: Depends on Skill summaries, localized metric/trust/risk copy, SkillsGo status colors, and action-ready empty states.
 * [OUTPUT]: Provides Skill glyphs, empty states, compact metrics, and trust/risk label and color mapping.
 * [POS]: Serves as the status and feedback segment of the SkillsGo brand library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../brand.dart';

class SkillGlyph extends StatelessWidget {
  const SkillGlyph({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.skillsComponents.statusSuccessContainer,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(
        color: context.skillsComponents.statusSuccess,
        fontWeight: FontWeight.w800,
        fontSize: 17,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.action});
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.skillsTypography.display.copyWith(fontSize: 28),
            ),
            if (message?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.skillsTypography.body.copyWith(height: 1.5),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

String _metricLabel(BuildContext context, SkillSummary skill) {
  final l10n = AppLocalizations.of(context);
  final value = _compactCount(skill.installs);
  return switch (skill.metricKind) {
    SkillMetricKind.allTimeInstalls => l10n.allTimeMetric(value),
    SkillMetricKind.installs24h => l10n.trendingMetric(value),
    SkillMetricKind.hotVelocity => l10n.hotMetric(
      value,
      skill.metricChange >= 0
          ? '+${skill.metricChange}'
          : '${skill.metricChange}',
    ),
  };
}

String _compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _trustLabel(BuildContext context, SkillTrustLevel trust) {
  final l10n = AppLocalizations.of(context);
  return switch (trust) {
    SkillTrustLevel.unverified => l10n.trustUnverified,
    SkillTrustLevel.communityVerified => l10n.trustCommunityVerified,
    SkillTrustLevel.publisherVerified => l10n.trustPublisherVerified,
    SkillTrustLevel.official => l10n.trustOfficial,
    SkillTrustLevel.warned => l10n.trustWarned,
    SkillTrustLevel.delisted => l10n.trustDelisted,
  };
}

Color _trustColor(
  BuildContext context,
  SkillTrustLevel trust,
) => switch (trust) {
  SkillTrustLevel.unverified => context.skillsColors.foregroundMuted,
  SkillTrustLevel.communityVerified => context.skillsComponents.statusAccent,
  SkillTrustLevel.publisherVerified => context.skillsComponents.statusAccent,
  SkillTrustLevel.official => context.skillsComponents.statusSuccess,
  SkillTrustLevel.warned => context.skillsComponents.statusAttention,
  SkillTrustLevel.delisted => context.skillsComponents.statusDanger,
};

String _riskLabel(BuildContext context, SkillRiskAssessment risk) {
  final l10n = AppLocalizations.of(context);
  return switch (risk) {
    SkillRiskAssessment.unknown => l10n.riskUnknown,
    SkillRiskAssessment.low => l10n.riskLow,
    SkillRiskAssessment.medium => l10n.riskMedium,
    SkillRiskAssessment.high => l10n.riskHigh,
    SkillRiskAssessment.critical => l10n.riskCritical,
  };
}

Color _riskColor(BuildContext context, SkillRiskAssessment risk) =>
    switch (risk) {
      SkillRiskAssessment.unknown => context.skillsColors.foregroundMuted,
      SkillRiskAssessment.low => context.skillsComponents.statusSuccess,
      SkillRiskAssessment.medium => context.skillsComponents.statusAttention,
      SkillRiskAssessment.high => context.skillsComponents.statusSevere,
      SkillRiskAssessment.critical => context.skillsComponents.statusDanger,
    };
