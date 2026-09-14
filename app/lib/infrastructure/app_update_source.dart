/*
 * [INPUT]: Depends on the official CDN, current desktop ABI, optional build-time production URL/channel overrides, and caller-supplied process environment containing an optional rehearsal source/channel pair.
 * [OUTPUT]: Resolves a platform-specific official production update directory by default, parses explicit public-HTTPS overrides, and parses rehearsal loopback-HTTP App update configuration with one shared security policy.
 * [POS]: Serves as the pure-Dart update-source contract shared by the App and release CI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';
import 'dart:ffi';

const appUpdateRehearsalUrlEnvironment = 'SKILLSGO_APP_UPDATE_REHEARSAL_URL';
const appUpdateRehearsalChannelEnvironment =
    'SKILLSGO_APP_UPDATE_REHEARSAL_CHANNEL';
const appUpdateProductionUrl = String.fromEnvironment(
  'SKILLSGO_APP_UPDATE_URL',
);
const appUpdateProductionChannelValue = String.fromEnvironment(
  'SKILLSGO_APP_UPDATE_CHANNEL',
);
const appUpdateProductionBaseUrl = 'https://cdn.skillsgo.ai/app';

/// Returns the stable HTTPS update directory embedded in a production build.
Uri? appUpdateProductionSource([String? raw]) {
  final configuredRaw =
      raw ??
      (appUpdateProductionUrl.trim().isNotEmpty ? appUpdateProductionUrl : '');
  final configured = configuredRaw.trim();
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
      configuredRaw,
    );
  }
  final path = source.path.endsWith('/') ? source.path : '${source.path}/';
  return source.replace(path: path);
}

String? appUpdateProductionChannel([String? raw]) {
  final channel =
      (raw ??
              (appUpdateProductionChannelValue.trim().isNotEmpty
                  ? appUpdateProductionChannelValue
                  : _currentProductionChannel()))
          .trim();
  if (channel.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(channel)) {
    throw FormatException(
      'SKILLSGO_APP_UPDATE_CHANNEL must be a Velopack channel.',
      raw,
    );
  }
  return channel;
}

String _currentProductionChannel() => switch (Abi.current()) {
  Abi.macosArm64 => 'osx-arm64',
  Abi.macosX64 => 'osx-x64',
  Abi.linuxX64 => 'linux-x64',
  Abi.windowsX64 => 'win-x64',
  final abi => throw UnsupportedError(
    'SkillsGo App updates do not support the current ABI: $abi',
  ),
};

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

String? appUpdateRehearsalChannel(Map<String, String> environment) {
  final channel = environment[appUpdateRehearsalChannelEnvironment]?.trim();
  if (channel == null || channel.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(channel)) {
    throw FormatException(
      '$appUpdateRehearsalChannelEnvironment must be a Velopack channel.',
      channel,
    );
  }
  return channel;
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
