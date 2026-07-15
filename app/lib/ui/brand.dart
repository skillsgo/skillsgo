import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        disabledBackgroundColor: Colors.white24,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
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
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: SkillsTokens.textPrimary,
      side: const BorderSide(color: SkillsTokens.hairline),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
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
    return TextField(
      key: const Key('skill-search'),
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: SkillsTokens.textPrimary, fontSize: 17),
      decoration: InputDecoration(
        hintText: l10n.searchSkills,
        hintStyle: const TextStyle(color: SkillsTokens.textTertiary),
        prefixIcon: const Icon(Icons.search, color: SkillsTokens.textSecondary),
        suffixIcon: IconButton(
          tooltip: l10n.search,
          onPressed: () => onSubmitted(controller.text),
          icon: const Icon(
            Icons.arrow_forward,
            color: SkillsTokens.textPrimary,
          ),
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: .24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: SkillsTokens.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: SkillsTokens.cream, width: 1.5),
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
                    const SizedBox(height: 5),
                    Text(
                      widget.skill.source,
                      style: const TextStyle(color: SkillsTokens.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                _formatInstalls(context, widget.skill.installs),
                style: const TextStyle(
                  fontFamily: SkillsTokens.monoFamily,
                  color: SkillsTokens.textTertiary,
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

String _formatInstalls(BuildContext context, int installs) {
  final l10n = AppLocalizations.of(context);
  if (installs >= 1000000) {
    return l10n.installs('${(installs / 1000000).toStringAsFixed(1)}M');
  }
  if (installs >= 1000) {
    return l10n.installs('${(installs / 1000).toStringAsFixed(1)}K');
  }
  return l10n.installs('$installs');
}
