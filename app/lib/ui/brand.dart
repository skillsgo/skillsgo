/*
 * [INPUT]: Depends on SkillsGateway discovery models, localized copy, Flutter Material rendering, native components, and the shared installation MenuAnchor.
 * [OUTPUT]: Provides SkillsGo tokens and reusable branded backgrounds, controls, Hub-image-backed discovery cards, anchored installation actions, status elements, and viewport-safe empty states.
 * [POS]: Serves as the thin Burrow-inspired presentation layer composed from native Flutter Material behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'install_location_popover.dart';
import 'native_components.dart';

ThemeData buildSkillsTheme(
  Color seed, {
  Brightness brightness = Brightness.dark,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return ThemeData.from(colorScheme: scheme, useMaterial3: true).copyWith(
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: SkillsTokens.sansFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    scaffoldBackgroundColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
  );
}

abstract final class SkillsTokens {
  static const nearBlack = Color(0xFF0B0B0D);
  static const warmBlack = Color(0xFF17130F);
  static const cream = Color(0xFFF3ECDD);
  static const espresso = Color(0xFF241B12);
  static const green = Color(0xFF57D58E);
  static const teal = Color(0xFF35C2A5);
  static const violet = Color(0xFF8E84F0);
  static const gold = Color(0xFFE6A93C);
  static const amber = Color(0xFFF0B24A);
  static const orange = Color(0xFFF2894E);
  static const blue = Color(0xFF5AA8F0);
  static const red = Color(0xFFF0604E);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0x9EFFFFFF);
  static const textTertiary = Color(0x66FFFFFF);
  static const hairline = Color(0x16FFFFFF);
  static const card = Color(0x0EFFFFFF);
  static const cardHover = Color(0x1AFFFFFF);
  static const sansFamily = '.AppleSystemUIFont';
  static const monoFamily = 'SF Mono';
  static const serifFamily = 'New York';
}

class SkillsBackground extends StatelessWidget {
  const SkillsBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);
}

extension SkillsColorRoles on ColorScheme {
  Color get textPrimary => onSurface;
  Color get textSecondary => onSurfaceVariant;
  Color get textTertiary => onSurfaceVariant.withValues(alpha: .72);
  Color get hairline => outlineVariant;
  Color get card => surfaceContainerLow;
  Color get cardHover => surfaceContainer;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: SkillsTokens.monoFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: SkillsTokens.monoFamily,
          fontSize: 10,
          color: resolvedColor,
        ),
      ),
    );
  }
}

class SkillTrustChip extends StatelessWidget {
  const SkillTrustChip({super.key, required this.trust});
  final SkillTrustLevel trust;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: _trustLabel(context, trust), color: _trustColor(trust));
}

class SkillRiskChip extends StatelessWidget {
  const SkillRiskChip({super.key, required this.risk});
  final SkillRiskAssessment risk;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: _riskLabel(context, risk), color: _riskColor(risk));
}

class SecondaryCapsuleButton extends StatelessWidget {
  const SecondaryCapsuleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      label: Text(label),
    );
  }
}

class SkillSearchField extends StatelessWidget {
  const SkillSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.onCleared,
    this.onChanged,
    this.active = false,
    this.loading = false,
    this.compact = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onCleared;
  final ValueChanged<String>? onChanged;
  final bool active;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.searchSkills,
      textField: true,
      child: SizedBox(
        key: const Key('skill-search'),
        height: compact ? 44 : 52,
        child: AnimatedBuilder(
          animation: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final value = controller.value;
            final foreground = active
                ? scheme.onPrimaryContainer
                : scheme.onSurface;
            final secondary = active
                ? scheme.onPrimaryContainer.withValues(alpha: .72)
                : scheme.onSurfaceVariant;
            final radius = BorderRadius.circular(999);
            final border = OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: active ? Colors.transparent : scheme.outlineVariant,
              ),
            );
            return AnimatedContainer(
              key: const Key('skill-search-surface'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0x29000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : const [],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                cursorColor: foreground,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 14 : 17,
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: active
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  hintText: l10n.searchSkills,
                  hintStyle: TextStyle(
                    color: scheme.textTertiary,
                    fontWeight: FontWeight.w300,
                  ),
                  prefixIcon: Icon(Icons.search, size: 19, color: secondary),
                  suffixIcon: loading
                      ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: secondary,
                            ),
                          ),
                        )
                      : value.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('skill-search-clear'),
                          tooltip: null,
                          onPressed: () {
                            controller.clear();
                            onCleared?.call();
                            focusNode.requestFocus();
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 17,
                            color: secondary,
                          ),
                        ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: 0,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(
                      color: active ? scheme.primary : scheme.outline,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SkillCard extends StatefulWidget {
  const SkillCard({
    super.key,
    required this.skill,
    required this.onTap,
    required this.onInstall,
    this.focusNode,
  });
  final SkillSummary skill;
  final VoidCallback onTap;
  final ValueChanged<InstallLocationMenuPresenter> onInstall;
  final FocusNode? focusNode;

  @override
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(14);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: hovered ? 1 : 0),
        duration: duration,
        builder: (context, progress, _) {
          final scheme = Theme.of(context).colorScheme;
          return Card(
            margin: EdgeInsets.zero,
            elevation: 4 * progress,
            shadowColor: Colors.black.withValues(alpha: .34),
            surfaceTintColor: Colors.transparent,
            color: Color.lerp(scheme.card, scheme.cardHover, progress),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: radius),
            child: Semantics(
              button: true,
              label: l10n.openSkill(widget.skill.name),
              child: InkWell(
                focusNode: widget.focusNode,
                onTap: widget.onTap,
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RepositoryAvatar(
                            source: widget.skill.source,
                            imageUrl: widget.skill.imageUrl,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.skill.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -.08,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _repositoryLabel(widget.skill.source),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.textTertiary,
                                    fontFamily: SkillsTokens.monoFamily,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Expanded(
                        child: Text(
                          widget.skill.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.textSecondary,
                            fontSize: 13,
                            height: 1.42,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _metricLabel(context, widget.skill),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.textSecondary,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InstallLocationMenuAnchor(
                            builder: (context, present) => PrimaryCapsuleButton(
                              label: l10n.install,
                              height: 28,
                              horizontalPadding: 9,
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                              onPressed: () => widget.onInstall(present),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RepositoryAvatar extends StatefulWidget {
  const RepositoryAvatar({
    super.key,
    required this.source,
    this.imageUrl,
    this.size = 36,
    this.borderRadius = 8,
  });
  final String source;
  final String? imageUrl;
  final double size;
  final double borderRadius;

  @override
  State<RepositoryAvatar> createState() => _RepositoryAvatarState();
}

class _RepositoryAvatarState extends State<RepositoryAvatar> {
  bool imageFailed = false;

  @override
  void didUpdateWidget(covariant RepositoryAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.imageUrl != widget.imageUrl) {
      imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = imageFailed ? null : widget.imageUrl;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: imageUrl == null
          ? _RepositoryAvatarFallback(source: widget.source, size: widget.size)
          : Image.network(
              imageUrl,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !imageFailed) {
                    setState(() => imageFailed = true);
                  }
                });
                return _RepositoryAvatarFallback(
                  source: widget.source,
                  size: widget.size,
                );
              },
            ),
    );
  }
}

class _RepositoryAvatarFallback extends StatelessWidget {
  const _RepositoryAvatarFallback({required this.source, required this.size});
  final String source;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    _repositoryOwner(
      source,
    ).substring(0, _repositoryOwner(source).length.clamp(0, 2)).toUpperCase(),
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      fontSize: (size * .34).clamp(12, 32),
    ),
  );
}

String _repositoryLabel(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1 && parts.first.contains('.')) {
    return parts.skip(1).join('/');
  }
  return source;
}

String _repositoryOwner(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length > 1 && parts.first.contains('.')) return parts[1];
  return parts.first;
}

class SkillGlyph extends StatelessWidget {
  const SkillGlyph({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: SkillsTokens.green.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: const TextStyle(
        color: SkillsTokens.green,
        fontWeight: FontWeight.w800,
        fontSize: 17,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title;
  final String message;
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
              style: const TextStyle(
                fontFamily: SkillsTokens.serifFamily,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
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

Color _trustColor(SkillTrustLevel trust) => switch (trust) {
  SkillTrustLevel.unverified => SkillsTokens.textSecondary,
  SkillTrustLevel.communityVerified => SkillsTokens.blue,
  SkillTrustLevel.publisherVerified => SkillsTokens.teal,
  SkillTrustLevel.official => SkillsTokens.green,
  SkillTrustLevel.warned => SkillsTokens.amber,
  SkillTrustLevel.delisted => SkillsTokens.red,
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

Color _riskColor(SkillRiskAssessment risk) => switch (risk) {
  SkillRiskAssessment.unknown => SkillsTokens.textSecondary,
  SkillRiskAssessment.low => SkillsTokens.green,
  SkillRiskAssessment.medium => SkillsTokens.amber,
  SkillRiskAssessment.high => SkillsTokens.orange,
  SkillRiskAssessment.critical => SkillsTokens.red,
};
