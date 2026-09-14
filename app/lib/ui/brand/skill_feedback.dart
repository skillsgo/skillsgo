/*
 * [INPUT]: Depends on Skill summaries, localized metric copy, SkillsGo status colors, and action-ready empty states.
 * [OUTPUT]: Provides Skill glyphs, empty states, and compact metrics.
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
    null => skill.latestVersion,
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
