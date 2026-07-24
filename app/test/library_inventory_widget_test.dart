/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Library loading, inventory resilience, location navigation, filtering, project recovery, and reviewed external-Skill Source matching.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets(
    'Adoption Review matches exact names in one deduplicated batch Find',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const externalSkills = [
        InstalledSkill(
          inventoryKey: 'external:first',
          name: 'ask-matt',
          description: 'Route a request to the best matching skill.',
          path: '/tmp/first/ask-matt',
          agents: ['codex'],
          targetCount: 1,
          provenance: LibraryProvenance.external,
        ),
        InstalledSkill(
          inventoryKey: 'external:second',
          name: 'ask-matt',
          description: 'Route a request to the best matching skill.',
          path: '/tmp/second/ask-matt',
          agents: ['claude'],
          targetCount: 1,
          provenance: LibraryProvenance.external,
        ),
      ];
      final gateway = FakeSkillsGateway(
        libraryEntries: externalSkills,
        searchResults: const [
          SkillSummary(
            repositoryId: 'github.com/example/skills',
            installName: 'ask-matt',
            name: 'ask-matt',
            source: 'example/skills',
            latestVersion: 'v3.2.1',
            description: 'Route a request to the best matching skill.',
          ),
          SkillSummary(
            repositoryId: 'github.com/example/other',
            installName: 'another-skill',
            name: 'another-skill',
            source: 'example/other',
            latestVersion: 'v9',
            description: 'Unrelated candidate.',
          ),
        ],
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('library-adoption-review-enter')));
      await tester.pumpAndSettle();

      expect(gateway.queries, ['ask-matt']);
      expect(find.text('example/skills'), findsNWidgets(2));
      expect(find.text('v3.2.1'), findsNWidgets(2));
      expect(find.text('Confirm SkillsGo management (2)'), findsOneWidget);
      expect(find.text('Matching Source…'), findsNothing);
    },
  );

  testWidgets('Library renders a cold-load skeleton before CLI inspection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final library = Completer<List<InstalledSkill>>();
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(installed: false, libraryCompleter: library),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pump();

    expect(find.byKey(const ValueKey('library-skeleton')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    library.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library identifies malformed CLI data as local', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryError: const SkillsException(
            'invalid local Agent data',
            kind: SkillsFailureKind.invalidLocalData,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('Can’t read an installed skill'), findsOneWidget);
    expect(find.text('SkillsGo needs an update'), findsNothing);
  });

  testWidgets('Library refresh retains the last valid inventory', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);

    final refresh = Completer<List<InstalledSkill>>();
    gateway.libraryCompleter = refresh;
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refresh-local-library')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pump();

    expect(find.text('local-skill'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-skeleton')), findsNothing);
    refresh.completeError(const SkillsException('refresh failed'));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);
  });

  testWidgets('Library clears an Agent filter when that Agent disappears', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    final agents = <String>['codex'];
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(agentNames: agents)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);

    agents.clear();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refresh-local-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsNothing);
    expect(find.text('All Agents'), findsOneWidget);
  });

  testWidgets('Library lists a detected Agent with zero installed Skills', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          agentNames: const ['codex'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library exposes Global and Added Projects in a location rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      addedProjects: const [
        AddedProject(
          id: 'alpha',
          name: 'Project Alpha',
          path: '/work/alpha',
          accessState: ProjectAccessState.accessible,
        ),
      ],
      projectsToAdd: const [
        AddedProject(
          id: 'bravo',
          name: 'Project Bravo',
          path: '/work/bravo',
          accessState: ProjectAccessState.accessible,
        ),
        AddedProject(
          id: 'charlie',
          name: 'Project Charlie',
          path: '/work/charlie',
          accessState: ProjectAccessState.accessible,
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('All Skills'), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(libraryLocation('Project Alpha'), findsOneWidget);
    expect(find.byKey(const Key('library-project-filter')), findsNothing);
    final projectScroll = find.byKey(const Key('side-rail-scroll'));
    final projectScrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('side-rail-scrollbar')),
    );
    expect(projectScrollbar.thickness, 2);
    expect(projectScrollbar.radius, const Radius.circular(999));
    expect(
      find.descendant(
        of: projectScroll,
        matching: libraryLocation('All Skills'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: projectScroll, matching: libraryLocation('Global')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: libraryLocation('Project Alpha'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: find.byKey(const ValueKey('side-rail-header-divider')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: find.byKey(const ValueKey('side-rail-footer-divider')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: find.byKey(const Key('library-add-project')),
      ),
      findsNothing,
    );

    await tester.tap(libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('No Skills yet'), findsOneWidget);
    expect(find.text('Browse Skills'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-add-project')));
    await tester.pumpAndSettle();
    expect(find.text('Project Bravo'), findsWidgets);
    expect(find.text('Project Charlie'), findsWidgets);
    expect(find.text('No skills installed yet'), findsOneWidget);
  });

  testWidgets('Library project rail avoids duplicate macOS scrollbars', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.binding.setSurfaceSize(const Size(1200, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final projects = List.generate(
        16,
        (index) => AddedProject(
          id: 'project-$index',
          name: 'Project $index',
          path: '/work/project-$index',
          accessState: ProjectAccessState.accessible,
        ),
      );

      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(installed: false, addedProjects: projects),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      final explicitScrollbar = find.byKey(const Key('side-rail-scrollbar'));
      expect(explicitScrollbar, findsOneWidget);
      expect(
        find.descendant(
          of: explicitScrollbar,
          matching: find.byType(Scrollbar),
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('empty Added Project links directly to Discover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          addedProjects: const [
            AddedProject(
              id: 'alpha',
              name: 'Project Alpha',
              path: '/work/alpha',
              accessState: ProjectAccessState.accessible,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('No Skills yet'), findsOneWidget);
    expect(find.text('No Skills found in Project Alpha'), findsNothing);
    expect(
      find.text(
        'This project does not need Git or SkillsGo files. '
        'Install its first Skill when you are ready.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Browse Skills'));
    await tester.pumpAndSettle();

    expect(isSemanticallySelected(tester, 'Discover'), isTrue);
  });

  testWidgets('Library scrolls only the Added Project list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final projects = List.generate(
      16,
      (index) => AddedProject(
        id: 'project-$index',
        name: 'Project ${index.toString().padLeft(2, '0')}',
        path: '/work/project-$index',
        accessState: ProjectAccessState.accessible,
      ),
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(installed: false, addedProjects: projects),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('library-refresh')), findsNothing);

    final allSkills = libraryLocation('All Skills');
    final global = libraryLocation('Global');
    final addProject = find.byKey(const Key('library-add-project'));
    final firstProject = libraryLocation('Project 00');
    final scroll = find.byKey(const Key('side-rail-scroll'));
    final headerDivider = find.byKey(
      const ValueKey('side-rail-header-divider'),
    );
    final footerDivider = find.byKey(
      const ValueKey('side-rail-footer-divider'),
    );
    final allSkillsTop = tester.getTopLeft(allSkills);
    final globalTop = tester.getTopLeft(global);
    final addProjectTop = tester.getTopLeft(addProject);
    final headerDividerTop = tester.getTopLeft(headerDivider);
    final footerDividerTop = tester.getTopLeft(footerDivider);
    final firstProjectTop = tester.getTopLeft(firstProject);
    final allSkillsButton = find
        .ancestor(of: allSkills, matching: find.byType(TextButton))
        .first;
    final firstProjectButton = find
        .ancestor(of: firstProject, matching: find.byType(TextButton))
        .first;

    expect(tester.getSize(allSkillsButton).height, 44);
    expect(tester.getSize(firstProjectButton).height, 38);
    expect(tester.getSize(addProject).height, 44);

    await tester.tap(firstProject);
    await tester.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('rail-indicator'));
    expect(tester.getSize(indicator).height, 34);
    expect(
      tester.getSize(indicator).width,
      tester.getSize(firstProjectButton).width - 8,
    );

    await tester.drag(scroll, const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(allSkills), allSkillsTop);
    expect(tester.getTopLeft(global), globalTop);
    expect(tester.getTopLeft(addProject), addProjectTop);
    expect(tester.getTopLeft(headerDivider), headerDividerTop);
    expect(tester.getTopLeft(footerDivider), footerDividerTop);
    expect(tester.getTopLeft(firstProject).dy, lessThan(firstProjectTop.dy));
  });

  testWidgets('Library location rail filters Global and Project targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const project = AddedProject(
      id: 'alpha',
      name: 'Project Alpha',
      path: '/work/alpha',
      accessState: ProjectAccessState.accessible,
    );
    const globalSkill = InstalledSkill(
      inventoryKey: 'global-skill',
      name: 'global-skill',
      path: '/Users/test/.codex/skills/global-skill',
      agents: ['codex'],
      targetCount: 1,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: '/Users/test/.codex/skills/global-skill',
          version: 'v1',
        ),
      ],
    );
    const projectSkill = InstalledSkill(
      inventoryKey: 'project-skill',
      name: 'project-skill',
      path: '/work/alpha/.agents/skills/project-skill',
      agents: ['codex'],
      targetCount: 1,
      projects: ['/work/alpha'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work/alpha',
          path: '/work/alpha/.agents/skills/project-skill',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          addedProjects: const [project],
          libraryEntries: const [globalSkill, projectSkill],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('global-skill'), findsOneWidget);
    expect(find.text('project-skill'), findsOneWidget);

    await tester.tap(libraryLocation('Global'));
    await tester.pumpAndSettle();
    expect(find.text('global-skill'), findsOneWidget);
    expect(find.text('project-skill'), findsNothing);

    await tester.tap(libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('global-skill'), findsNothing);
    expect(find.text('project-skill'), findsOneWidget);
  });

  testWidgets('inaccessible Project stays visible and supports Relocate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      addedProjects: const [
        AddedProject(
          id: 'stable-id',
          name: 'Moved Project',
          path: '/Volumes/offline/project',
          accessState: ProjectAccessState.missing,
          diagnostic: 'volume offline',
        ),
      ],
      projectToRelocate: const AddedProject(
        id: 'stable-id',
        name: 'Moved Project',
        path: '/work/project',
        accessState: ProjectAccessState.accessible,
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(libraryLocation('Moved Project — unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Project directory is missing'), findsOneWidget);
    expect(find.textContaining('/Volumes/offline/project'), findsOneWidget);
    expect(find.textContaining('volume offline'), findsNothing);
    await tester.tap(find.text('Relocate').last);
    await tester.pumpAndSettle();
    expect(find.text('No Skills yet'), findsOneWidget);
    expect(find.text('Browse Skills'), findsOneWidget);
    expect(gateway.projects.single.id, 'stable-id');
    expect(gateway.projects.single.path, '/work/project');

    expect(find.text('Remove from List'), findsNothing);
  });
}
