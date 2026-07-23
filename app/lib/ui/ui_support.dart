/*
 * [INPUT]: Depends on App domain status contracts, localized copy, SkillsGo design tokens, HugeIcons, and native Material components.
 * [OUTPUT]: Provides localized BuildContext access, shared failure/status copy, command result rendering, stable Library target keys, Agent labels, and health/status presentation.
 * [POS]: Serves as the small shared presentation vocabulary imported by otherwise independent App journey libraries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'brand.dart';
import 'native_components.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

Color folderThemeColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null || normalized.length != 6) {
    return Colors.white;
  }
  return Color(0xFF000000 | parsed);
}

String folderThemeHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

({String title, String message}) failureCopy(
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

String cliStatusMessage(BuildContext context, CliStatus status) =>
    switch (status.issue) {
      CliIssue.missing => context.l10n.cliMissingBundled,
      CliIssue.damaged => context.l10n.cliDamagedBundled,
      CliIssue.incompatible => context.l10n.cliIncompatibleBundled,
      null => status.message ?? context.l10n.cliNeedsAttention,
    };

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

CommandResult exceptionResult(Object error) {
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

String libraryUpdateKey(InstalledSkill skill) =>
    skill.inventoryKey.isEmpty ? skill.name : skill.inventoryKey;

String agentDisplayLabel(String agent) => agent
    .split(RegExp(r'[-_]'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

Widget installationHealthChip(BuildContext context, InstallationHealth health) {
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

String hubStatusMessage(BuildContext context, HubStatus status) =>
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

String cliAvailabilityLabel(
  BuildContext context,
  CliAvailability? availability,
) => switch (availability) {
  CliAvailability.ready => context.l10n.ready,
  CliAvailability.missing => context.l10n.missing,
  CliAvailability.incompatible => context.l10n.incompatible,
  null => context.l10n.unknown,
};
