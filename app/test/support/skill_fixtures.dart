/*
 * [INPUT]: Depends on SkillsGateway domain values used by App and gateway-adjacent tests.
 * [OUTPUT]: Provides canonical immutable SkillDetail and successful CommandResult fixture transformations.
 * [POS]: Serves as the domain-fixture seam shared by rendered-test helpers and FakeSkillsGateway.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:skillsgo/domain/skills_gateway.dart';

SkillDetail withoutInstallationTargets(
  SkillDetail detail, {
  SkillRiskAssessment? riskAssessment,
}) => SkillDetail(
  name: detail.name,
  source: detail.source,
  markdown: detail.markdown,
  files: detail.files,
  installs: detail.installs,
  description: detail.description,
  requestedVersion: detail.requestedVersion,
  immutableVersion: detail.immutableVersion,
  commitSHA: detail.commitSHA,
  treeSHA: detail.treeSHA,
  sourceRef: detail.sourceRef,
  contentDigest: detail.contentDigest,
  trustLevel: detail.trustLevel,
  riskAssessment: riskAssessment ?? detail.riskAssessment,
  riskScannerVersion: detail.riskScannerVersion,
  riskEvidence: detail.riskEvidence,
  hubExecutableSignal: detail.hubExecutableSignal,
);

CommandResult successCommand(List<String> command) => CommandResult(
  command: command,
  output: const ProcessOutput(exitCode: 0, stdout: 'ok', stderr: ''),
);
