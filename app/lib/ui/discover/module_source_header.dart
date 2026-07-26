/*
 * [INPUT]: Depends on Module metadata, localized copy, SkillsGo typography, and installation callbacks.
 * [OUTPUT]: Provides the Module source header, metadata formatting, and install-all action.
 * [POS]: Serves as the Module-context presentation segment of the Discover journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../discover_screen.dart';

class _ModuleSourceHeader extends StatelessWidget {
  const _ModuleSourceHeader({
    required this.modulePath,
    required this.skills,
    required this.onInstallAll,
    this.module,
  });

  final String modulePath;
  final List<SkillSummary> skills;
  final ValueChanged<InstallLocationMenuPresenter> onInstallAll;
  final ModuleSummary? module;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstSkill = skills.first;
    final summary = module;
    final description = summary?.description.trim() ?? '';
    final metadata = <String>[
      if ((summary?.stars ?? 0) > 0) '★ ${_moduleCompactCount(summary!.stars)}',
      context.l10n.skillCount(skills.length),
      if (summary?.updatedAt != null)
        '${context.l10n.detailUpdated} ${_moduleDate(summary!.updatedAt!)}',
    ];
    final version = summary?.latestVersion.isNotEmpty == true
        ? summary!.latestVersion
        : firstSkill.latestVersion;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepositoryAvatar(
          source: modulePath,
          imageUrl: summary?.imageUrl ?? firstSkill.imageUrl,
          size: 88,
          borderRadius: 16,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _modulePathLabel(modulePath),
                textDirection: contentTextDirection(modulePath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  textDirection: contentTextDirection(description),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var index = 0; index < metadata.length; index++) ...[
                    if (index > 0)
                      Text('·', style: TextStyle(color: scheme.outline)),
                    Text(
                      metadata[index],
                      textDirection: contentTextDirection(metadata[index]),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (version.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 150),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _moduleVersionLabel(context, version),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            InstallLocationMenuAnchor(
              builder: (context, present) => PrimaryCapsuleButton(
                key: const Key('module-install-all'),
                label: context.l10n.installAll,
                height: 40,
                horizontalPadding: 18,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                onPressed: () => onInstallAll(present),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _moduleDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _modulePathLabel(String modulePath) {
  final segments = modulePath.split('/');
  return segments.length > 1 && segments.first.contains('.')
      ? segments.skip(1).join(' / ')
      : modulePath;
}

String _moduleCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
  }
  return '$value';
}

String _moduleVersionLabel(BuildContext context, String version) {
  if (RegExp(r'^v\d+\.\d+\.\d+').hasMatch(version)) return version;
  return context.l10n.latestCommit;
}
