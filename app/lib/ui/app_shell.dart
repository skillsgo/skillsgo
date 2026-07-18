/*
 * [INPUT]: Depends on SkillsGateway contracts, Riverpod feature state, split feature view parts, localized copy, Flutter spring physics, HugeIcons, native Material components, the accessible themeable primary folder, stateful nested navigation, and SkillsGo brand tokens.
 * [OUTPUT]: Provides the desktop shell composition plus shared UI contracts consumed by split Discover, Library, Settings, and mutation-flow views.
 * [POS]: Serves as the primary rendered product surface and translates domain states into accessible localized UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;
import 'bloom_color_picker/bloom_color_picker.dart';
import 'discrete_tabs/discrete_tabs.dart';
import 'native_components.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'appearance_controller.dart';
import 'brand.dart';
import 'brand_theme_presets.dart';
import 'color_scheme_inspector.dart';
import 'discover_controller.dart';
import 'install_location_popover.dart';
import 'install_operation_controller.dart';
import 'library_controller.dart';
import 'nested_navigation.dart';
import 'primary_folder_shell.dart';
import 'skill_markdown_view.dart';
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

class _AppShellState extends ConsumerState<AppShell> {
  VoidCallback? dismissDiscoverDetail;
  _Destination destination = _Destination.discover;
  CliStatus? cliStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_detectCli());
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
  });

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
                            activeLabelStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.foregroundDefault,
                            ),
                            inactiveLabelStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              color: colors.foregroundMuted,
                            ),
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
                                child: LibraryScreen(gateway: widget.gateway),
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
                                  wallpaper: appearance.wallpaper,
                                  onWallpaperChanged: ref
                                      .read(appearanceProvider.notifier)
                                      .setWallpaper,
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
            style: const TextStyle(
              fontFamily: SkillsTokens.monoFamily,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> _confirmCommand(
  BuildContext context, {
  required String title,
  required String description,
  required List<String> facts,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showSkillsDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 16),
              ...facts.map(
                (fact) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    fact,
                    style: TextStyle(
                      fontFamily: SkillsTokens.monoFamily,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? context.skillsComponents.statusDangerSolid
                  : context.skillsComponents.primaryRest,
              foregroundColor: destructive
                  ? context.skillsComponents.statusDangerForeground
                  : context.skillsComponents.primaryForeground,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

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

String _installationModeLabel(BuildContext context, InstallationMode mode) =>
    switch (mode) {
      InstallationMode.symlink => context.l10n.modeSymlink,
      InstallationMode.copy => context.l10n.modeCopy,
      InstallationMode.external => context.l10n.modeExternal,
    };

Widget _libraryProvenanceChip(
  BuildContext context,
  LibraryProvenance provenance,
) {
  final presentation = switch (provenance) {
    LibraryProvenance.hub => (
      label: context.l10n.hubManaged,
      color: context.skillsComponents.statusAccent,
    ),
    LibraryProvenance.local => (
      label: context.l10n.localManaged,
      color: context.skillsComponents.statusSevere,
    ),
    LibraryProvenance.external => (
      label: context.l10n.externalInstallation,
      color: context.skillsComponents.statusAttention,
    ),
  };
  return StatusChip(label: presentation.label, color: presentation.color);
}

Widget _installationHealthChip(
  BuildContext context,
  InstallationHealth health,
) {
  final presentation = switch (health) {
    InstallationHealth.healthy => (
      label: context.l10n.healthHealthy,
      color: context.skillsComponents.statusSuccess,
    ),
    InstallationHealth.undeclared => (
      label: context.l10n.healthUndeclared,
      color: context.skillsComponents.statusAttention,
    ),
    InstallationHealth.workspaceUnreadable => (
      label: context.l10n.healthWorkspaceUnreadable,
      color: context.skillsComponents.statusSevere,
    ),
    InstallationHealth.lockMismatch => (
      label: context.l10n.healthLockMismatch,
      color: context.skillsComponents.statusSevere,
    ),
    InstallationHealth.missing => (
      label: context.l10n.healthMissing,
      color: context.skillsComponents.statusDanger,
    ),
    InstallationHealth.replaced => (
      label: context.l10n.healthReplaced,
      color: context.skillsComponents.statusDanger,
    ),
    InstallationHealth.localModification => (
      label: context.l10n.healthLocalModification,
      color: context.skillsComponents.statusAttention,
    ),
    InstallationHealth.unreadable => (
      label: context.l10n.healthUnreadable,
      color: context.skillsComponents.statusDanger,
    ),
    InstallationHealth.unexpectedPath => (
      label: context.l10n.healthUnexpectedPath,
      color: context.skillsComponents.statusDanger,
    ),
  };
  return StatusChip(label: presentation.label, color: presentation.color);
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

String _storageStatusMessage(BuildContext context, StorageStatus status) =>
    switch (status.state) {
      HealthState.ready => context.l10n.storageHealthyDescription,
      HealthState.notInitialized =>
        context.l10n.storageNotInitializedDescription,
      HealthState.unreachable => context.l10n.storageUnavailableDescription,
      HealthState.invalid => context.l10n.storageInvalidResponse,
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
