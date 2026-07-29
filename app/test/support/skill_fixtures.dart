/*
 * [INPUT]: Depends on SkillsGateway domain values used by App and gateway-adjacent tests.
 * [OUTPUT]: Provides canonical immutable SkillDetail and successful CommandResult fixture transformations.
 * [POS]: Serves as the domain-fixture seam shared by rendered-test helpers and FakeSkillsGateway.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:skillsgo/domain/skills_gateway.dart';

SkillDetail withoutInstallationTargets(SkillDetail detail) => SkillDetail(
  name: detail.name,
  path: detail.path,
  content: detail.content,
  packagePath: detail.packagePath,
  version: detail.version,
  time: detail.time,
  description: detail.description,
);

CommandResult successCommand(List<String> command) => CommandResult(
  command: command,
  output: const ProcessOutput(exitCode: 0, stdout: 'ok', stderr: ''),
);
