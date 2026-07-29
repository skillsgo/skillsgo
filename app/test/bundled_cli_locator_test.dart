/*
 * [INPUT]: Depends on the infrastructure bundled CLI locator and representative platform executable paths.
 * [OUTPUT]: Verifies the production CLI bundle contract for macOS, Windows, and Linux.
 * [POS]: Serves as the platform-path contract test for desktop App packaging.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/infrastructure/bundled_cli_locator.dart';

void main() {
  test('resolves the macOS app-bundle CLI', () {
    expect(
      bundledCliPathFor(
        operatingSystem: 'macos',
        executable: '/Applications/SkillsGo.app/Contents/MacOS/skillsgo',
      ),
      '/Applications/SkillsGo.app/Contents/Resources/bin/skillsgo',
    );
  });

  test('resolves the Windows data-bundle CLI', () {
    expect(
      bundledCliPathFor(
        operatingSystem: 'windows',
        executable: r'C:\Program Files\SkillsGo\skillsgo.exe',
      ),
      r'C:\Program Files\SkillsGo\data\bin\skillsgo.exe',
    );
  });

  test('resolves the Linux data-bundle CLI', () {
    expect(
      bundledCliPathFor(
        operatingSystem: 'linux',
        executable: '/opt/skillsgo/skillsgo',
      ),
      '/opt/skillsgo/data/bin/skillsgo',
    );
  });
}
