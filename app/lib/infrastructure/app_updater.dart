/*
 * [INPUT]: Depends on velopack_flutter's Velopack 1.2.0 Rust bridge and a caller-supplied HTTP update source.
 * [OUTPUT]: Provides the App's native updater boundary, early Velopack runtime initialization, real check/download/apply/restart execution, and loopback-only rehearsal-source parsing.
 * [POS]: Serves as the App-update infrastructure seam; production UI may consume AppUpdater without reimplementing Velopack, while CI uses the guarded rehearsal source to prove a complete unsigned update.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:velopack_flutter/velopack_flutter.dart' as velopack;

const appUpdateRehearsalUrlEnvironment = 'SKILLSGO_APP_UPDATE_REHEARSAL_URL';

abstract interface class AppUpdater {
  Future<void> initializeRuntime();

  Future<bool> applyAvailableUpdateAndRestart(Uri source);
}

final class VelopackAppUpdater implements AppUpdater {
  @override
  Future<void> initializeRuntime() => velopack.VelopackRustLib.init();

  @override
  Future<bool> applyAvailableUpdateAndRestart(Uri source) async {
    await velopack.initializeVelopack(url: source.toString());
    if (!await velopack.isUpdateAvailable()) return false;
    await velopack.updateAndRestart();
    return true;
  }
}

/// Returns a deliberately local-only update source used by the unsigned CI
/// rehearsal. Production update sources must be configured through the normal
/// App settings/update policy instead of this process environment escape hatch.
Uri? appUpdateRehearsalSource(Map<String, String> environment) {
  final raw = environment[appUpdateRehearsalUrlEnvironment]?.trim();
  if (raw == null || raw.isEmpty) return null;

  final source = Uri.tryParse(raw);
  if (source == null ||
      source.scheme != 'http' ||
      source.userInfo.isNotEmpty ||
      source.hasQuery ||
      source.hasFragment ||
      !_isLoopbackHost(source.host)) {
    throw FormatException(
      '$appUpdateRehearsalUrlEnvironment must be a loopback HTTP URL.',
      raw,
    );
  }
  return source;
}

bool _isLoopbackHost(String host) {
  if (host.toLowerCase() == 'localhost') return true;
  return InternetAddress.tryParse(host)?.isLoopback ?? false;
}
