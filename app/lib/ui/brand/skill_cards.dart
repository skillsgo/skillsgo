/*
 * [INPUT]: Depends on Skill discovery summaries, installation presenters, repository identity, trust/risk chips, hover state, and localized copy.
 * [OUTPUT]: Provides interactive Skill cards, repository avatars with optional caller-fixed fallback colors, and repository identity formatting.
 * [POS]: Serves as the discovery-card segment of the SkillsGo brand library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../brand.dart';

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
    final installed = widget.skill.localTargetCount > 0;
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
                                  style: context.skillsTypography.body.copyWith(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -.08,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _repositoryLabel(widget.skill.source),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.skillsTypography.caption
                                      .copyWith(color: scheme.textTertiary),
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
                          style: context.skillsTypography.bodySecondary
                              .copyWith(
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
                              style: context.skillsTypography.metadata.copyWith(
                                color: scheme.textSecondary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InstallLocationMenuAnchor(
                            builder: (context, present) => PrimaryCapsuleButton(
                              label: installed
                                  ? l10n.installedCell
                                  : l10n.install,
                              height: 28,
                              horizontalPadding: 9,
                              labelStyle: context.skillsTypography.metadata,
                              onPressed: installed
                                  ? null
                                  : () => widget.onInstall(present),
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
    this.backgroundColor,
    this.fallbackForegroundColor,
  });
  final String source;
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? fallbackForegroundColor;

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
        color:
            widget.backgroundColor ??
            (imageUrl == null
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: imageUrl == null
          ? _RepositoryAvatarFallback(
              source: widget.source,
              size: widget.size,
              foregroundColor: widget.fallbackForegroundColor,
            )
          : Image.network(
              imageUrl,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : _RepositoryAvatarFallback(
                      source: widget.source,
                      size: widget.size,
                      foregroundColor: widget.fallbackForegroundColor,
                    ),
              errorBuilder: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !imageFailed) {
                    setState(() => imageFailed = true);
                  }
                });
                return _RepositoryAvatarFallback(
                  source: widget.source,
                  size: widget.size,
                  foregroundColor: widget.fallbackForegroundColor,
                );
              },
            ),
    );
  }
}

class _RepositoryAvatarFallback extends StatelessWidget {
  const _RepositoryAvatarFallback({
    required this.source,
    required this.size,
    this.foregroundColor,
  });
  final String source;
  final double size;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) => Text(
    _repositoryOwner(
      source,
    ).substring(0, _repositoryOwner(source).length.clamp(0, 2)).toUpperCase(),
    style: TextStyle(
      color:
          foregroundColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
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
