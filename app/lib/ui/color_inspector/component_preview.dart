/*
 * [INPUT]: Depends on the generated ThemeData, SkillsGo component tokens, and native Material preview controls.
 * [OUTPUT]: Provides the representative buttons, fields, selections, alerts, navigation, and surface component preview.
 * [POS]: Serves as the component-preview segment of the development ColorScheme inspector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../color_scheme_inspector.dart';

class _ComponentPreview extends StatelessWidget {
  const _ComponentPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(onPressed: () {}, child: Text(l10n.install)),
          FilledButton.tonal(onPressed: () {}, child: Text(l10n.save)),
          OutlinedButton(onPressed: () {}, child: Text(l10n.retry)),
          SizedBox(
            width: 230,
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchSkills,
                prefixIcon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 20,
                  strokeWidth: 1.8,
                ),
              ),
            ),
          ),
          Container(
            width: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.colorSchemeSampleTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.colorSchemeSampleBody,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<_ColorRole> _skillsTokenRoles(
  SkillsColorTokens colors,
  AppLocalizations l10n,
) => [
  _ColorRole('canvas', colors.canvas, l10n.colorSchemeUsageSurface),
  _ColorRole(
    'folderBody',
    colors.folderBody,
    l10n.colorSchemeUsageSurfaceElevation('Folder'),
  ),
  _ColorRole(
    'folderTabInactive',
    colors.folderTabInactive,
    l10n.colorSchemeUsageSurfaceElevation('Folder tab'),
  ),
  _ColorRole(
    'surfaceDefault',
    colors.surfaceDefault,
    l10n.colorSchemeUsageSurface,
  ),
  _ColorRole(
    'surfaceMuted',
    colors.surfaceMuted,
    l10n.colorSchemeUsageSurfaceElevation('muted'),
  ),
  _ColorRole(
    'surfaceRaised',
    colors.surfaceRaised,
    l10n.colorSchemeUsageSurfaceElevation('raised'),
  ),
  _ColorRole(
    'surfaceInset',
    colors.surfaceInset,
    l10n.colorSchemeUsageSurfaceElevation('inset'),
  ),
  _ColorRole(
    'foregroundDefault',
    colors.foregroundDefault,
    l10n.colorSchemeUsageContentOn('surface'),
  ),
  _ColorRole(
    'foregroundMuted',
    colors.foregroundMuted,
    l10n.colorSchemeUsageContentOn('muted surface'),
  ),
  _ColorRole(
    'foregroundSubtle',
    colors.foregroundSubtle,
    l10n.colorSchemeUsageContentOn('subtle surface'),
  ),
  _ColorRole(
    'borderDefault',
    colors.borderDefault,
    l10n.colorSchemeUsageOutline,
  ),
  _ColorRole(
    'borderMuted',
    colors.borderMuted,
    l10n.colorSchemeUsageOutlineVariant,
  ),
  _ColorRole('accent', colors.accent, l10n.colorSchemeUsagePrimary),
  _ColorRole(
    'accentHover',
    colors.accentHover,
    l10n.colorSchemeUsageFixedDim('accent'),
  ),
  _ColorRole(
    'accentMuted',
    colors.accentMuted,
    l10n.colorSchemeUsageContainer('accent'),
  ),
  _ColorRole(
    'onAccent',
    colors.onAccent,
    l10n.colorSchemeUsageContentOn('accent'),
  ),
];

List<_ColorGroup> _groups(ColorScheme scheme, AppLocalizations l10n) => [
  _ColorGroup(
    name: l10n.colorSchemeGroupPrimary,
    description: l10n.colorSchemeGroupPrimaryDescription,
    roles: [
      _ColorRole('primary', scheme.primary, l10n.colorSchemeUsagePrimary),
      _ColorRole(
        'onPrimary',
        scheme.onPrimary,
        l10n.colorSchemeUsageContentOn('primary'),
      ),
      _ColorRole(
        'primaryContainer',
        scheme.primaryContainer,
        l10n.colorSchemeUsageContainer('primary'),
      ),
      _ColorRole(
        'onPrimaryContainer',
        scheme.onPrimaryContainer,
        l10n.colorSchemeUsageContentOn('primaryContainer'),
      ),
      _ColorRole(
        'primaryFixed',
        scheme.primaryFixed,
        l10n.colorSchemeUsageFixed('primary'),
      ),
      _ColorRole(
        'primaryFixedDim',
        scheme.primaryFixedDim,
        l10n.colorSchemeUsageFixedDim('primary'),
      ),
      _ColorRole(
        'onPrimaryFixed',
        scheme.onPrimaryFixed,
        l10n.colorSchemeUsageFixedContent('primary'),
      ),
      _ColorRole(
        'onPrimaryFixedVariant',
        scheme.onPrimaryFixedVariant,
        l10n.colorSchemeUsageFixedVariantContent('primary'),
      ),
    ],
  ),
  _ColorGroup(
    name: l10n.colorSchemeGroupSecondary,
    description: l10n.colorSchemeGroupSecondaryDescription,
    roles: [
      _ColorRole('secondary', scheme.secondary, l10n.colorSchemeUsageSecondary),
      _ColorRole(
        'onSecondary',
        scheme.onSecondary,
        l10n.colorSchemeUsageContentOn('secondary'),
      ),
      _ColorRole(
        'secondaryContainer',
        scheme.secondaryContainer,
        l10n.colorSchemeUsageContainer('secondary'),
      ),
      _ColorRole(
        'onSecondaryContainer',
        scheme.onSecondaryContainer,
        l10n.colorSchemeUsageContentOn('secondaryContainer'),
      ),
      _ColorRole(
        'secondaryFixed',
        scheme.secondaryFixed,
        l10n.colorSchemeUsageFixed('secondary'),
      ),
      _ColorRole(
        'secondaryFixedDim',
        scheme.secondaryFixedDim,
        l10n.colorSchemeUsageFixedDim('secondary'),
      ),
      _ColorRole(
        'onSecondaryFixed',
        scheme.onSecondaryFixed,
        l10n.colorSchemeUsageFixedContent('secondary'),
      ),
      _ColorRole(
        'onSecondaryFixedVariant',
        scheme.onSecondaryFixedVariant,
        l10n.colorSchemeUsageFixedVariantContent('secondary'),
      ),
    ],
  ),
  _ColorGroup(
    name: l10n.colorSchemeGroupTertiary,
    description: l10n.colorSchemeGroupTertiaryDescription,
    roles: [
      _ColorRole('tertiary', scheme.tertiary, l10n.colorSchemeUsageTertiary),
      _ColorRole(
        'onTertiary',
        scheme.onTertiary,
        l10n.colorSchemeUsageContentOn('tertiary'),
      ),
      _ColorRole(
        'tertiaryContainer',
        scheme.tertiaryContainer,
        l10n.colorSchemeUsageContainer('tertiary'),
      ),
      _ColorRole(
        'onTertiaryContainer',
        scheme.onTertiaryContainer,
        l10n.colorSchemeUsageContentOn('tertiaryContainer'),
      ),
      _ColorRole(
        'tertiaryFixed',
        scheme.tertiaryFixed,
        l10n.colorSchemeUsageFixed('tertiary'),
      ),
      _ColorRole(
        'tertiaryFixedDim',
        scheme.tertiaryFixedDim,
        l10n.colorSchemeUsageFixedDim('tertiary'),
      ),
      _ColorRole(
        'onTertiaryFixed',
        scheme.onTertiaryFixed,
        l10n.colorSchemeUsageFixedContent('tertiary'),
      ),
      _ColorRole(
        'onTertiaryFixedVariant',
        scheme.onTertiaryFixedVariant,
        l10n.colorSchemeUsageFixedVariantContent('tertiary'),
      ),
    ],
  ),
  _ColorGroup(
    name: l10n.colorSchemeGroupSurface,
    description: l10n.colorSchemeGroupSurfaceDescription,
    roles: [
      _ColorRole('surface', scheme.surface, l10n.colorSchemeUsageSurface),
      _ColorRole(
        'surfaceDim',
        scheme.surfaceDim,
        l10n.colorSchemeUsageSurfaceDim,
      ),
      _ColorRole(
        'surfaceBright',
        scheme.surfaceBright,
        l10n.colorSchemeUsageSurfaceBright,
      ),
      _ColorRole(
        'surfaceContainerLowest',
        scheme.surfaceContainerLowest,
        l10n.colorSchemeUsageSurfaceElevation(l10n.colorSchemeElevationLowest),
      ),
      _ColorRole(
        'surfaceContainerLow',
        scheme.surfaceContainerLow,
        l10n.colorSchemeUsageSurfaceElevation(l10n.colorSchemeElevationLow),
      ),
      _ColorRole(
        'surfaceContainer',
        scheme.surfaceContainer,
        l10n.colorSchemeUsageSurfaceElevation(l10n.colorSchemeElevationDefault),
      ),
      _ColorRole(
        'surfaceContainerHigh',
        scheme.surfaceContainerHigh,
        l10n.colorSchemeUsageSurfaceElevation(l10n.colorSchemeElevationHigh),
      ),
      _ColorRole(
        'surfaceContainerHighest',
        scheme.surfaceContainerHighest,
        l10n.colorSchemeUsageSurfaceElevation(l10n.colorSchemeElevationHighest),
      ),
      _ColorRole('onSurface', scheme.onSurface, l10n.colorSchemeUsageOnSurface),
      _ColorRole(
        'onSurfaceVariant',
        scheme.onSurfaceVariant,
        l10n.colorSchemeUsageOnSurfaceVariant,
      ),
      _ColorRole(
        'surfaceTint',
        scheme.surfaceTint,
        l10n.colorSchemeUsageSurfaceTint,
      ),
    ],
  ),
  _ColorGroup(
    name: l10n.colorSchemeGroupUtility,
    description: l10n.colorSchemeGroupUtilityDescription,
    roles: [
      _ColorRole('outline', scheme.outline, l10n.colorSchemeUsageOutline),
      _ColorRole(
        'outlineVariant',
        scheme.outlineVariant,
        l10n.colorSchemeUsageOutlineVariant,
      ),
      _ColorRole('shadow', scheme.shadow, l10n.colorSchemeUsageShadow),
      _ColorRole('scrim', scheme.scrim, l10n.colorSchemeUsageScrim),
      _ColorRole(
        'inverseSurface',
        scheme.inverseSurface,
        l10n.colorSchemeUsageInverseSurface,
      ),
      _ColorRole(
        'onInverseSurface',
        scheme.onInverseSurface,
        l10n.colorSchemeUsageContentOn('inverseSurface'),
      ),
      _ColorRole(
        'inversePrimary',
        scheme.inversePrimary,
        l10n.colorSchemeUsageInversePrimary,
      ),
    ],
  ),
  _ColorGroup(
    name: l10n.colorSchemeGroupError,
    description: l10n.colorSchemeGroupErrorDescription,
    roles: [
      _ColorRole('error', scheme.error, l10n.colorSchemeUsageError),
      _ColorRole(
        'onError',
        scheme.onError,
        l10n.colorSchemeUsageContentOn('error'),
      ),
      _ColorRole(
        'errorContainer',
        scheme.errorContainer,
        l10n.colorSchemeUsageContainer('error'),
      ),
      _ColorRole(
        'onErrorContainer',
        scheme.onErrorContainer,
        l10n.colorSchemeUsageContentOn('errorContainer'),
      ),
    ],
  ),
];
