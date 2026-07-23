/*
 * [INPUT]: Depends on LocalDetailScreen state, shared detail primitives, InstallationScopePanel, localized action controls, and Markdown presentation.
 * [OUTPUT]: Provides local detail action bar, toolbar, artifact context, installation scope, operation feedback, and document rendering.
 * [POS]: Serves as the private rendering implementation of the local Skill detail journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

extension _LocalDetailRendering on _LocalDetailScreenState {
  Widget _actions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (skill.provenance == LibraryProvenance.external) ...[
        SecondaryCapsuleButton(
          label: context.l10n.remove,
          icon: HugeIcons.strokeRoundedDelete02,
          onPressed: managing ? null : manage,
        ),
      ] else ...[
        if (skill.provenance == LibraryProvenance.hub &&
            updateState == UpdateState.available) ...[
          SecondaryCapsuleButton(
            label: context.l10n.update,
            icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
            onPressed: updating || managing ? null : update,
          ),
          const SizedBox(width: 8),
        ],
        if (detail?.immutableVersion.isNotEmpty ?? false) ...[
          InstallLocationMenuAnchor(
            builder: (context, present) => PrimaryCapsuleButton(
              label: context.l10n.installMoreTargets,
              height: 40,
              horizontalPadding: 18,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              onPressed: installingMore || managing || updating
                  ? null
                  : () => installMore(present),
              busy: installingMore,
            ),
          ),
        ],
      ],
    ],
  );

  Widget _detailToolbar() {
    final scheme = Theme.of(context).colorScheme;
    final offset = detailScrollController.hasClients
        ? detailScrollController.offset
        : 0.0;
    final materialProgress = ((offset - 12) / 52).clamp(0.0, 1.0);
    final compactProgress = ((offset - 72) / 56).clamp(0.0, 1.0);
    final source =
        remoteIdentity?.source ??
        (skill.repositoryId.isNotEmpty ? skill.repositoryId : skill.name);
    return SizedBox(
      key: const Key('installed-detail-sticky-toolbar'),
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, .04, .96, 1],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0, .16, .68, 1],
                ).createShader(bounds),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 22 * materialProgress,
                    sigmaY: 22 * materialProgress,
                  ),
                  child: ColoredBox(
                    color: scheme.surface.withValues(
                      alpha: .62 * materialProgress,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Semantics(
                  label: context.l10n.backToLibrary,
                  button: true,
                  child: Material(
                    color: scheme.surfaceContainerHigh.withValues(alpha: .82),
                    elevation: 3,
                    shadowColor: scheme.shadow.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      key: const Key('installed-detail-back'),
                      tooltip: context.l10n.backToLibrary,
                      onPressed: widget.onBack,
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        fixedSize: const Size.square(40),
                        minimumSize: const Size.square(40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Transform.flip(
                        flipX: Directionality.of(context) == TextDirection.rtl,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedLessThan,
                          size: 20,
                          strokeWidth: 1.8,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (compactProgress > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      key: const Key('installed-detail-compact-identity'),
                      opacity: compactProgress,
                      child: IgnorePointer(
                        ignoring: compactProgress < .95,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RepositoryAvatar(
                              source: source,
                              imageUrl: remoteIdentity?.imageUrl,
                              size: 26,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                skill.name,
                                textDirection: contentTextDirection(skill.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (compactProgress > 0)
                  Opacity(
                    key: const Key('installed-detail-compact-actions'),
                    opacity: compactProgress,
                    child: IgnorePointer(
                      ignoring: compactProgress < .95,
                      child: _actions(),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
