/*
 * [INPUT]: Depends on SkillsGateway discovery models, localized copy, shadcn_ui primitives, and Flutter rendering.
 * [OUTPUT]: Provides SkillsGo tokens and reusable branded backgrounds, controls, discovery cards, status elements, and empty states.
 * [POS]: Serves as the thin Burrow-inspired presentation layer composed around shared shadcn_ui behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';

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
  const SkillsBackground({
    super.key,
    required this.child,
    this.tint = SkillsTokens.warmBlack,
  });
  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint, SkillsTokens.nearBlack],
            ),
          ),
        ),
        child,
      ],
    );
  }
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
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF171513),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SkillsTokens.hairline),
    ),
    child: child,
  );
}

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(
    this.text, {
    super.key,
    this.color = SkillsTokens.textSecondary,
  });
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: SkillsTokens.monoFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: color,
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color = SkillsTokens.textSecondary,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: SkillsTokens.monoFamily,
        fontSize: 10,
        color: color,
      ),
    ),
  );
}

class PrimaryCapsuleButton extends StatelessWidget {
  const PrimaryCapsuleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => ShadButton(
    enabled: !busy && onPressed != null,
    onPressed: onPressed,
    backgroundColor: Colors.white,
    hoverBackgroundColor: const Color(0xFFF1F1EF),
    pressedBackgroundColor: const Color(0xFFE5E5E2),
    foregroundColor: Colors.black,
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const ShadDecoration(
      shape: BoxShape.rectangle,
      border: ShadBorder(radius: BorderRadius.all(Radius.circular(999))),
    ),
    child: busy
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
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
  Widget build(BuildContext context) => ShadButton.outline(
    enabled: onPressed != null,
    onPressed: onPressed,
    leading: icon == null ? null : Icon(icon, size: 16),
    foregroundColor: SkillsTokens.textPrimary,
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: ShadDecoration(
      shape: BoxShape.rectangle,
      border: ShadBorder.all(
        color: SkillsTokens.hairline,
        radius: const BorderRadius.all(Radius.circular(999)),
      ),
    ),
    child: Text(label),
  );
}

class SkillSearchField extends StatelessWidget {
  const SkillSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ShadInput(
      key: const Key('skill-search'),
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: SkillsTokens.textPrimary, fontSize: 17),
      placeholder: Text(l10n.searchSkills),
      placeholderStyle: const TextStyle(color: SkillsTokens.textTertiary),
      leading: const Icon(Icons.search, color: SkillsTokens.textSecondary),
      trailing: ShadTooltip(
        builder: (_) => Text(l10n.search),
        child: ShadButton.ghost(
          width: 36,
          height: 36,
          padding: EdgeInsets.zero,
          onPressed: () => onSubmitted(controller.text),
          child: const Icon(
            Icons.arrow_forward,
            color: SkillsTokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class SkillCard extends StatefulWidget {
  const SkillCard({super.key, required this.skill, required this.onTap});
  final SkillSummary skill;
  final VoidCallback onTap;

  @override
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: Semantics(
      button: true,
      label: AppLocalizations.of(context).openSkill(widget.skill.name),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: hovered ? SkillsTokens.cardHover : SkillsTokens.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hovered ? Colors.white24 : SkillsTokens.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkillGlyph(name: widget.skill.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.skill.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.skill.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SkillsTokens.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.skill.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SkillsTokens.textTertiary,
                        fontFamily: SkillsTokens.monoFamily,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        StatusChip(
                          label: _trustLabel(context, widget.skill.trustLevel),
                          color: _trustColor(widget.skill.trustLevel),
                        ),
                        StatusChip(
                          label: _riskLabel(
                            context,
                            widget.skill.riskAssessment,
                          ),
                          color: _riskColor(widget.skill.riskAssessment),
                        ),
                        StatusChip(
                          label: AppLocalizations.of(
                            context,
                          ).localTargets(widget.skill.localTargetCount),
                          color: widget.skill.isInstalled
                              ? SkillsTokens.green
                              : SkillsTokens.textTertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.skill.latestVersion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: SkillsTokens.monoFamily,
                        fontSize: 11,
                        color: SkillsTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _metricLabel(context, widget.skill),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: SkillsTokens.monoFamily,
                        color: SkillsTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.skill.isInstalled
                          ? AppLocalizations.of(context).installToMoreTargets
                          : AppLocalizations.of(context).install,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: SkillsTokens.cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: SkillsTokens.textTertiary),
            ],
          ),
        ),
      ),
    ),
  );
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
            style: const TextStyle(
              color: SkillsTokens.textSecondary,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
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
