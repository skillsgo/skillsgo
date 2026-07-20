/*
 * [INPUT]: Depends on SkillsGateway contracts, Mandatory Onboarding, Riverpod feature state, split feature view parts, localized copy, Flutter rendering direction and spring physics, HugeIcons, multi_dropdown, shared Agent, Added Project, and language identity components, the vendored Portal Labs subscription switch, native Material components, the accessible themeable primary folder, stateful nested navigation, and SkillsGo brand tokens.
 * [OUTPUT]: Provides the first-launch gate, desktop shell composition, cross-destination navigation actions, and shared UI contracts consumed by split Discover, Library, Settings, and mutation-flow views.
 * [POS]: Serves as the primary rendered product surface and translates domain states into accessible localized UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'native_components.dart';

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'appearance_controller.dart';
import 'brand.dart';
import 'discover_controller.dart';
import 'library_controller.dart';
import 'onboarding_screen.dart';
import 'primary_folder_shell.dart';

import 'discover_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'ui_support.dart';

enum _Destination { discover, library, settings }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.gateway});

  final SkillsGateway gateway;

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
  bool _mainShellInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadOnboarding());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _mainShellInitialized) {
      unawaited(
        ref.read(agentCatalogProvider.notifier).refreshIfStaleSilently(),
      );
    }
  }

  Future<void> _loadOnboarding() async {
    if (mounted) setState(() => onboardingError = null);
    try {
      final state = await widget.gateway.loadOnboardingState();
      if (!mounted) return;
      if (state.completed) _initializeMainShell();
      setState(() => onboardingState = state);
    } catch (error) {
      if (mounted) setState(() => onboardingError = error);
    }
  }

  void _initializeMainShell() {
    if (_mainShellInitialized) return;
    _mainShellInitialized = true;
    ref.read(agentCatalogProvider);
    unawaited(_detectCli());
  }

  void _completeOnboarding(bool openLibrary) {
    _initializeMainShell();
    setState(() {
      onboardingState = OnboardingState(
        completed: true,
        step: OnboardingStep.projects,
      );
      destination = openLibrary ? _Destination.library : _Destination.discover;
    });
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

  void _showLibrary() => setState(() {
    destination = _Destination.library;
    ref.invalidate(libraryProvider);
    unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
  });

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
          if (onboarding == null) {
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
              child: SafeArea(
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
                            setState(() => destination = value);
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
                            inactiveLabelStyle: context.skillsTypography.body
                                .copyWith(color: colors.foregroundMuted),
                          ),
                          child: IndexedStack(
                            index: destination.index,
                            children: [
                              TickerMode(
                                enabled: destination == _Destination.discover,
                                child: DiscoverScreen(
                                  gateway: widget.gateway,
                                  onInstalled: _showLibrary,
                                  onDismissHandlerChanged: (handler) {
                                    dismissDiscoverDetail = handler;
                                  },
                                ),
                              ),
                              TickerMode(
                                enabled: destination == _Destination.library,
                                child: LibraryScreen(
                                  gateway: widget.gateway,
                                  onBrowseSkills: () => setState(
                                    () => destination = _Destination.discover,
                                  ),
                                ),
                              ),
                              TickerMode(
                                enabled: destination == _Destination.settings,
                                child: SettingsScreen(
                                  gateway: widget.gateway,
                                  folderTheme: folderTheme,
                                  onFolderThemeChanged: (value) => ref
                                      .read(appearanceProvider.notifier)
                                      .setFolderTheme(folderThemeHex(value)),
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
            ),
          );
        },
      ),
    );
  }
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
