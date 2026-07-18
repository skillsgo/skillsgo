/*
 * [INPUT]: Depends on SkillsGateway discovery models, localized copy, the SkillsGo design-system interface, Flutter Material rendering, HugeIcons, the bundled solar-starfield background asset, native components, and the shared installation MenuAnchor.
 * [OUTPUT]: Exports SkillsGo theme and semantic color interfaces and provides the full-window photographic background behind Folder, typography/status tokens, controls, Hub-image-backed discovery cards, anchored installation actions, status elements, and viewport-safe empty states.
 * [POS]: Serves as the thin branded presentation layer over the SkillsGo design system and native Flutter Material behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'design_system/skills_color_tokens.dart';
import 'design_system/skills_component_tokens.dart';
import 'install_location_popover.dart';
import 'native_components.dart';

export 'design_system/skills_color_tokens.dart';
export 'design_system/skills_component_tokens.dart';
export 'design_system/skills_theme.dart';

abstract final class SkillsTokens {
  static const sansFamily = '.AppleSystemUIFont';
  static const monoFamily = 'SF Mono';
  static const serifFamily = 'New York';
}

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
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: SkillsTokens.monoFamily,
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w200,
    ),
  );
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
    this.showClearButton = true,
    this.height,
    this.appearance = SkillSearchAppearance.capsule,
    this.showShortcutHint = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onCleared;
  final ValueChanged<String>? onChanged;
  final bool active;
  final bool loading;
  final bool compact;
  final bool showClearButton;
  final double? height;
  final SkillSearchAppearance appearance;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.searchSkills,
      textField: true,
      child: SizedBox(
        key: const Key('skill-search'),
        height: height ?? (compact ? 44 : 52),
        child: AnimatedBuilder(
          animation: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final components = context.skillsComponents;
            final value = controller.value;
            if (appearance == SkillSearchAppearance.leaderboard) {
              const contentAlignment = 0.5;
              final showSparkles =
                  value.text.contains(' ') && value.text.trim().length >= 2;
              final reduceMotion = MediaQuery.disableAnimationsOf(context);
              final animationDuration = MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100);
              return AnimatedContainer(
                duration: animationDuration,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: focusNode.hasFocus
                          ? scheme.onSurface
                          : components.controlBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: const TextAlignVertical(
                    y: contentAlignment,
                  ),
                  cursorColor: scheme.onSurface,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontFamily: SkillsTokens.monoFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(bottom: 2),
                    prefixIconConstraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 45,
                    ),
                    prefixIcon: Align(
                      alignment: const Alignment(-1, contentAlignment),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedOpacity(
                            key: const Key('search-visual-icon'),
                            opacity: showSparkles ? 0 : 1,
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: const Cubic(0.4, 0, 0.2, 1),
                            child: SearchVisualIcon(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          AnimatedOpacity(
                            key: const Key('search-sparkles-icon'),
                            opacity: showSparkles ? 1 : 0,
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: const Cubic(0.4, 0, 0.2, 1),
                            child: SearchVisualIcon(
                              color: scheme.onSurfaceVariant,
                              sparkles: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: l10n.searchSkills,
                    hintStyle: TextStyle(
                      color: scheme.textTertiary,
                      fontFamily: SkillsTokens.monoFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    suffixIconConstraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 45,
                    ),
                    suffixIcon: loading
                        ? const Align(
                            alignment: Alignment(0, contentAlignment),
                            child: SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            ),
                          )
                        : value.text.isNotEmpty && showClearButton
                        ? Align(
                            alignment: const Alignment(0, contentAlignment),
                            child: SizedBox.square(
                              dimension: 24,
                              child: IconButton(
                                key: const Key('skill-search-clear'),
                                tooltip: null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                style: ButtonStyle(
                                  minimumSize: const WidgetStatePropertyAll(
                                    Size.zero,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(
                                          WidgetState.pressed,
                                        )) {
                                          return scheme.onSurface.withValues(
                                            alpha: 0.12,
                                          );
                                        }
                                        if (states.contains(
                                          WidgetState.hovered,
                                        )) {
                                          return scheme.onSurface.withValues(
                                            alpha: 0.08,
                                          );
                                        }
                                        return Colors.transparent;
                                      }),
                                  overlayColor: const WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  controller.clear();
                                  onCleared?.call();
                                  focusNode.requestFocus();
                                },
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 16,
                                  strokeWidth: 1.8,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : showShortcutHint
                        ? Align(
                            alignment: const Alignment(0, contentAlignment),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '⌘ F',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontFamily: SkillsTokens.monoFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  height: 1,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }
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
                color: active ? Colors.transparent : components.controlBorder,
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
                      ? components.searchActive
                      : components.searchRest,
                  hintText: l10n.searchSkills,
                  hintStyle: TextStyle(
                    color: scheme.textTertiary,
                    fontWeight: FontWeight.w300,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  prefixIcon: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        size: 17,
                        strokeWidth: 1.5,
                        color: secondary,
                      ),
                    ),
                  ),
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
                      : value.text.isEmpty || !showClearButton
                      ? null
                      : IconButton(
                          key: const Key('skill-search-clear'),
                          tooltip: null,
                          onPressed: () {
                            controller.clear();
                            onCleared?.call();
                            focusNode.requestFocus();
                          },
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 17,
                            strokeWidth: 1.8,
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
                      color: active
                          ? components.focusRing
                          : components.controlBorder,
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
          final components = context.skillsComponents;
          final light = scheme.brightness == Brightness.light;
          final restColor = light
              ? scheme.surfaceContainer
              : components.cardRest;
          final hoverColor = light ? scheme.surfaceDim : components.cardHover;
          return Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            color: Color.lerp(restColor, hoverColor, progress),
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
                          maxLines: 3,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: imageUrl == null
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
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
      color: Theme.of(context).colorScheme.onSecondaryContainer,
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
      color: context.skillsComponents.statusSuccessContainer,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(
        color: context.skillsComponents.statusSuccess,
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

Color _trustColor(
  BuildContext context,
  SkillTrustLevel trust,
) => switch (trust) {
  SkillTrustLevel.unverified => context.skillsColors.foregroundMuted,
  SkillTrustLevel.communityVerified => context.skillsComponents.statusAccent,
  SkillTrustLevel.publisherVerified => context.skillsComponents.statusAccent,
  SkillTrustLevel.official => context.skillsComponents.statusSuccess,
  SkillTrustLevel.warned => context.skillsComponents.statusAttention,
  SkillTrustLevel.delisted => context.skillsComponents.statusDanger,
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

Color _riskColor(BuildContext context, SkillRiskAssessment risk) =>
    switch (risk) {
      SkillRiskAssessment.unknown => context.skillsColors.foregroundMuted,
      SkillRiskAssessment.low => context.skillsComponents.statusSuccess,
      SkillRiskAssessment.medium => context.skillsComponents.statusAttention,
      SkillRiskAssessment.high => context.skillsComponents.statusSevere,
      SkillRiskAssessment.critical => context.skillsComponents.statusDanger,
    };
