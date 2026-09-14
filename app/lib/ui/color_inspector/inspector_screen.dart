/*
 * [INPUT]: Depends on Material ColorScheme generation, theme controls, semantic token groups, and component preview sections.
 * [OUTPUT]: Provides the public inspector screen, seed/brightness state, header controls, and section composition.
 * [POS]: Serves as the state-owning screen of the development ColorScheme inspector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../color_scheme_inspector.dart';

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
    final skillsColors = previewTheme.extension<SkillsColorTokens>()!;
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
            _SectionTitle(
              title: l10n.skillsColorTokensTitle,
              description: l10n.skillsColorTokensDescription,
            ),
            const SizedBox(height: 12),
            _TokenGrid(roles: _skillsTokenRoles(skillsColors, l10n)),
            const SizedBox(height: 30),
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
