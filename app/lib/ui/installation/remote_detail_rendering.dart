/*
 * [INPUT]: Depends on RemoteDetailScreen state, localized copy, audit models, installation scope widgets, and Markdown presentation.
 * [OUTPUT]: Provides remote detail toolbar, loading/error/content regions, artifact metadata, and document rendering methods.
 * [POS]: Serves as the private rendering implementation of the remote Skill detail journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../installation_flows.dart';

extension _RemoteDetailRendering on RemoteDetailScreenState {
  Widget _detailToolbar() {
    final scheme = Theme.of(context).colorScheme;
    final offset = detailScrollController.hasClients
        ? detailScrollController.offset
        : 0.0;
    final materialProgress = ((offset - 12) / 52).clamp(0.0, 1.0);
    final compactProgress = ((offset - 72) / 56).clamp(0.0, 1.0);
    final value = detail;
    return SizedBox(
      key: const Key('detail-sticky-toolbar'),
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
                  label: context.l10n.backToSearch,
                  button: true,
                  child: Material(
                    color: scheme.surfaceContainerHigh.withValues(alpha: .82),
                    elevation: 3,
                    shadowColor: scheme.shadow.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      key: const Key('detail-back'),
                      onPressed: () => widget.onBack(
                        installed: execution?.hasSuccess == true,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        fixedSize: const Size.square(40),
                        minimumSize: const Size.square(40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedLessThan,
                        size: 20,
                        strokeWidth: 1.8,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (value != null && compactProgress > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      key: const Key('detail-compact-identity'),
                      opacity: compactProgress,
                      child: IgnorePointer(
                        ignoring: compactProgress < .95,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RepositoryAvatar(
                              source: value.source,
                              imageUrl: value.imageUrl,
                              size: 26,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                value.name,
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
                if (value != null && compactProgress > 0)
                  Opacity(
                    key: const Key('detail-compact-install'),
                    opacity: compactProgress,
                    child: IgnorePointer(
                      ignoring: compactProgress < .95,
                      child: InstallLocationMenuAnchor(
                        builder: (context, present) => PrimaryCapsuleButton(
                          label: _installActionLabel(value),
                          height: 36,
                          horizontalPadding: 16,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w400,
                          ),
                          onPressed: () => install(present),
                          busy: operating || loadingCatalog,
                        ),
                      ),
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

  Widget _content() {
    if (loading) {
      return _detailSkeleton();
    }
    if (error != null) {
      final copy = failureCopy(context, error!, detail: true);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: SkillsButton(onPressed: load, child: Text(context.l10n.retry)),
      );
    }
    return _detailBody();
  }

  Widget _detailSkeleton() => Semantics(
    liveRegion: true,
    label: context.l10n.detailLoading,
    child: SingleChildScrollView(
      key: const ValueKey('detail-skeleton'),
      padding: const EdgeInsets.only(top: 76, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepositoryAvatar(
                source: widget.skill.source,
                imageUrl: widget.skill.imageUrl,
                size: 116,
                borderRadius: 24,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.skill.source,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SkillsSkeletonBox(height: 12, width: 280),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const SkillsSkeletonBox(height: 18, width: 190),
          const SizedBox(height: 16),
          const SkillsSkeletonBox(height: 13),
          const SizedBox(height: 10),
          const SkillsSkeletonBox(height: 13),
          const SizedBox(height: 10),
          const SkillsSkeletonBox(height: 13, width: 520),
          const SizedBox(height: 28),
          const SkillsSkeletonBox(height: 220, borderRadius: 14),
        ],
      ),
    ),
  );

  Widget _detailBody() {
    final value = detail!;
    return SkillDetailPageBody(
      scrollKey: const Key('detail-scroll-view'),
      controller: detailScrollController,
      hero: SkillDetailHero(
        name: value.name,
        source: value.source,
        description: value.description,
        imageUrl: value.imageUrl,
        avatarKey: const Key('detail-skill-avatar'),
        descriptionKey: const Key('detail-description-markdown'),
        actions: InstallLocationMenuAnchor(
          builder: (context, present) => PrimaryCapsuleButton(
            key: const Key('detail-hero-install'),
            label: _installActionLabel(value),
            height: 40,
            horizontalPadding: 18,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            onPressed: () => install(present),
            busy: operating || loadingCatalog,
          ),
        ),
      ),
      contextArea: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailProductMetadata(value),
          if (value.installationTargets.isNotEmpty) ...[
            _skillDetailDivider(context),
            InstallationScopePanel(
              targets: value.installationTargets,
              projects: addedProjects,
              onManageTarget: manageTargetInline,
            ),
          ],
          if (widget.operation.error != null) ...[
            const SizedBox(height: 14),
            _PlanError(error: widget.operation.error!),
          ],
          if (execution != null) ...[
            const SizedBox(height: 14),
            _InstallationCompletionBanner(execution: execution!),
          ],
        ],
      ),
      document: SkillMarkdownView(
        key: const Key('detail-instructions'),
        data: value.markdown,
        scrollable: false,
        stripFrontMatter: true,
      ),
    );
  }

  String _installActionLabel(SkillDetail value) =>
      value.installationTargets.isNotEmpty || execution?.hasSuccess == true
      ? context.l10n.installMoreTargets
      : context.l10n.install;

  Widget _detailProductMetadata(SkillDetail value) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        label: context.l10n.detailRepository,
        value: _repositoryDisplayName(
          value.repository.isEmpty ? value.source : value.repository,
        ),
      ),
      (label: context.l10n.detailStars, value: _compactCount(value.stars)),
      (
        label: context.l10n.detailInstalls,
        value: _compactCount(value.installs),
      ),
      (
        label: context.l10n.detailUpdated,
        value: _shortDate(value.sourceUpdatedAt),
      ),
      (
        label: context.l10n.detailArchiveSize,
        value: _fileSize(value.archiveSize),
      ),
    ];
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              SizedBox(
                height: 48,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: .55),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          items[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.skillsTypography.metadata.copyWith(
                            height: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 24,
                      width: double.infinity,
                      child: Center(
                        child: Tooltip(
                          message: index == 0 ? items[index].value : '',
                          child: Text(
                            items[index].value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: context.skillsTypography.bodySecondary
                                .copyWith(
                                  fontSize: switch (index) {
                                    0 => 12,
                                    3 => 15,
                                    _ => 16,
                                  },
                                  height: 1,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _repositoryDisplayName(String repository) {
    final firstSeparator = repository.indexOf('/');
    if (firstSeparator <= 0) {
      return repository;
    }
    final firstSegment = repository.substring(0, firstSeparator);
    return firstSegment.contains('.')
        ? repository.substring(firstSeparator + 1)
        : repository;
  }

  String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _shortDate(DateTime? value) {
    if (value == null || value.year <= 1) return '—';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _fileSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(bytes >= 10240 ? 0 : 1)} KB';
  }
}
