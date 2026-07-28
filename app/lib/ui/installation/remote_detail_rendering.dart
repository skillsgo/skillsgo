/*
 * [INPUT]: Depends on RemoteDetailScreen state, localized copy, audit models, installation scope widgets, and Markdown presentation.
 * [OUTPUT]: Provides remote detail toolbar, loading/error/content regions, X-inspired inline translation state, artifact metadata, and document rendering methods.
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
                            PackageAvatar(
                              source: value.packagePath,
                              imageUrl: widget.skill.imageUrl,
                              size: 26,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                value.name,
                                textDirection: contentTextDirection(value.name),
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
                          label: context.l10n.install,
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
              PackageAvatar(
                source: widget.skill.packagePath,
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
                        textDirection: contentTextDirection(widget.skill.name),
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
                        widget.skill.packagePath,
                        textDirection: contentTextDirection(
                          widget.skill.packagePath,
                        ),
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
        source: value.packagePath,
        description: value.description,
        imageUrl: widget.skill.imageUrl,
        avatarKey: const Key('detail-skill-avatar'),
        descriptionKey: const Key('detail-description-markdown'),
        titleContext: _translationState(),
        actions: InstallLocationMenuAnchor(
          builder: (context, present) => PrimaryCapsuleButton(
            key: const Key('detail-hero-install'),
            label: context.l10n.install,
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
        data: value.content,
        scrollable: false,
        stripFrontMatter: true,
      ),
    );
  }

  Widget _translationState() {
    final scheme = Theme.of(context).colorScheme;
    final translationAvailable =
        showingSource ||
        detail?.translated == true ||
        localizedDetail?.translated == true;
    if (!translationAvailable) return const SizedBox.shrink();
    return Semantics(
      key: const Key('detail-language-source-switch'),
      button: true,
      label: showingSource
          ? context.l10n.showTranslation
          : context.l10n.showOriginalContent,
      child: InkWell(
        onTap: switchingSource ? null : () => showSource(!showingSource),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTranslation,
                size: 17,
                strokeWidth: 1.7,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              if (!showingSource) ...[
                Text(
                  _translatedStatusLabel(detail?.sourceLanguage ?? ''),
                  style: context.skillsTypography.metadata.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: switchingSource
                    ? SizedBox.square(
                        key: const ValueKey('translation-switch-progress'),
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: scheme.primary,
                        ),
                      )
                    : Text(
                        showingSource
                            ? context.l10n.showTranslation
                            : context.l10n.showOriginalContent,
                        key: ValueKey(showingSource),
                        style: context.skillsTypography.metadata.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLanguageLabel(String tag) {
    final normalized = tag.trim().replaceAll('_', '-').toLowerCase();
    final code = switch (normalized) {
      _ when normalized.startsWith('zh-hans') => 'zhHans',
      _ when normalized.startsWith('zh-hant') => 'zhHant',
      _ => normalized.split('-').first,
    };
    return context.l10n.sourceLanguageName(code);
  }

  String _translatedStatusLabel(String tag) {
    if (tag.trim().isEmpty) return context.l10n.translatedContent;
    return context.l10n.translatedFrom(_sourceLanguageLabel(tag));
  }

  Widget _detailProductMetadata(SkillDetail value) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        label: context.l10n.detailPackageSource,
        value: _packageDisplayName(value.packagePath),
      ),
      (label: context.l10n.detailUpdated, value: _shortDate(value.time)),
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

  String _packageDisplayName(String packagePath) {
    final firstSeparator = packagePath.indexOf('/');
    if (firstSeparator <= 0) {
      return packagePath;
    }
    final firstSegment = packagePath.substring(0, firstSeparator);
    return firstSegment.contains('.')
        ? packagePath.substring(firstSeparator + 1)
        : packagePath;
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
