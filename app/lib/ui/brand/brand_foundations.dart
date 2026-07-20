/*
 * [INPUT]: Depends on SkillsGo design tokens, App wallpaper assets, Loading Animation Widget, and Flutter Material primitives.
 * [OUTPUT]: Provides backgrounds, wallpaper asset mapping, semantic ColorScheme roles, content frames, editorial titles, loading shapes, cards, status chips, trust/risk chips, capsule buttons, and search icon primitives.
 * [POS]: Serves as the visual foundation segment of the SkillsGo brand library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../brand.dart';

class SkillsBackground extends StatelessWidget {
  const SkillsBackground({
    super.key,
    required this.wallpaper,
    required this.child,
  });
  final AppWallpaper wallpaper;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        key: const Key('app-wallpaper'),
        wallpaper.assetPath,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      ),
      child,
    ],
  );
}

extension AppWallpaperAsset on AppWallpaper {
  String get assetPath =>
      'assets/backgrounds/${this == AppWallpaper.sun ? 'solar' : name}-starfield.png';
}

extension SkillsColorRoles on ColorScheme {
  Color get textPrimary => onSurface;
  Color get textSecondary => onSurfaceVariant;
  Color get textTertiary => onSurfaceVariant.withValues(alpha: .72);
  Color get hairline => outlineVariant;
  Color get card => surfaceContainerLow;
  Color get cardHover => surfaceContainer;
}

class SkillsContentFrame extends StatelessWidget {
  const SkillsContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1152),
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}

class SkillsEditorialTitle extends StatelessWidget {
  const SkillsEditorialTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.skillsTypography.pageTitle);
}

enum SkillsLoadingVariant { inkDrop, progressiveDots }

class SkillsLoadingShape extends StatelessWidget {
  const SkillsLoadingShape({
    super.key,
    this.size = 32,
    this.color,
    this.progress,
    this.variant = SkillsLoadingVariant.inkDrop,
  });

  final double size;
  final Color? color;
  final double? progress;
  final SkillsLoadingVariant variant;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = !reduceMotion;
    final indicatorColor = color ?? Theme.of(context).colorScheme.primary;
    return TickerMode(
      enabled: animate,
      child: switch (variant) {
        SkillsLoadingVariant.inkDrop => LoadingAnimationWidget.inkDrop(
          key: const Key('skills-loading-ink-drop'),
          color: indicatorColor,
          size: size,
        ),
        SkillsLoadingVariant.progressiveDots =>
          LoadingAnimationWidget.progressiveDots(
            key: const Key('skills-loading-progressive-dots'),
            color: indicatorColor,
            size: size,
          ),
      },
    );
  }
}

class SkillsRepositoryLoadingShape extends StatelessWidget {
  const SkillsRepositoryLoadingShape({super.key, this.size = 56, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TickerMode(
      enabled: !reduceMotion,
      child: portal.LoadingShapes(
        key: const Key('portal-repository-loading-shape'),
        isLoading: !reduceMotion,
        style: portal.LoadingShapesStyle(
          size: size,
          color: color ?? Theme.of(context).colorScheme.primary,
          transitionDuration: const Duration(milliseconds: 800),
          baseRotationSpeed: 0.007,
          boostRotationSpeed: 0.02,
          enableHaptics: false,
          pauseDuration: const Duration(milliseconds: 160),
        ),
      ),
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
    style: context.skillsTypography.caption.copyWith(
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
    final components = context.skillsComponents;
    final containerColor = switch (resolvedColor) {
      final value when value == components.statusAccent =>
        components.statusAccentContainer,
      final value when value == components.statusSuccess =>
        components.statusSuccessContainer,
      final value when value == components.statusAttention =>
        components.statusAttentionContainer,
      final value when value == components.statusSevere =>
        components.statusSevereContainer,
      final value when value == components.statusDanger =>
        components.statusDangerContainer,
      _ => resolvedColor.withValues(alpha: .14),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.skillsTypography.caption.copyWith(
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
  Widget build(BuildContext context) => StatusChip(
    label: _trustLabel(context, trust),
    color: _trustColor(context, trust),
  );
}

class SkillRiskChip extends StatelessWidget {
  const SkillRiskChip({super.key, required this.risk});
  final SkillRiskAssessment risk;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: _riskLabel(context, risk),
    color: _riskColor(context, risk),
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
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : HugeIcon(icon: icon!, size: 16, strokeWidth: 1.8),
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

enum SkillSearchAppearance { capsule, leaderboard }

const skillSearchLeaderboardContentAlignment = .5;

class SearchVisualIcon extends StatelessWidget {
  const SearchVisualIcon({
    super.key,
    required this.color,
    this.sparkles = false,
  });

  final Color color;
  final bool sparkles;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: sparkles
          ? HugeIcons.strokeRoundedSparkles
          : HugeIcons.strokeRoundedSearchArea,
      size: 18,
      strokeWidth: 1.8,
      color: color,
    );
  }
}
