/*
 * [INPUT]: Depends on Flutter foundation, Riverpod legacy family providers, and SkillsGateway Package update-check plus discovery reads.
 * [OUTPUT]: Provides one shared, Package-Path-keyed manual update-check operation with immediate feedback, duplicate-call coalescing, and bounded publication polling.
 * [POS]: Serves as the App business-state boundary shared by Package cards and remote Skill detail.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

enum PackageUpdateOperationPhase {
  idle,
  checking,
  upToDate,
  updating,
  updated,
  failed,
}

class PackageUpdateOperationState {
  const PackageUpdateOperationState({
    this.phase = PackageUpdateOperationPhase.idle,
    this.version = '',
    this.error,
  });

  final PackageUpdateOperationPhase phase;
  final String version;
  final Object? error;

  bool get busy =>
      phase == PackageUpdateOperationPhase.checking ||
      phase == PackageUpdateOperationPhase.updating;
}

final packageUpdateOperationProvider =
    ChangeNotifierProvider.family<PackageUpdateCheckController, String>(
      (ref, packagePath) => PackageUpdateCheckController(
        ref.read(skillsGatewayProvider),
        packagePath,
      ),
    );

class PackageUpdateCheckController extends ChangeNotifier {
  PackageUpdateCheckController(
    this._gateway,
    this.packagePath, {
    this.pollInterval = const Duration(seconds: 1),
    this.maximumPolls = 60,
  });

  final SkillsGateway _gateway;
  final String packagePath;
  final Duration pollInterval;
  final int maximumPolls;
  PackageUpdateOperationState _state = const PackageUpdateOperationState();
  Future<PackageUpdateOperationState>? _active;
  bool _disposed = false;

  PackageUpdateOperationState get state => _state;

  void _replace(PackageUpdateOperationState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  Future<PackageUpdateOperationState> check(String currentVersion) {
    final active = _active;
    if (active != null) return active;
    final operation = _run(currentVersion);
    _active = operation;
    operation.whenComplete(() {
      if (identical(_active, operation)) _active = null;
    });
    return operation;
  }

  Future<PackageUpdateOperationState> _run(String currentVersion) async {
    _replace(
      const PackageUpdateOperationState(
        phase: PackageUpdateOperationPhase.checking,
      ),
    );
    try {
      final result = await _gateway.checkPackageUpdate(packagePath);
      if (result.status == PackageUpdateCheckStatus.upToDate) {
        _replace(
          PackageUpdateOperationState(
            phase: result.version == currentVersion
                ? PackageUpdateOperationPhase.upToDate
                : PackageUpdateOperationPhase.updated,
            version: result.version,
          ),
        );
        return state;
      }
      _replace(
        PackageUpdateOperationState(
          phase: PackageUpdateOperationPhase.updating,
          version: result.version,
        ),
      );
      for (var attempt = 0; attempt < maximumPolls; attempt++) {
        if (_disposed) return state;
        if (attempt > 0 || pollInterval > Duration.zero) {
          await Future<void>.delayed(pollInterval);
        }
        final page = await _gateway.discover(
          DiscoveryCollection.search,
          query: packagePath,
          perPage: 100,
        );
        var publishedVersion = page.module?.latestVersion;
        if (publishedVersion == null || publishedVersion.isEmpty) {
          for (final skill in page.skills) {
            if (skill.packagePath == packagePath) {
              publishedVersion = skill.latestVersion;
              break;
            }
          }
        }
        if (publishedVersion == result.version) {
          _replace(
            PackageUpdateOperationState(
              phase: PackageUpdateOperationPhase.updated,
              version: result.version,
            ),
          );
          return state;
        }
      }
      throw TimeoutException('Package update was not ready in time.');
    } catch (error) {
      _replace(
        PackageUpdateOperationState(
          phase: PackageUpdateOperationPhase.failed,
          version: currentVersion,
          error: error,
        ),
      );
      return state;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
