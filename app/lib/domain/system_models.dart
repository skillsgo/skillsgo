/*
 * [INPUT]: Depends only on Dart asynchronous primitives.
 * [OUTPUT]: Provides shared status enums, update availability, App preferences, CLI process contracts, command results, and typed Skills failures.
 * [POS]: Serves as the cross-journey system vocabulary used by focused App domain modules and infrastructure adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

enum CliAvailability { ready, missing, incompatible }

enum CliIssue { missing, damaged, incompatible }

enum UpdateState { unknown, checking, upToDate, available, unsupported, failed }

class UpdateAvailability {
  const UpdateAvailability({required this.state, this.toVersion = ''});

  final UpdateState state;
  final String toVersion;
}

enum HealthState { ready, notInitialized, unreachable, invalid }

enum SkillsFailureKind {
  validation,
  server,
  timeout,
  offline,
  invalidResponse,
  invalidLocalData,
  artifactUnavailable,
}

enum DiscoveryCollection { search, ranking, trending, hot }

enum SkillTrustLevel {
  unverified,
  communityVerified,
  publisherVerified,
  official,
  warned,
  delisted,
}

enum SkillRiskAssessment { unknown, low, medium, high, critical }

enum InstallationScope { user, project }

enum DiscoveryVerification { verified, unverified }

enum InstallationPlanAction { create, replace, skip, conflict, blockedByRisk }

enum InstallationTargetOutcome { succeeded, skipped, conflict, failed }

enum InstallationProgressState { started, finished }

enum UpdatePlanAction { update, current, pinned, failed }

enum UpdateTargetOutcome { succeeded, skipped, failed }

enum TargetManagementAction { remove, repair }

enum TargetManagementOutcome { succeeded, failed }

enum InstallationHealth {
  healthy,
  missing,
  replaced,
  localModification,
  unreadable,
  undeclared,
  workspaceUnreadable,
  lockMismatch,
  unexpectedPath,
}

enum LibraryProvenance { hub, local, external }

enum ProjectAccessState { accessible, missing, permissionDenied, inaccessible }

enum OnboardingStep { welcome, projects }

enum SkillMetricKind { allTimeInstalls, installs24h, hotVelocity }

enum HubIssue {
  invalidOrigin,
  httpFailure,
  invalidProtocol,
  invalidJson,
  connectionFailure,
  timeout,
}

enum HubMode { selfhost, cloud }

class HubRuntime {
  const HubRuntime({required this.mode, this.cloudOrigin});

  final HubMode mode;
  final Uri? cloudOrigin;

  bool get hasCloud => mode == HubMode.cloud && cloudOrigin != null;
}

class HubStatus {
  const HubStatus({
    required this.origin,
    required this.state,
    this.issue,
    this.httpStatus,
    this.diagnostic,
    this.version,
  });

  final String origin;
  final HealthState state;
  final HubIssue? issue;
  final int? httpStatus;
  final String? diagnostic;
  final String? version;

  bool get isReady => state == HealthState.ready;
}

class PersonalRiskPolicy {
  const PersonalRiskPolicy({
    this.confirmHighRisk = true,
    this.allowCriticalOverride = false,
  });

  final bool confirmHighRisk;
  final bool allowCriticalOverride;
}

class ReminderSettings {
  const ReminderSettings({
    this.updateAvailable = true,
    this.securityAdvisory = true,
  });

  final bool updateAvailable;
  final bool securityAdvisory;

  ReminderSettings copyWith({bool? updateAvailable, bool? securityAdvisory}) =>
      ReminderSettings(
        updateAvailable: updateAvailable ?? this.updateAvailable,
        securityAdvisory: securityAdvisory ?? this.securityAdvisory,
      );
}

class CliStatus {
  const CliStatus({
    required this.availability,
    this.path,
    this.version,
    this.message,
    this.issue,
  });

  final CliAvailability availability;
  final String? path;
  final String? version;
  final String? message;
  final CliIssue? issue;

  bool get isReady => availability == CliAvailability.ready;
}

class ProcessOutput {
  const ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract interface class ProcessRunner {
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  });
}

enum AppThemeMode { system, light, dark }

enum AppWallpaper {
  sun,
  mercury,
  venus,
  earth,
  mars,
  jupiter,
  saturn,
  uranus,
  neptune,
  pluto,
  moon,
}

class CommandResult {
  const CommandResult({required this.command, required this.output});

  final List<String> command;
  final ProcessOutput output;

  bool get succeeded => output.exitCode == 0;
}

class SkillsException implements Exception {
  const SkillsException(
    this.message, {
    this.kind = SkillsFailureKind.server,
    this.isOffline = false,
    this.code = '',
    this.retryable = false,
    this.details = const {},
    this.requestId = '',
    this.diagnostic = '',
  });

  final String message;
  final SkillsFailureKind kind;
  final bool isOffline;
  final String code;
  final bool retryable;
  final Map<String, Object?> details;
  final String requestId;
  final String diagnostic;

  @override
  String toString() => message;
}
