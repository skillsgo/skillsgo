/*
 * [INPUT]: Depends on the App updater's production source and unsigned rehearsal source/channel parsers.
 * [OUTPUT]: Proves production builds accept only clean HTTPS feeds while the CI escape hatch accepts only explicit loopback HTTP feeds and safe Velopack channels.
 * [POS]: Serves as the security and configuration contract for production App updates and real packaged update rehearsals.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/infrastructure/app_updater.dart';

void main() {
  test('production update source is absent unless configured', () {
    expect(appUpdateProductionSource(''), isNull);
    expect(appUpdateProductionSource('   '), isNull);
  });

  test(
    'production update source accepts HTTPS and normalizes its directory',
    () {
      expect(
        appUpdateProductionSource('https://releases.example.com/app/osx-arm64'),
        Uri.parse('https://releases.example.com/app/osx-arm64/'),
      );
    },
  );

  test('production update source rejects unsafe or ambiguous URLs', () {
    for (final source in const [
      'http://releases.example.com/app/osx-arm64/',
      'https://user@releases.example.com/app/osx-arm64/',
      'https://releases.example.com/app/osx-arm64/?channel=preview',
      'https://releases.example.com/app/osx-arm64/#feed',
      'https://localhost/app/osx-arm64/',
      'https://10.0.0.1/app/osx-arm64/',
      'https://192.168.1.1/app/osx-arm64/',
      'https://192.0.2.1/app/osx-arm64/',
      'https://198.18.0.1/app/osx-arm64/',
      'https://198.51.100.1/app/osx-arm64/',
      'https://203.0.113.1/app/osx-arm64/',
      'https://[fc00::1]/app/osx-arm64/',
      'https://[fe80::1]/app/osx-arm64/',
      'https://[2001:db8::1]/app/osx-arm64/',
    ]) {
      expect(() => appUpdateProductionSource(source), throwsFormatException);
    }
  });

  test('ordinary launches have no rehearsal update source', () {
    expect(appUpdateRehearsalSource(const {}), isNull);
    expect(
      appUpdateRehearsalSource(const {appUpdateRehearsalUrlEnvironment: '   '}),
      isNull,
    );
    expect(appUpdateRehearsalChannel(const {}), isNull);
  });

  test('accepts only an explicit Velopack rehearsal channel', () {
    expect(
      appUpdateRehearsalChannel(const {
        appUpdateRehearsalChannelEnvironment: 'osx-x64',
      }),
      'osx-x64',
    );
    expect(
      () => appUpdateRehearsalChannel(const {
        appUpdateRehearsalChannelEnvironment: '../osx-x64',
      }),
      throwsFormatException,
    );
  });

  test('accepts loopback HTTP sources', () {
    for (final source in const [
      'http://localhost:8080/releases/',
      'http://127.0.0.1:8080/releases',
      'http://[::1]:8080/releases',
    ]) {
      expect(
        appUpdateRehearsalSource({appUpdateRehearsalUrlEnvironment: source}),
        Uri.parse(source),
      );
    }
  });

  test('rejects remote, credentialed, and ambiguous sources', () {
    for (final source in const [
      'https://127.0.0.1/releases',
      'http://updates.example.com/releases',
      'http://user@localhost/releases',
      'http://localhost/releases?channel=test',
      'http://localhost/releases#feed',
    ]) {
      expect(
        () => appUpdateRehearsalSource({
          appUpdateRehearsalUrlEnvironment: source,
        }),
        throwsFormatException,
      );
    }
  });
}
