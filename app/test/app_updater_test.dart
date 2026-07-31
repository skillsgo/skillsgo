/*
 * [INPUT]: Depends on the App updater's unsigned rehearsal-source parser.
 * [OUTPUT]: Proves the CI update escape hatch accepts only explicit loopback HTTP feeds and remains absent during ordinary launches.
 * [POS]: Serves as the security and configuration contract for real packaged update rehearsals before native E2E coverage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/infrastructure/app_updater.dart';

void main() {
  test('ordinary launches have no rehearsal update source', () {
    expect(appUpdateRehearsalSource(const {}), isNull);
    expect(
      appUpdateRehearsalSource(const {appUpdateRehearsalUrlEnvironment: '   '}),
      isNull,
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
