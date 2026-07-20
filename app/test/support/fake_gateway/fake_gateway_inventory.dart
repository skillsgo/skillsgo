/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides installed inventory, local detail, and update-state inspection behavior.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewayInventory on FakeSkillsGatewayCore {
  @override
  Future<List<InstalledSkill>> listInstalled({
    List<AddedProject> projects = const [],
  }) async => libraryError != null
      ? throw libraryError!
      : await libraryCompleter?.future ??
            libraryEntries ??
            (installed
                ? [
                    InstalledSkill(
                      inventoryKey: 'hub:github.com/test/skills/-/local-skill',
                      name: 'local-skill',
                      path: '/tmp/local-skill',
                      agents: agentNames,
                      targetCount: agentNames.length,
                      skillId: 'github.com/test/skills/-/local-skill',
                      versions: const ['v1'],
                      targets: [
                        for (final agent in agentNames)
                          SkillInstallationTarget(
                            agent: agent,
                            scope: InstallationScope.user,
                            path: '/tmp/local-skill',
                            version: 'v1',
                          ),
                      ],
                    ),
                  ]
                : const []);
  @override
  Future<AgentCatalog> inspectOnboardingAgents() => inspectAgents();

  @override
  Future<AgentCatalog> inspectAgents() async {
    agentInspections++;
    if (agentInspectionError != null) throw agentInspectionError!;
    final pending = agentInspectionCompleter;
    if (pending != null) return pending.future;
    return AgentCatalog(
      schemaVersion: 1,
      agents:
          agentStatuses ??
          agentNames
              .map(
                (agent) => AgentStatus(
                  id: agent,
                  displayName: agent
                      .split(RegExp(r'[-_]'))
                      .where((part) => part.isNotEmpty)
                      .map(
                        (part) =>
                            '${part[0].toUpperCase()}${part.substring(1)}',
                      )
                      .join(' '),
                  installed: true,
                  supportedScopes: const [
                    InstallationScope.project,
                    InstallationScope.user,
                  ],
                  userTarget: AgentUserTarget(
                    path: '/Users/test/.$agent/skills',
                    exists: true,
                  ),
                ),
              )
              .toList(growable: false),
    );
  }

  @override
  Future<List<AddedProject>> loadAddedProjects() async {
    projectLoads++;
    return await projectLoadCompleter?.future ?? List.of(projects);
  }

  @override
  Future<AddedProject> resolveProjectIcon(AddedProject project) async =>
      project;
  @override
  Future<List<AddedProject>> addProjects() async {
    for (final project in projectsToAdd) {
      if (!projects.any((item) => item.id == project.id)) {
        projects.add(project);
      }
    }
    return List.of(projectsToAdd);
  }

  @override
  Future<AddedProject?> relocateProject(String id) async {
    final project = projectToRelocate;
    if (project == null || project.id != id) return null;
    final index = projects.indexWhere((item) => item.id == id);
    if (index >= 0) projects[index] = project;
    return project;
  }

  @override
  Future<void> removeProject(String id) async {
    projects.removeWhere((project) => project.id == id);
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async {
    if (localDetailError != null) throw localDetailError!;
    return localDetail ??
        SkillDetail(
          name: 'local-skill',
          source: 'Local',
          markdown: '# Local',
          immutableVersion: skill.versions.length == 1
              ? skill.versions.single
              : '',
          files: const [SkillFile(path: 'SKILL.md', contents: '# Local')],
          installationTargets: skill.targets,
        );
  }

  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async {
    if (updateCheckErrors.isNotEmpty) throw updateCheckErrors.removeAt(0);
    return {
      for (final skill in skills)
        (skill.inventoryKey.isEmpty ? skill.name : skill.inventoryKey):
            updateState,
    };
  }
}
