/*
 * [INPUT]: Depends on semantic color roles, readable foreground calculation, clipboard services, and hover/copy feedback.
 * [OUTPUT]: Provides interactive color role cards and semantic foreground/background pair grids.
 * [POS]: Serves as the inspectable token-card segment of the development ColorScheme inspector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../color_scheme_inspector.dart';

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
                  style: context.skillsTypography.metadata.copyWith(
                    color: foreground.withValues(alpha: .82),
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
