/*
 * [INPUT]: Depends on Package metadata, localized copy, shared Package update-check state, SkillsGo components, and detail/installation callbacks.
 * [OUTPUT]: Provides the reusable full-surface Package summary card used by Discover results and Package detail.
 * [POS]: Serves as the shared Package identity and action surface in the App UI module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/skills_gateway.dart';
import 'bidirectional_content.dart';
import 'brand.dart';
import 'install_location_popover.dart';
import 'native_components.dart';
import 'package_update_check_controller.dart';
import 'ui_support.dart';

class PackageSummaryCard extends ConsumerWidget {
  const PackageSummaryCard({
    super.key,
    required this.packagePath,
    required this.skills,
    this.onInstallAll,
    this.onUpdated,
    this.onOpen,
    this.summary,
  });

  final String packagePath;
  final List<SkillSummary> skills;
  final ValueChanged<InstallLocationMenuPresenter>? onInstallAll;
  final Future<void> Function()? onUpdated;
  final VoidCallback? onOpen;
  final PackageSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final firstSkill = skills.firstOrNull;
    final description = summary?.description.trim() ?? '';
    final metadata = <String>[
      if ((summary?.stars ?? 0) > 0) '★ ${_compactCount(summary!.stars)}',
      context.l10n.skillCount(skills.length),
      if (summary?.updatedAt != null)
        '${context.l10n.detailUpdated} ${_date(summary!.updatedAt!)}',
    ];
    final version = summary?.latestVersion.isNotEmpty == true
        ? summary!.latestVersion
        : firstSkill?.latestVersion ?? '';
    final updateOperation = ref.watch(
      packageUpdateOperationProvider(packagePath),
    );
    final updateState = updateOperation.state;

    return Material(
      key: const Key('package-summary-card'),
      color: Theme.of(context).brightness == Brightness.light
          ? scheme.surfaceContainer
          : context.skillsComponents.cardRest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: onOpen == null ? null : const Key('discover-open-package-detail'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PackageAvatar(
                source: packagePath,
                imageUrl: summary?.imageUrl ?? firstSkill?.imageUrl,
                size: 88,
                borderRadius: 16,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pathLabel(packagePath),
                      textDirection: contentTextDirection(packagePath),
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
                        for (
                          var index = 0;
                          index < metadata.length;
                          index++
                        ) ...[
                          if (index > 0)
                            Text('·', style: TextStyle(color: scheme.outline)),
                          Text(
                            metadata[index],
                            textDirection: contentTextDirection(
                              metadata[index],
                            ),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (version.isNotEmpty) ...[
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _versionLabel(context, version),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.skillsTypography.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      SecondaryCapsuleButton(
                        key: const Key('package-check-update'),
                        label: packageUpdateOperationLabel(
                          context,
                          updateState,
                        ),
                        icon:
                            updateState.phase ==
                                    PackageUpdateOperationPhase.updated ||
                                updateState.phase ==
                                    PackageUpdateOperationPhase.upToDate
                            ? HugeIcons.strokeRoundedCheckmarkCircle02
                            : HugeIcons.strokeRoundedRefresh,
                        onPressed: onUpdated == null || updateState.busy
                            ? null
                            : () async {
                                final result = await updateOperation.check(
                                  version,
                                );
                                if (result.phase ==
                                    PackageUpdateOperationPhase.updated) {
                                  await onUpdated!();
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  InstallLocationMenuAnchor(
                    builder: (context, present) => PrimaryCapsuleButton(
                      key: const Key('package-install-all'),
                      label: context.l10n.installAll,
                      height: 40,
                      horizontalPadding: 18,
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      onPressed: onInstallAll == null
                          ? null
                          : () => onInstallAll!(present),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _pathLabel(String packagePath) {
  final segments = packagePath.split('/');
  return segments.length > 1 && segments.first.contains('.')
      ? segments.skip(1).join(' / ')
      : packagePath;
}

String _compactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
  }
  return '$value';
}

String _versionLabel(BuildContext context, String version) {
  if (RegExp(r'^v\d+\.\d+\.\d+').hasMatch(version)) return version;
  return context.l10n.latestCommit;
}
