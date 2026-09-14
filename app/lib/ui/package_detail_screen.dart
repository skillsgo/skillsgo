/*
 * [INPUT]: Depends on SkillsGateway Package detail and CDN README reads, the shared Package summary card, Markdown, native loading primitives, and optional Package actions.
 * [OUTPUT]: Provides a Package-centered detail surface with the shared floating detail toolbar, one reusable Package card, and independently loaded immutable README navigation.
 * [POS]: Serves as the reusable Package detail journey entered from Discover Package context.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/skills_gateway.dart';
import 'install_location_popover.dart';
import 'native_components.dart';
import 'package_summary_card.dart';
import 'skill_markdown_view.dart';
import 'ui_support.dart';

class PackageDetailScreen extends StatefulWidget {
  const PackageDetailScreen({
    super.key,
    required this.gateway,
    required this.packagePath,
    this.version = '',
    this.summary,
    this.onBack,
    this.onInstallAll,
  });

  final SkillsGateway gateway;
  final String packagePath;
  final String version;
  final PackageSummary? summary;
  final VoidCallback? onBack;
  final void Function(
    InstallLocationMenuPresenter presenter,
    SkillSummary anchorSkill,
  )?
  onInstallAll;

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  PackageDetail? _detail;
  Object? _detailError;
  String? _readme;
  Object? _readmeError;
  Uri? _documentUri;
  bool _refreshing = false;
  Object? _refreshError;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollChanged);
    unawaited(_load());
  }

  void _scrollChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scrollChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveContent = false}) async {
    setState(() {
      _detailError = null;
      _refreshError = null;
      _refreshing = preserveContent;
      if (!preserveContent) _detail = null;
    });
    try {
      final detail = await widget.gateway.loadPackageDetail(
        widget.packagePath,
        version: widget.version,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
      final readmeUrl = detail.readmeUrl;
      if (readmeUrl != null) {
        await _loadDocument(readmeUrl, preserveContent: preserveContent);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          if (_detail == null) {
            _detailError = error;
          } else {
            _refreshError = error;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadDocument(Uri uri, {bool preserveContent = false}) async {
    final requestUri = uri.removeFragment();
    setState(() {
      _documentUri = requestUri;
      if (!preserveContent) _readme = null;
      _readmeError = null;
    });
    try {
      final value = await widget.gateway.loadPackageReadme(requestUri);
      if (mounted && _documentUri == requestUri) {
        setState(() => _readme = value);
      }
    } on Object catch (error) {
      if (mounted && _documentUri == requestUri) {
        setState(() {
          if (preserveContent && _readme != null) {
            _refreshError = error;
          } else {
            _readmeError = error;
          }
        });
      }
    }
  }

  Future<void> _openDocumentLink(Uri uri) async {
    final root = _detail?.readmeUrl;
    final rootDirectory = root?.resolve('.');
    if (root != null &&
        rootDirectory != null &&
        uri.scheme == 'https' &&
        uri.host == root.host &&
        uri.path.startsWith(rootDirectory.path) &&
        uri.path.toLowerCase().endsWith('.md')) {
      if (_documentUri?.replace(fragment: '') == uri.replace(fragment: '')) {
        return;
      }
      await _loadDocument(uri);
      return;
    }
    if (const {'https', 'http', 'mailto'}.contains(uri.scheme)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Material(
      key: const Key('package-detail-surface'),
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomScrollView(
              key: const Key('package-detail-scroll'),
              controller: _scrollController,
              slivers: [
                if (_refreshing)
                  SliverToBoxAdapter(
                    child: SkillsProgress(
                      key: const Key('package-detail-refreshing'),
                      minHeight: 2,
                      semanticsLabel: context.l10n.loading,
                    ),
                  ),
                if (_refreshError != null && detail != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 76, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        key: const Key('package-detail-refresh-error'),
                        children: [
                          Expanded(
                            child: Text(
                              failureCopy(context, _refreshError!).message,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _load(preserveContent: true),
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_detailError != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(failureCopy(context, _detailError!).message),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('package-detail-retry'),
                            onPressed: _load,
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (detail == null)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(28, 76, 28, 28),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SkillsSkeletonBox(height: 116, borderRadius: 18),
                          SizedBox(height: 24),
                          SkillsSkeletonBox(height: 220, borderRadius: 18),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      _refreshError == null ? 76 : 24,
                      28,
                      16,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PackageSummaryCard(
                        packagePath: detail.packagePath,
                        skills: detail.skills,
                        summary: detail.summary ?? widget.summary,
                        onUpdated: () => _load(preserveContent: true),
                        onInstallAll:
                            widget.onInstallAll == null || detail.skills.isEmpty
                            ? null
                            : (presenter) => widget.onInstallAll!(
                                presenter,
                                detail.skills.first,
                              ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
                    sliver: SliverToBoxAdapter(child: _readmeRegion(detail)),
                  ),
                ],
              ],
            ),
            Align(alignment: Alignment.topCenter, child: _detailToolbar()),
          ],
        ),
      ),
    );
  }

  Widget _detailToolbar() {
    final scheme = Theme.of(context).colorScheme;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0;
    final materialProgress = ((offset - 12) / 52).clamp(0.0, 1.0);
    return SizedBox(
      key: const Key('package-detail-sticky-toolbar'),
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
                      key: const Key('package-detail-back'),
                      onPressed:
                          widget.onBack ?? () => Navigator.maybePop(context),
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
                const Spacer(),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readmeRegion(PackageDetail detail) {
    if (detail.readmeUrl == null) {
      return const SizedBox.shrink(key: Key('package-readme-empty'));
    }
    if (_readmeError != null) {
      return Column(
        key: const Key('package-readme-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(failureCopy(context, _readmeError!).message),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _loadDocument(_documentUri ?? detail.readmeUrl!),
            child: Text(context.l10n.retry),
          ),
        ],
      );
    }
    if (_readme == null) {
      return const SkillsSkeletonBox(
        key: Key('package-readme-loading'),
        height: 220,
        borderRadius: 18,
      );
    }
    if (_readme!.trim().isEmpty) {
      return const SizedBox.shrink(key: Key('package-readme-empty'));
    }
    return SkillMarkdownView(
      key: const Key('package-readme-content'),
      data: _readme!,
      documentUri: _documentUri,
      resourceRootUri: detail.readmeUrl?.resolve('.'),
      onTapLink: _openDocumentLink,
      scrollable: false,
    );
  }
}
