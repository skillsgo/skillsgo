/*
 * [INPUT]: Depends on SkillsGateway contracts, Mandatory Onboarding, Riverpod feature state, split feature view parts, localized copy, Flutter rendering direction and spring physics, HugeIcons, multi_dropdown, shared Agent, Added Project, and language identity components, the vendored Portal Labs subscription switch, native Material components, the accessible themeable primary folder, stateful nested navigation, and SkillsGo brand tokens.
 * [OUTPUT]: Provides the first-launch gate, desktop shell composition, cross-destination navigation actions, and shared UI contracts consumed by split Discover, Library, Settings, and mutation-flow views.
 * [POS]: Serves as the primary rendered product surface and translates domain states into accessible localized UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:multi_dropdown/multi_dropdown.dart';
import 'package:path/path.dart' as p;
import 'package:just_tooltip/just_tooltip.dart';
import 'bloom_color_picker/bloom_color_picker.dart';
import 'discrete_tabs/discrete_tabs.dart';
import 'native_components.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'agent_catalog_controller.dart';
import 'appearance_controller.dart';
import 'brand.dart';
import 'brand_theme_presets.dart';
import 'discover_controller.dart';
import 'install_location_popover.dart';
import 'install_operation_controller.dart';
import 'language_identity_icon.dart';
import 'library_controller.dart';
import 'nested_navigation.dart';
import 'onboarding_screen.dart';
import 'primary_folder_shell.dart';
import 'project_identity_icon.dart';
import 'skill_markdown_view.dart';
import 'subscription_segmented_switch.dart';
import 'target_management_controller.dart';
import 'update_operation_controller.dart';

part 'discover_screen.dart';
part 'installation_flows.dart';
part 'library_screen.dart';
part 'settings_screen.dart';

extension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

({String title, String message}) _failureCopy(
  BuildContext context,
  Object error, {
  bool detail = false,
}) {
  final kind = error is SkillsException ? error.kind : SkillsFailureKind.server;
  return switch (kind) {
    SkillsFailureKind.validation => (
      title: context.l10n.validationTitle,
      message: context.l10n.validationMessage,
    ),
    SkillsFailureKind.server => (
      title: context.l10n.serverTitle,
      message: context.l10n.serverMessage,
    ),
    SkillsFailureKind.timeout => (
      title: context.l10n.timeoutTitle,
      message: context.l10n.timeoutMessage,
    ),
    SkillsFailureKind.offline => (
      title: context.l10n.offlineTitle,
      message: context.l10n.offlineMessage,
    ),
    SkillsFailureKind.invalidResponse when detail => (
      title: context.l10n.detailInvalidTitle,
      message: context.l10n.detailInvalidMessage,
    ),
    SkillsFailureKind.invalidResponse => (
      title: context.l10n.invalidResponseTitle,
      message: context.l10n.invalidResponseMessage,
    ),
    SkillsFailureKind.invalidLocalData => (
      title: context.l10n.invalidLocalDataTitle,
      message: context.l10n.invalidLocalDataMessage,
    ),
    SkillsFailureKind.artifactUnavailable => (
      title: context.l10n.artifactUnavailableTitle,
      message: context.l10n.artifactUnavailableMessage,
    ),
  };
}

String _cliStatusMessage(BuildContext context, CliStatus status) =>
    switch (status.issue) {
      CliIssue.missing => context.l10n.cliMissingBundled,
      CliIssue.damaged => context.l10n.cliDamagedBundled,
      CliIssue.incompatible => context.l10n.cliIncompatibleBundled,
      null => status.message ?? context.l10n.cliNeedsAttention,
    };

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

  static const _legacyFolderThemes = <String, Color>{
    'manila': Color(0xFF514532),
    'blue': Color(0xFF294556),
    'sage': Color(0xFF3D5141),
    'charcoal': Color(0xFF292A2B),
  };

  Brightness _effectiveBrightness(
    BuildContext context,
    AppThemeMode themeMode,
  ) => switch (themeMode) {
    AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
  };

  static Color _folderThemeColor(String value) {
    final legacy = _legacyFolderThemes[value];
    if (legacy != null) return legacy;
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null || normalized.length != 6) {
      return _legacyFolderThemes['manila']!;
    }
    return Color(0xFF000000 | parsed);
  }

  static String _folderThemeHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

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
    final folderTheme = _folderThemeHex(
      _folderThemeColor(appearance.folderTheme),
    );
    final theme = buildSkillsTheme(
      _folderThemeColor(folderTheme),
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
                                      .setFolderTheme(_folderThemeHex(value)),
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
            _cliStatusMessage(context, status),
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

class OperationPanel extends StatelessWidget {
  const OperationPanel({super.key, required this.result});
  final CommandResult result;
  @override
  Widget build(BuildContext context) {
    if (result.output.exitCode == 69) {
      return SkillsAlert(
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedCloudOff,
          strokeWidth: 1.8,
        ),
        title: Text(context.l10n.offlineTitle),
        description: Text(context.l10n.offlineMessage),
      );
    }
    if (result.output.exitCode == 75) {
      return SkillsAlert(
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedAlarmClockOff,
          strokeWidth: 1.8,
        ),
        title: Text(context.l10n.timeoutTitle),
        description: Text(context.l10n.timeoutMessage),
      );
    }
    final statusColor = result.succeeded
        ? context.skillsComponents.statusSuccess
        : context.skillsComponents.statusDanger;
    return ExpansionTile(
      collapsedBackgroundColor: statusColor.withValues(alpha: .1),
      backgroundColor: context.skillsComponents.controlRest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: HugeIcon(
        icon: result.succeeded
            ? HugeIcons.strokeRoundedCheckmarkCircle02
            : HugeIcons.strokeRoundedAlertCircle,
        strokeWidth: 1.8,
        color: statusColor,
      ),
      title: Text(
        result.succeeded
            ? context.l10n.commandCompleted
            : context.l10n.commandFailed,
      ),
      subtitle: Text(context.l10n.commandExit(result.output.exitCode)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            '\$ ${result.command.join(' ')}\n\nstdout:\n${result.output.stdout}\n\nstderr:\n${result.output.stderr}',
            style: context.skillsTypography.code,
          ),
        ),
      ],
    );
  }
}

CommandResult _exceptionResult(Object error) {
  final exitCode = error is SkillsException
      ? switch (error.kind) {
          SkillsFailureKind.offline => 69,
          SkillsFailureKind.timeout => 75,
          _ => 1,
        }
      : 1;
  return CommandResult(
    command: const ['skills'],
    output: ProcessOutput(
      exitCode: exitCode,
      stdout: '',
      stderr: error.toString(),
    ),
  );
}

String _libraryUpdateKey(InstalledSkill skill) =>
    skill.inventoryKey.isEmpty ? skill.name : skill.inventoryKey;

String _agentDisplayLabel(String agent) => agent
    .split(RegExp(r'[-_]'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

Widget _installationHealthChip(
  BuildContext context,
  InstallationHealth health,
) {
  final label = switch (health) {
    InstallationHealth.healthy => context.l10n.healthHealthy,
    InstallationHealth.undeclared => context.l10n.healthUndeclared,
    InstallationHealth.workspaceUnreadable =>
      context.l10n.healthWorkspaceUnreadable,
    InstallationHealth.lockMismatch => context.l10n.healthLockMismatch,
    InstallationHealth.missing => context.l10n.healthMissing,
    InstallationHealth.replaced => context.l10n.healthReplaced,
    InstallationHealth.localModification =>
      context.l10n.healthLocalModification,
    InstallationHealth.unreadable => context.l10n.healthUnreadable,
    InstallationHealth.unexpectedPath => context.l10n.healthUnexpectedPath,
  };
  return StatusChip(
    label: label,
    color: health == InstallationHealth.healthy
        ? context.skillsComponents.statusSuccess
        : context.skillsComponents.statusDangerSolid,
  );
}

String _hubStatusMessage(BuildContext context, HubStatus status) =>
    switch (status.issue) {
      HubIssue.invalidOrigin => context.l10n.hubInvalidOrigin,
      HubIssue.httpFailure => context.l10n.hubHttpFailure(
        status.httpStatus ?? 0,
      ),
      HubIssue.invalidProtocol => context.l10n.hubInvalidProtocol,
      HubIssue.invalidJson => context.l10n.hubInvalidJson,
      HubIssue.connectionFailure => context.l10n.hubConnectionFailure,
      HubIssue.timeout => context.l10n.hubConnectionTimeout,
      null => context.l10n.hubInvalidProtocol,
    };

String _cliAvailabilityLabel(
  BuildContext context,
  CliAvailability? availability,
) => switch (availability) {
  CliAvailability.ready => context.l10n.ready,
  CliAvailability.missing => context.l10n.missing,
  CliAvailability.incompatible => context.l10n.incompatible,
  null => context.l10n.unknown,
};
