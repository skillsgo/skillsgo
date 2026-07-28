/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides direct Package update behavior and update availability checks for rendered tests.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewayUpdates on FakeSkillsGatewayCore {
  @override
  Future<void> updatePackage(
    InstalledSkill skill, {
    required String toVersion,
  }) async {
    updateCalls++;
    updatePackageHistory.add((
      packagePath: skill.packagePath,
      version: toVersion,
    ));
    if (updateError != null) throw updateError!;
    libraryEntries = libraryEntries
        ?.map(
          (entry) => entry.packagePath == skill.packagePath
              ? entry.withTargets([
                  for (final target in entry.targets)
                    SkillInstallationTarget(
                      agent: target.agent,
                      scope: target.scope,
                      path: target.path,
                      version: toVersion,
                      projectRoot: target.projectRoot,
                      health: target.health,
                    ),
                ])
              : entry,
        )
        .toList(growable: false);
  }
}
