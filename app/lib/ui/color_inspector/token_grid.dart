/*
 * [INPUT]: Depends on color role groups, responsive layout, section titles, and selectable Material surfaces.
 * [OUTPUT]: Provides the inspector header, responsive token grid, and section-title presentation.
 * [POS]: Serves as the navigation and grid segment of the development ColorScheme inspector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../color_scheme_inspector.dart';

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
                    '${_hex(seed)} · SkillsGo',
                    style: context.skillsTypography.metadata.copyWith(
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
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSun01,
                  strokeWidth: 1.8,
                ),
              ),
              ButtonSegment(
                value: Brightness.dark,
                label: Text(l10n.darkMode),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMoon02,
                  strokeWidth: 1.8,
                ),
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

class _TokenGrid extends StatelessWidget {
  const _TokenGrid({required this.roles});

  final List<_ColorRole> roles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 620
          ? 3
          : 2;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final role in roles)
            SizedBox(
              width: width,
              child: _ColorRoleCard(role: role),
            ),
        ],
      );
    },
  );
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
