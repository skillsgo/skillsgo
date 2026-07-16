/*
 * [INPUT]: Depends on the current SkillsGo seed, Material 3 ColorScheme generation, localization, and clipboard services.
 * [OUTPUT]: Renders a read-only Light/Dark inspector for every non-deprecated Material 3 ColorScheme role plus semantic pair and component previews.
 * [POS]: Serves as the Settings developer surface for validating generated theme roles without creating a second theme system.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'brand.dart';

class ColorSchemeInspector extends StatefulWidget {
  const ColorSchemeInspector({super.key, required this.seed});

  final Color seed;

  @override
  State<ColorSchemeInspector> createState() => _ColorSchemeInspectorState();
}

class _ColorSchemeInspectorState extends State<ColorSchemeInspector> {
  late Brightness previewBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    previewBrightness = Theme.of(context).brightness;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final previewTheme = buildSkillsTheme(
      widget.seed,
      brightness: previewBrightness,
    );
    final scheme = previewTheme.colorScheme;
    final groups = _groups(scheme, l10n);
    return Theme(
      data: previewTheme,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InspectorHeader(
              seed: widget.seed,
              brightness: previewBrightness,
              onBrightnessChanged: (value) =>
                  setState(() => previewBrightness = value),
            ),
            const SizedBox(height: 24),
            for (final group in groups) ...[
              _SectionTitle(title: group.name, description: group.description),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 620
                      ? 3
                      : 2;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final role in group.roles)
                        SizedBox(
                          width: width,
                          child: _ColorRoleCard(role: role),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
            _SectionTitle(
              title: l10n.colorSchemePairPreview,
              description: l10n.colorSchemePairPreviewDescription,
            ),
            const SizedBox(height: 12),
            _SemanticPairGrid(scheme: scheme),
            const SizedBox(height: 30),
            _SectionTitle(
              title: l10n.colorSchemeComponentPreview,
              description: l10n.colorSchemeComponentPreviewDescription,
            ),
            const SizedBox(height: 12),
            const _ComponentPreview(),
          ],
        ),
      ),
    );
  }
}

class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({
    required this.seed,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  final Color seed;
  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

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
        spacing: 24,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.colorSchemeInspectorTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                l10n.colorSchemeInspectorDescription,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: seed,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_hex(seed)} · fidelity',
                    style: const TextStyle(
                      fontFamily: SkillsTokens.monoFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SegmentedButton<Brightness>(
            segments: [
              ButtonSegment(
                value: Brightness.light,
                label: Text(l10n.lightMode),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: Brightness.dark,
                label: Text(l10n.darkMode),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {brightness},
            onSelectionChanged: (values) => onBrightnessChanged(values.single),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        description,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _ColorRoleCard extends StatefulWidget {
  const _ColorRoleCard({required this.role});

  final _ColorRole role;

  @override
  State<_ColorRoleCard> createState() => _ColorRoleCardState();
}

class _ColorRoleCardState extends State<_ColorRoleCard> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final role = widget.role;
    final foreground = _readableForeground(role.color);
    return Material(
      color: role.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: _hex(role.color)));
          if (!mounted) return;
          setState(() => copied = true);
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (mounted) setState(() => copied = false);
        },
        child: SizedBox(
          height: 148,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    role.usage,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: .72),
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  copied
                      ? '${l10n.colorSchemeCopied} · ${_hex(role.color)}'
                      : _hex(role.color),
                  style: TextStyle(
                    color: foreground.withValues(alpha: .82),
                    fontFamily: SkillsTokens.monoFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SemanticPairGrid extends StatelessWidget {
  const _SemanticPairGrid({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final pairs = [
      ('primary / onPrimary', scheme.primary, scheme.onPrimary),
      (
        'primaryContainer / onPrimaryContainer',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ('secondary / onSecondary', scheme.secondary, scheme.onSecondary),
      (
        'secondaryContainer / onSecondaryContainer',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ('tertiary / onTertiary', scheme.tertiary, scheme.onTertiary),
      (
        'tertiaryContainer / onTertiaryContainer',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ('error / onError', scheme.error, scheme.onError),
      (
        'errorContainer / onErrorContainer',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      ('surface / onSurface', scheme.surface, scheme.onSurface),
      (
        'surfaceContainer / onSurface',
        scheme.surfaceContainer,
        scheme.onSurface,
      ),
      (
        'surfaceContainerHigh / onSurfaceVariant',
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
      ),
      (
        'inverseSurface / onInverseSurface',
        scheme.inverseSurface,
        scheme.onInverseSurface,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final pair in pairs)
              SizedBox(
                width: width,
                child: Container(
                  height: 128,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pair.$2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pair.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: pair.$3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${AppLocalizations.of(context).colorSchemeSampleGlyphs} · ${_hex(pair.$2)}',
                        style: TextStyle(color: pair.$3, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
                prefixIcon: const Icon(Icons.search),
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

Color _readableForeground(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _ColorRole {
  const _ColorRole(this.name, this.color, this.usage);

  final String name;
  final Color color;
  final String usage;
}

class _ColorGroup {
  const _ColorGroup({
    required this.name,
    required this.description,
    required this.roles,
  });

  final String name;
  final String description;
  final List<_ColorRole> roles;
}
