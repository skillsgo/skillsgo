/*
 * [INPUT]: Depends on platform-specific desktop bundle layouts and path normalization rules.
 * [OUTPUT]: Provides deterministic bundled SkillsGo CLI path resolution for macOS, Windows, and Linux.
 * [POS]: Serves as the shared packaging/runtime contract between desktop builds and DesktopSkillsGateway.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:path/path.dart' as p;

String bundledCliPathFor({
  required String operatingSystem,
  required String executable,
}) {
  final context = p.Context(
    style: operatingSystem == 'windows' ? p.Style.windows : p.Style.posix,
  );
  final executableDirectory = context.dirname(executable);
  return switch (operatingSystem) {
    'macos' => context.normalize(
      context.join(executableDirectory, '..', 'Resources', 'bin', 'skillsgo'),
    ),
    'windows' => context.normalize(
      context.join(executableDirectory, 'data', 'bin', 'skillsgo.exe'),
    ),
    'linux' => context.normalize(
      context.join(executableDirectory, 'data', 'bin', 'skillsgo'),
    ),
    _ => throw UnsupportedError(
      'SkillsGo does not support $operatingSystem desktop bundles.',
    ),
  };
}
