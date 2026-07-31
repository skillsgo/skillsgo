/*
 * [INPUT]: Depends on a build-time production URL and caller-supplied process environment.
 * [OUTPUT]: Parses production public-HTTPS and rehearsal loopback-HTTP App update sources with one shared security policy.
 * [POS]: Serves as the pure-Dart update-source contract shared by the App and release CI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

const appUpdateRehearsalUrlEnvironment = 'SKILLSGO_APP_UPDATE_REHEARSAL_URL';
const appUpdateProductionUrl = String.fromEnvironment(
  'SKILLSGO_APP_UPDATE_URL',
);

/// Returns the stable HTTPS update directory embedded in a production build.
Uri? appUpdateProductionSource([String raw = appUpdateProductionUrl]) {
  final configured = raw.trim();
  if (configured.isEmpty) return null;

  final source = Uri.tryParse(configured);
  if (source == null ||
      source.scheme != 'https' ||
      source.host.isEmpty ||
      source.userInfo.isNotEmpty ||
      source.hasQuery ||
      source.hasFragment ||
      _isDisallowedLiteralIpHost(source.host)) {
    throw FormatException(
      'SKILLSGO_APP_UPDATE_URL must be a public HTTPS directory URL.',
      raw,
    );
  }
  final path = source.path.endsWith('/') ? source.path : '${source.path}/';
  return source.replace(path: path);
}

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

bool _isDisallowedLiteralIpHost(String host) {
  if (host.toLowerCase() == 'localhost') return true;
  final address = InternetAddress.tryParse(host);
  if (address == null) return false;
  if (address.isLoopback) return true;
  final bytes = address.rawAddress;
  if (bytes.length == 4) return _isNonPublicIpv4(bytes);
  if (bytes.every((byte) => byte == 0) ||
      bytes.first & 0xfe == 0xfc ||
      bytes.first == 0xfe && bytes[1] & 0xc0 == 0x80 ||
      bytes.first == 0xff ||
      bytes[0] == 0x20 &&
          bytes[1] == 0x01 &&
          bytes[2] == 0x0d &&
          bytes[3] == 0xb8) {
    return true;
  }
  final ipv4Mapped =
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;
  return ipv4Mapped && _isNonPublicIpv4(bytes.sublist(12));
}

bool _isNonPublicIpv4(List<int> bytes) {
  final first = bytes[0];
  final second = bytes[1];
  return first == 0 ||
      first == 10 ||
      first == 100 && second >= 64 && second <= 127 ||
      first == 127 ||
      first == 169 && second == 254 ||
      first == 172 && second >= 16 && second <= 31 ||
      first == 192 &&
          (second == 0 && (bytes[2] == 0 || bytes[2] == 2) ||
              second == 88 && bytes[2] == 99) ||
      first == 192 && second == 168 ||
      first == 198 &&
          (second == 18 || second == 19 || second == 51 && bytes[2] == 100) ||
      first == 203 && second == 0 && bytes[2] == 113 ||
      first >= 224;
}
