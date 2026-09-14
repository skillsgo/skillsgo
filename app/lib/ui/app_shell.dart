/*
 * [INPUT]: Depends on SkillsGateway contracts, the native App updater/feed, path utilities, the first-Library-entry platform-sensitive local-scan privacy notice, Mandatory Onboarding, Riverpod feature state including the Package update coordinator, the App-scoped installation task stack, split feature view parts, localized copy, Flutter rendering direction and spring physics, HugeIcons, multi_dropdown, shared Agent, Added Project, and language identity components, the vendored Portal Labs subscription switch, native Material components, the accessible themeable primary folder, stateful nested navigation, and SkillsGo brand tokens.
 * [OUTPUT]: Provides the lazy project-named Library pre-scan privacy gate, first-launch gate, desktop shell composition with non-blocking bottom-right installation tasks, lifecycle-aware Package update checks, channel-explicit timed App-update dependency routing, cross-destination navigation actions, and shared UI contracts consumed by split Discover, Library, Settings, and mutation-flow views.
 * [POS]: Serves as the primary rendered product surface and translates domain states into accessible localized UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;
import 'native_components.dart';

import '../domain/skills_gateway.dart';
import '../infrastructure/app_updater.dart';
import 'agent_catalog_controller.dart';
import 'appearance_controller.dart';
import 'brand.dart';
import 'discover_controller.dart';
import 'library_controller.dart';
import 'installation_task_stack.dart';
import 'onboarding_screen.dart';
import 'primary_folder_shell.dart';

import 'discover_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'ui_support.dart';
import 'update_check_controller.dart';

enum _Destination { discover, library, settings }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.gateway,
    required this.appUpdater,
    required this.appUpdateSource,
    required this.appUpdateChannel,
    required this.appUpdateInitialDelay,
    required this.appUpdateCheckInterval,
  });

  final SkillsGateway gateway;
  final AppUpdater appUpdater;
  final Uri? appUpdateSource;
  final String? appUpdateChannel;
  final Duration appUpdateInitialDelay;
  final Duration appUpdateCheckInterval;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  VoidCallback? dismissDiscoverDetail;
  _Destination destination = _Destination.discover;
  CliStatus? cliStatus;
  OnboardingState? onboardingState;
  Object? onboardingError;
  LocalScanNoticeDecision? _localScanNoticeDecision;
  bool _localScanNoticeBypassed = false;
  bool _libraryActivated = false;
  bool _localScanNoticeVisible = false;
  bool _checkingLocalScanNoticeRequirement = false;
  Object? _localScanNoticeRequirementError;
  List<String> _localScanNoticePaths = const [];
  bool _refreshLibraryAfterNotice = false;
  bool _savingLocalScanNoticeDecision = false;
  Object? _localScanNoticeError;
  bool _mainShellInitialized = false;
  Timer? _startupUpdateTimer;

  bool get _localScanAccessReady =>
      _localScanNoticeDecision == LocalScanNoticeDecision.accepted ||
      _localScanNoticeBypassed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadOnboarding());
  }

  @override
  void dispose() {
    _startupUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _mainShellInitialized &&
        _libraryActivated &&
        _localScanAccessReady) {
      unawaited(
        ref.read(agentCatalogProvider.notifier).refreshIfStaleSilently(),
      );
      unawaited(_checkUpdates(UpdateCheckTrigger.automatic));
    }
  }

  Future<void> _loadOnboarding() async {
    if (mounted) setState(() => onboardingError = null);
    try {
      final results = await Future.wait<Object>([
        widget.gateway.loadOnboardingState(),
        widget.gateway.loadLocalScanNoticeDecision(),
      ]);
      final state = results[0] as OnboardingState;
      final noticeDecision = results[1] as LocalScanNoticeDecision;
      if (!mounted) return;
      if (state.completed) _initializeMainShell();
      setState(() {
        onboardingState = state;
        _localScanNoticeDecision = noticeDecision;
      });
    } catch (error) {
      if (mounted) setState(() => onboardingError = error);
    }
  }

  Future<void> _acknowledgeLocalScanNotice() async {
    if (_savingLocalScanNoticeDecision) return;
    setState(() {
      _savingLocalScanNoticeDecision = true;
      _localScanNoticeError = null;
    });
    try {
      await widget.gateway.saveLocalScanNoticeDecision(
        LocalScanNoticeDecision.accepted,
      );
      if (!mounted) return;
      final refresh = _refreshLibraryAfterNotice;
      setState(() {
        _localScanNoticeDecision = LocalScanNoticeDecision.accepted;
        _localScanNoticeVisible = false;
        _refreshLibraryAfterNotice = false;
      });
      _openLibrary(refresh: refresh);
    } catch (error) {
      if (mounted) setState(() => _localScanNoticeError = error);
    } finally {
      if (mounted) setState(() => _savingLocalScanNoticeDecision = false);
    }
  }

  Future<void> _deferLocalScanNotice() async {
    if (_savingLocalScanNoticeDecision) return;
    setState(() {
      _savingLocalScanNoticeDecision = true;
      _localScanNoticeError = null;
    });
    try {
      await widget.gateway.saveLocalScanNoticeDecision(
        LocalScanNoticeDecision.deferred,
      );
      if (!mounted) return;
      setState(() {
        _localScanNoticeDecision = LocalScanNoticeDecision.deferred;
        _localScanNoticeVisible = false;
        _refreshLibraryAfterNotice = false;
      });
    } catch (error) {
      if (mounted) setState(() => _localScanNoticeError = error);
    } finally {
      if (mounted) setState(() => _savingLocalScanNoticeDecision = false);
    }
  }

  void _initializeMainShell() {
    if (_mainShellInitialized) return;
    _mainShellInitialized = true;
    ref.read(agentCatalogProvider);
    unawaited(_detectCli());
    _startupUpdateTimer = Timer(const Duration(seconds: 2), () {
      if (_libraryActivated && _localScanAccessReady) {
        unawaited(_checkUpdates(UpdateCheckTrigger.automatic));
      }
    });
  }

  Future<void> _checkUpdates(UpdateCheckTrigger trigger) async {
    try {
      final settings = await widget.gateway.loadReminderSettings();
      if (!settings.updateAvailable) return;
      final library = await ref.read(libraryProvider.future);
      await ref
          .read(updateCheckProvider.notifier)
          .check(library.skills, trigger: trigger);
    } on Object {
      // Update discovery is optional and must never interrupt App navigation.
    }
  }

  void _completeOnboarding(bool openLibrary) {
    _initializeMainShell();
    setState(() {
      onboardingState = OnboardingState(
        completed: true,
        step: OnboardingStep.projects,
      );
      destination = _Destination.discover;
    });
    if (openLibrary) unawaited(_requestLibrary());
  }

  Future<void> _restartOnboarding() async {
    await widget.gateway.resetOnboarding();
    if (!mounted) return;
    setState(() {
      onboardingError = null;
      onboardingState = const OnboardingState(
        completed: false,
        step: OnboardingStep.welcome,
      );
    });
  }

  Future<void> _detectCli() async {
    final detected = await widget.gateway.detectCli();
    if (mounted) setState(() => cliStatus = detected);
  }

  Brightness _effectiveBrightness(
    BuildContext context,
    AppThemeMode themeMode,
  ) => switch (themeMode) {
    AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
  };

  void _openLibrary({bool refresh = false}) {
    setState(() {
      _libraryActivated = true;
      destination = _Destination.library;
    });
    _startupUpdateTimer?.cancel();
    unawaited(_checkUpdates(UpdateCheckTrigger.automatic));
    if (!refresh) return;
    ref.invalidate(libraryProvider);
    unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
  }

  Future<void> _requestLibrary({bool refresh = false}) async {
    if (_localScanAccessReady) {
      _openLibrary(refresh: refresh);
      return;
    }
    if (_checkingLocalScanNoticeRequirement || _localScanNoticeVisible) return;
    setState(() {
      _libraryActivated = true;
      destination = _Destination.library;
      _checkingLocalScanNoticeRequirement = true;
      _localScanNoticeRequirementError = null;
    });
    late final List<String> paths;
    try {
      paths = await widget.gateway.loadLocalScanNoticePaths();
    } catch (error) {
      if (mounted) setState(() => _localScanNoticeRequirementError = error);
      return;
    } finally {
      if (mounted) {
        setState(() => _checkingLocalScanNoticeRequirement = false);
      }
    }
    if (!mounted) return;
    if (paths.isEmpty) {
      setState(() => _localScanNoticeBypassed = true);
      _openLibrary(refresh: refresh);
      return;
    }
    setState(() {
      _refreshLibraryAfterNotice = refresh;
      _localScanNoticePaths = paths;
      _localScanNoticeError = null;
      _localScanNoticeVisible =
          _localScanNoticeDecision != LocalScanNoticeDecision.deferred;
    });
  }

  void _showLibrary() => unawaited(_requestLibrary(refresh: true));

  Future<void> _changeLanguage(AppLanguage language) async {
    dismissDiscoverDetail?.call();
    await ref.read(appearanceProvider.notifier).setLanguage(language);
    await ref.read(discoverProvider.notifier).reloadLocalizedContent();
  }

  @override
  Widget build(BuildContext context) {
    final appearance =
        ref.watch(appearanceProvider).value ?? const AppearanceState();
    final folderTheme = folderThemeHex(
      folderThemeColor(appearance.folderTheme),
    );
    final theme = buildSkillsTheme(
      folderThemeColor(folderTheme),
      brightness: _effectiveBrightness(context, appearance.themeMode),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = context.skillsColors;
          final onboarding = onboardingState;
          if (onboarding == null || _localScanNoticeDecision == null) {
            if (onboardingError != null) {
              return SkillsBackground(
                wallpaper: appearance.wallpaper,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SkillsAlert.destructive(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAlertCircle,
                        size: 18,
                        strokeWidth: 1.8,
                      ),
                      title: Text(context.l10n.onboardingStartupError),
                      description: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SkillsButton.outline(
                          onPressed: () => unawaited(_loadOnboarding()),
                          size: SkillsButtonSize.sm,
                          child: Text(context.l10n.retry),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return SkillsBackground(
              wallpaper: appearance.wallpaper,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  label: context.l10n.loading,
                  child: const SkillsSkeletonBox(
                    key: Key('local-scan-notice-loading-skeleton'),
                    width: 220,
                    height: 18,
                    borderRadius: 9,
                  ),
                ),
              ),
            );
          }
          if (!onboarding.completed) {
            return SkillsBackground(
              wallpaper: appearance.wallpaper,
              child: OnboardingScreen(
                gateway: widget.gateway,
                initialState: onboarding,
                onCompleted: _completeOnboarding,
              ),
            );
          }
          return SkillsBackground(
            wallpaper: appearance.wallpaper,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        if (cliStatus != null && !cliStatus!.isReady)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                            child: _CliBanner(
                              status: cliStatus!,
                              onOpenSettings: () => setState(
                                () => destination = _Destination.settings,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                            child: SkillsPrimaryFolder<_Destination>(
                              tabs: [
                                SkillsFolderTab(
                                  id: 'discover',
                                  value: _Destination.discover,
                                  label: context.l10n.discover,
                                ),
                                SkillsFolderTab(
                                  id: 'library',
                                  value: _Destination.library,
                                  label: context.l10n.library,
                                ),
                                SkillsFolderTab(
                                  id: 'settings',
                                  value: _Destination.settings,
                                  label: context.l10n.settings,
                                ),
                              ],
                              selected: destination,
                              onSelected: (value) {
                                if (value != _Destination.discover) {
                                  dismissDiscoverDetail?.call();
                                }
                                if (value == _Destination.library) {
                                  unawaited(_requestLibrary());
                                } else {
                                  setState(() => destination = value);
                                }
                              },
                              style: SkillsPrimaryFolderStyle(
                                folderColor: colors.folderBody,
                                activeTabColor: colors.folderBody,
                                inactiveTabColor: colors.folderTabInactive,
                                activeLabelStyle: context.skillsTypography.body
                                    .copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colors.foregroundDefault,
                                    ),
                                inactiveLabelStyle: context
                                    .skillsTypography
                                    .body
                                    .copyWith(color: colors.foregroundMuted),
                              ),
                              child: IndexedStack(
                                index: destination.index,
                                children: [
                                  TickerMode(
                                    enabled:
                                        destination == _Destination.discover,
                                    child: DiscoverScreen(
                                      gateway: widget.gateway,
                                      onInstalled: _showLibrary,
                                      onDismissHandlerChanged: (handler) {
                                        dismissDiscoverDetail = handler;
                                      },
                                    ),
                                  ),
                                  TickerMode(
                                    enabled:
                                        destination == _Destination.library,
                                    child:
                                        _libraryActivated &&
                                            _localScanAccessReady
                                        ? LibraryScreen(
                                            gateway: widget.gateway,
                                            onBrowseSkills: () => setState(
                                              () => destination =
                                                  _Destination.discover,
                                            ),
                                          )
                                        : _checkingLocalScanNoticeRequirement
                                        ? Center(
                                            child: Semantics(
                                              liveRegion: true,
                                              label: context.l10n.loading,
                                              child: const SkillsSkeletonBox(
                                                key: Key(
                                                  'local-scan-preflight-loading',
                                                ),
                                                width: 220,
                                                height: 18,
                                                borderRadius: 9,
                                              ),
                                            ),
                                          )
                                        : _localScanNoticeDecision ==
                                                  LocalScanNoticeDecision
                                                      .deferred &&
                                              _localScanNoticePaths.isNotEmpty
                                        ? _LocalScanDeferredView(
                                            paths: _localScanNoticePaths,
                                            continuing:
                                                _savingLocalScanNoticeDecision,
                                            onContinue: () => unawaited(
                                              _acknowledgeLocalScanNotice(),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  TickerMode(
                                    enabled:
                                        destination == _Destination.settings,
                                    child: SettingsScreen(
                                      gateway: widget.gateway,
                                      appUpdater: widget.appUpdater,
                                      appUpdateSource: widget.appUpdateSource,
                                      appUpdateChannel: widget.appUpdateChannel,
                                      appUpdateInitialDelay:
                                          widget.appUpdateInitialDelay,
                                      appUpdateCheckInterval:
                                          widget.appUpdateCheckInterval,
                                      folderTheme: folderTheme,
                                      onFolderThemeChanged: (value) => ref
                                          .read(appearanceProvider.notifier)
                                          .setFolderTheme(
                                            folderThemeHex(value),
                                          ),
                                      themeMode: appearance.themeMode,
                                      onThemeModeChanged: ref
                                          .read(appearanceProvider.notifier)
                                          .setThemeMode,
                                      language: appearance.language,
                                      onLanguageChanged: (language) =>
                                          unawaited(_changeLanguage(language)),
                                      wallpaper: appearance.wallpaper,
                                      onWallpaperChanged: ref
                                          .read(appearanceProvider.notifier)
                                          .setWallpaper,
                                      onRestartOnboarding: _restartOnboarding,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_localScanNoticeVisible ||
                      _localScanNoticeRequirementError != null) ...[
                    ModalBarrier(
                      key: const Key('local-scan-notice-barrier'),
                      color: context.skillsComponents.overlayBackdrop,
                      dismissible: false,
                    ),
                    if (_localScanNoticeRequirementError != null)
                      Center(
                        child: SkillsDialog(
                          constraints: const BoxConstraints(maxWidth: 480),
                          title: Text(
                            context.l10n.libraryRefreshSettingsFailed,
                          ),
                          actions: [
                            SkillsButton.outline(
                              onPressed: () => setState(() {
                                _localScanNoticeRequirementError = null;
                                destination = _Destination.discover;
                              }),
                              child: Text(context.l10n.cancel),
                            ),
                            SkillsButton(
                              onPressed: () => unawaited(_requestLibrary()),
                              child: Text(context.l10n.retry),
                            ),
                          ],
                          child: SkillsAlert.destructive(
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedAlertCircle,
                              size: 18,
                              strokeWidth: 1.8,
                            ),
                            title: Text(
                              context.l10n.onboardingProjectsLoadError,
                            ),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: SkillsDialog(
                          constraints: const BoxConstraints(maxWidth: 560),
                          title: Text(context.l10n.localScanPermissionTitle),
                          actions: [
                            SkillsButton.outline(
                              enabled: !_savingLocalScanNoticeDecision,
                              onPressed: () =>
                                  unawaited(_deferLocalScanNotice()),
                              child: Text(context.l10n.localScanDefer),
                            ),
                            SkillsButton(
                              enabled: !_savingLocalScanNoticeDecision,
                              onPressed: () =>
                                  unawaited(_acknowledgeLocalScanNotice()),
                              child: Text(context.l10n.localScanContinue),
                            ),
                          ],
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.localScanPermissionDescription,
                                style: context.skillsTypography.bodySecondary,
                              ),
                              const SizedBox(height: 12),
                              _LocalScanProjectTags(
                                paths: _localScanNoticePaths,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                key: const Key('local-scan-privacy-summary'),
                                context.l10n.localScanPrivacySummary,
                                style: context.skillsTypography.bodySecondary,
                              ),
                              if (_localScanNoticeError != null) ...[
                                const SizedBox(height: 10),
                                SkillsAlert.destructive(
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedAlertCircle,
                                    size: 18,
                                    strokeWidth: 1.8,
                                  ),
                                  title: Text(
                                    context.l10n.onboardingStateError,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                  const InstallationTaskStack(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocalScanDeferredView extends StatelessWidget {
  const _LocalScanDeferredView({
    required this.paths,
    required this.continuing,
    required this.onContinue,
  });

  final List<String> paths;
  final bool continuing;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Semantics(
          key: const Key('local-scan-deferred-view'),
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                context.l10n.localScanDeferredTitle,
                textAlign: TextAlign.center,
                style: context.skillsTypography.pageTitle,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.localScanDeferredMessage,
                textAlign: TextAlign.center,
                style: context.skillsTypography.bodySecondary,
              ),
              const SizedBox(height: 14),
              _LocalScanProjectTags(
                paths: paths,
                alignment: WrapAlignment.center,
              ),
              const SizedBox(height: 20),
              SkillsButton(
                enabled: !continuing,
                onPressed: onContinue,
                child: Text(context.l10n.localScanResume),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LocalScanProjectTags extends StatelessWidget {
  const _LocalScanProjectTags({
    required this.paths,
    this.alignment = WrapAlignment.start,
  });

  final List<String> paths;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 180),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Wrap(
          key: const Key('local-scan-project-tags'),
          spacing: 6,
          runSpacing: 6,
          alignment: alignment,
          children: [
            for (final path in paths)
              Container(
                key: ValueKey('local-scan-project-tag-$path'),
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.basename(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.metadata.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
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

class _CliBanner extends StatelessWidget {
  const _CliBanner({required this.status, required this.onOpenSettings});
  final CliStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: context.skillsComponents.statusAttention.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: context.skillsComponents.statusAttention.withValues(alpha: .3),
      ),
    ),
    child: Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedComputerTerminal01,
          size: 17,
          strokeWidth: 1.8,
          color: context.skillsComponents.statusAttention,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            cliStatusMessage(context, status),
            style: TextStyle(color: context.skillsComponents.statusAttention),
          ),
        ),
        TextButton(
          onPressed: onOpenSettings,
          child: Text(context.l10n.openSettings),
        ),
      ],
    ),
  );
}
