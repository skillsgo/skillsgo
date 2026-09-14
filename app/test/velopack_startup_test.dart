/*
 * [INPUT]: Depends on the App entry point's official Velopack lifecycle-argument classifier.
 * [OUTPUT]: Proves all Velopack fast-exit hooks bypass normal UI startup without swallowing ordinary or malformed launches.
 * [POS]: Serves as the unit contract for installer/update lifecycle compatibility before native package smoke tests.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/main.dart' as app_entry;

void main() {
  test('recognizes every official Velopack fast-exit hook', () {
    for (final hook in const [
      '--veloapp-install',
      '--veloapp-obsolete',
      '--veloapp-updated',
      '--veloapp-uninstall',
    ]) {
      expect(app_entry.isVelopackFastExitInvocation([hook, '0.0.1']), isTrue);
    }
  });

  test('keeps ordinary and malformed launches on the normal startup path', () {
    expect(app_entry.isVelopackFastExitInvocation(const []), isFalse);
    expect(
      app_entry.isVelopackFastExitInvocation(const ['--veloapp-install']),
      isFalse,
    );
    expect(
      app_entry.isVelopackFastExitInvocation(const ['--version', '0.0.1']),
      isFalse,
    );
  });
}
