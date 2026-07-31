/*
 * [INPUT]: Depends on velopack_flutter's Velopack 1.2.0 Rust bridge and the shared update-source contract.
 * [OUTPUT]: Provides typed App update checks, early Velopack runtime initialization, real check/download/apply/restart execution, and re-exports guarded update-source parsing.
 * [POS]: Serves as the native App-update infrastructure seam consumed by App presentation while re-exporting the pure source policy used by App callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:velopack_flutter/velopack_flutter.dart' as velopack;

export 'app_update_source.dart';

final class AppUpdateCheck {
  const AppUpdateCheck({
    required this.currentVersion,
    required this.availableVersion,
  });

  final String currentVersion;
  final String? availableVersion;

  bool get updateAvailable => availableVersion != null;
}

abstract interface class AppUpdater {
  Future<void> initializeRuntime();

  Future<AppUpdateCheck> checkForUpdate(Uri source);

  Future<bool> applyAvailableUpdateAndRestart(Uri source);
}

final class VelopackAppUpdater implements AppUpdater {
  @override
  Future<void> initializeRuntime() => velopack.VelopackRustLib.init();

  @override
  Future<AppUpdateCheck> checkForUpdate(Uri source) async {
    await velopack.initializeVelopack(url: source.toString());
    final currentVersion = await velopack.currentVersion();
    final update = await velopack.getLatestUpdateInfo();
    return AppUpdateCheck(
      currentVersion: currentVersion,
      availableVersion: update?.targetFullRelease.version,
    );
  }

  @override
  Future<bool> applyAvailableUpdateAndRestart(Uri source) async {
    await velopack.initializeVelopack(url: source.toString());
    if (!await velopack.isUpdateAvailable()) return false;
    await velopack.updateAndRestart();
    return true;
  }
}
