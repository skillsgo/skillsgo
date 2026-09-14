/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Unified Library grouping, exact location target projection, degraded Hub behavior, query-transition selection reset, All Skills governance-state restoration, stable Other Installation entry isolation, External diagnostics, and selection motion.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('switching the Library location clears selected Skills', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const project = AddedProject(
      id: 'alpha',
      name: 'Project Alpha',
      path: '/work/alpha',
      accessState: ProjectAccessState.accessible,
    );
    const entry = InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:demo',
      name: 'demo',
      packagePath: 'github.com/example/skills',
      path: '/Users/test/.codex/skills/demo',
      agents: ['codex'],
      targetCount: 2,
      projects: ['/work/alpha'],
      versions: ['v1'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/Users/test/.codex/skills/demo',
          version: 'v1',
        ),
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work/alpha',
          path: '/work/alpha/.agents/skills/demo',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          addedProjects: const [project],
          libraryEntries: const [entry],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    const selectionKey = ValueKey(
      'library-select-hub:github.com/example/skills:demo',
    );
    await tester.tap(find.byKey(selectionKey));
    await tester.pump();
    expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);

    await tester.tap(libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectionKey)).value,
      isFalse,
    );
    expect(find.byKey(const Key('library-selection-bar')), findsNothing);
  });

  testWidgets(
    'Library query transitions clear Skills hidden from pending removal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const entry = InstalledSkill(
        inventoryKey: 'hub:github.com/example/skills:demo',
        name: 'demo',
        packagePath: 'github.com/example/skills',
        path: '/Users/test/.codex/skills/demo',
        agents: ['codex'],
        targetCount: 1,
        versions: ['v1'],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/Users/test/.codex/skills/demo',
            version: 'v1',
          ),
        ],
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            agentNames: const ['codex'],
            libraryEntries: const [entry],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      const selectionKey = ValueKey(
        'library-select-hub:github.com/example/skills:demo',
      );
      Future<void> selectSkill() async {
        await tester.tap(find.byKey(selectionKey));
        await tester.pump();
        expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
      }

      Future<void> expectSelectionCleared() async {
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('library-selection-bar')), findsNothing);
      }

      await selectSkill();
      await tester.enterText(librarySearchInput(), 'not-present');
      await expectSelectionCleared();
      await tester.enterText(librarySearchInput(), '');
      await tester.pumpAndSettle();

      await selectSkill();
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await expectSelectionCleared();
      await tester.tap(find.text('All Agents'));
      await tester.pumpAndSettle();

      await selectSkill();
      await tester.tap(find.byKey(const Key('library-filter-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('library-management-filter-managed')),
      );
      await expectSelectionCleared();

      await selectSkill();
      await tester.tap(find.byKey(const Key('library-filter-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('library-usage-filter-unused45Days')),
      );
      await expectSelectionCleared();
    },
  );

  testWidgets('Needs Attention restores the prior All Skills query context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    InstalledSkill skill(int index) => InstalledSkill(
      inventoryKey: 'github.com/acme/skills:skill-$index',
      name: 'skill-$index',
      path: '/tmp/skill-$index',
      packagePath: 'github.com/acme/skills',
      agents: const ['codex'],
      targetCount: 1,
      hits45Days: index,
      hits90Days: index,
      usageState: SkillUsageState.available,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/tmp/skill-$index',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          agentNames: const ['codex'],
          libraryEntries: [
            for (var index = 0; index < 30; index++) skill(index),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.enterText(librarySearchInput(), 'skill');
    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('library-management-filter-managed')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('library-results')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('library-results')),
      matching: find.byType(Scrollable),
    );
    final originalOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(originalOffset, greaterThan(0));

    await tester.tap(find.byKey(const Key('library-content-needs-attention')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-needs-attention-body')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('library-attention-unused')), findsOneWidget);
    expect(
      find.byKey(const Key('library-attention-other-installation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('library-attention-updates')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-content-all-skills')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(librarySearchInput()).controller.text,
      'skill',
    );
    expect(find.text('Codex'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('library-filter'))).value,
      '1',
    );
    expect(
      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey('library-results')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels,
      closeTo(originalOffset, .5),
    );
  });

  testWidgets(
    'Other Installation governance survives search and isolates selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const managed = InstalledSkill(
        inventoryKey: 'managed',
        name: 'managed-skill',
        path: '/tmp/managed',
        packagePath: 'github.com/acme/skills',
        agents: ['codex'],
        targetCount: 1,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/tmp/managed',
            version: 'v1',
          ),
        ],
      );
      const external = InstalledSkill(
        inventoryKey: 'external',
        name: 'external-skill',
        path: '/tmp/external',
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/tmp/external',
            version: '',
          ),
        ],
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(libraryEntries: const [managed, external]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.enterText(librarySearchInput(), 'managed');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-select-managed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('library-content-needs-attention')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsNothing);
      await tester.tap(
        find.byKey(const Key('library-attention-other-installation')),
      );
      await tester.pumpAndSettle();
      expect(find.text('external-skill'), findsOneWidget);
      expect(
        find.byKey(const Key('library-adoption-review-enter')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('library-adoption-review-enter')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('library-content-all-skills')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(librarySearchInput()).controller.text,
        'managed',
      );
      expect(find.text('managed-skill'), findsOneWidget);
      expect(find.text('external-skill'), findsNothing);
      expect(find.byKey(const Key('library-selection-bar')), findsNothing);
    },
  );

  testWidgets('Project selection removes only the projected Project target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const project = AddedProject(
      id: 'alpha',
      name: 'Project Alpha',
      path: '/work/alpha',
      accessState: ProjectAccessState.accessible,
    );
    const entry = InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:demo',
      name: 'demo',
      packagePath: 'github.com/example/skills',
      path: '/Users/test/.codex/skills/demo',
      agents: ['codex'],
      targetCount: 2,
      projects: ['/work/alpha'],
      versions: ['v1'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/Users/test/.codex/skills/demo',
          version: 'v1',
        ),
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work/alpha',
          path: '/work/alpha/.agents/skills/demo',
          version: 'v1',
        ),
      ],
    );
    final gateway = FakeSkillsGateway(
      installed: false,
      addedProjects: const [project],
      libraryEntries: const [entry],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills:demo'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('library-remove-selected')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('library-remove-selected')));
    await tester.pumpAndSettle();

    expect(gateway.managementTargetHistory, hasLength(1));
    expect(gateway.managementTargetHistory.single.keys, hasLength(1));
    expect(
      gateway.managementTargetHistory.single.keys.single,
      contains('/work/alpha/.agents/skills/demo'),
    );
    expect(gateway.libraryEntries, hasLength(1));
    expect(
      gateway.libraryEntries!.single.targets.single.scope,
      InstallationScope.global,
    );
  });

  testWidgets(
    'Hub outage never empties the selected Project or local Agent views',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const project = AddedProject(
        id: 'alpha',
        name: 'Project Alpha',
        path: '/work/alpha',
        accessState: ProjectAccessState.accessible,
      );
      const hubEntry = InstalledSkill(
        inventoryKey: 'hub:github.com/acme/skills:hub-demo',
        name: 'hub-demo',
        path: '/work/alpha/.agents/skills/hub-demo',
        agents: ['codex'],
        targetCount: 1,
        packagePath: 'github.com/acme/skills',
        projects: ['/work/alpha'],
        versions: ['v1'],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.project,
            projectRoot: '/work/alpha',
            path: '/work/alpha/.agents/skills/hub-demo',
            version: 'v1',
          ),
        ],
      );
      const externalEntry = InstalledSkill(
        inventoryKey: 'external:private',
        name: 'private-external',
        path: '/Users/test/.codex/skills/private-local',
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/Users/test/.codex/skills/private-local',
            version: '',
          ),
        ],
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [project],
        libraryEntries: const [hubEntry, externalEntry],
        updateCheckErrors: const [
          SkillsException(
            'network unavailable',
            kind: SkillsFailureKind.offline,
            isOffline: true,
          ),
        ],
        reminderSettings: const ReminderSettings(
          updateAvailable: true,
          securityAdvisory: false,
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(libraryLocation('Project Alpha'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Can’t connect to SkillsGo'), findsOneWidget);
      expect(find.text('hub-demo'), findsOneWidget);

      await tester.tap(libraryLocation('Global Skills'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();
      expect(find.text('hub-demo'), findsNothing);
      expect(find.text('private-external'), findsOneWidget);
    },
  );

  testWidgets(
    'unified Library summarizes and filters multi-location multi-Agent targets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const alpha = AddedProject(
        id: 'alpha',
        name: 'Project Alpha',
        path: '/work/alpha',
        accessState: ProjectAccessState.accessible,
      );
      const beta = AddedProject(
        id: 'beta',
        name: 'Project Beta',
        path: '/work/beta',
        accessState: ProjectAccessState.accessible,
      );
      const entry = InstalledSkill(
        inventoryKey: 'hub:github.com/example/skills:demo',
        name: 'demo',
        description: 'Coordinates reliable multi-Agent skill workflows.',
        packagePath: 'github.com/example/skills',
        path: '/Users/test/.codex/skills/demo',
        agents: ['claude-code', 'codex'],
        targetCount: 3,
        projects: ['/work/alpha', '/work/beta'],
        versions: ['v1', 'v2'],
        versionDivergence: true,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/Users/test/.codex/skills/demo',
            version: 'v1',
          ),
          SkillInstallationTarget(
            agent: 'claude-code',
            scope: InstallationScope.project,
            projectRoot: '/work/alpha',
            path: '/work/alpha/.claude/skills/demo',
            version: 'v2',
          ),
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.project,
            projectRoot: '/work/beta',
            path: '/work/beta/.agents/skills/demo',
            version: 'v2',
          ),
        ],
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [alpha, beta],
        libraryEntries: const [entry],
        agentStatuses: const [
          AgentStatus(
            id: 'codex',
            displayName: 'Codex',
            installed: true,
            supportedScopes: [
              InstallationScope.global,
              InstallationScope.project,
            ],
          ),
          AgentStatus(
            id: 'claude-code',
            displayName: 'Claude Code',
            installed: true,
            supportedScopes: [
              InstallationScope.global,
              InstallationScope.project,
            ],
          ),
          AgentStatus(
            id: 'cursor',
            displayName: 'Cursor',
            installed: true,
            supportedScopes: [InstallationScope.project],
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      expect(find.text('Version divergence'), findsNothing);
      expect(find.text('/Users/test/.codex/skills/demo'), findsNothing);
      expect(find.byTooltip('Codex'), findsOneWidget);
      expect(find.byTooltip('Claude Code'), findsNothing);
      expect(libraryLocation('Project Alpha'), findsOneWidget);
      expect(libraryLocation('Project Beta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Cursor'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(libraryLocation('Project Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Version divergence'), findsNothing);
      expect(find.byTooltip('Claude Code'), findsOneWidget);
      expect(find.byTooltip('Codex'), findsNothing);
      expect(
        find.byKey(const Key('library-scope-project-agents-alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'library-scope-global-agents-hub:github.com/example/skills:demo',
          ),
        ),
        findsNothing,
      );
      final projectHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await projectHover.addPointer(
        location: tester.getCenter(
          find.byKey(const Key('library-scope-project-agents-alpha')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('/work/alpha'), findsOneWidget);
      expect(find.text('Claude Code'), findsWidgets);
      await tester.tap(find.byKey(const Key('copy-project-path-alpha')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const Key('copy-project-path-copied-alpha')),
        findsOneWidget,
      );
      await projectHover.moveTo(
        tester.getCenter(find.text('Claude Code').last),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('/work/alpha'), findsOneWidget);
      expect(find.text('Claude Code'), findsWidgets);
      await projectHover.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha'), findsNothing);
      expect(find.text('Claude Code'), findsNothing);
      await projectHover.removePointer();
      await tester.tap(find.text('demo').first);
      await tester.pump();
      final openingDetail = tester.widget<SlideTransition>(
        find.byKey(const Key('library-detail-surface')),
      );
      expect(openingDetail.position.value.dx, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-detail-surface')), findsOneWidget);
      expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('installation-scope-toggle-project:/work/alpha')),
      );
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha/.claude/skills/demo'), findsWidgets);
      expect(find.text('/Users/test/.codex/skills/demo'), findsNothing);
      expect(
        find.byKey(const Key('installed-detail-compact-identity')),
        findsNothing,
      );
      await tester.binding.setSurfaceSize(const Size(1200, 500));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('installed-detail-scroll-view')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('installed-detail-compact-identity')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back to Library'));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpAndSettle();

      final librarySearch = tester.widget<SkillSearchField>(
        find.byKey(const Key('library-search')),
      );
      expect(librarySearch.appearance, SkillSearchAppearance.leaderboard);
      expect(find.byKey(const Key('library-filter')), findsOneWidget);
      expect(find.text('Add Project'), findsOneWidget);
      expect(find.text('Check updates'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      await tester.enterText(librarySearchInput(), 'not-present');
      await tester.pumpAndSettle();
      expect(find.text('No matching Skills'), findsOneWidget);
      await tester.enterText(librarySearchInput(), 'demo');
      await tester.pumpAndSettle();
      expect(find.text('demo'), findsWidgets);
    },
  );

  testWidgets(
    'local detail keeps target diagnostics visible when reading fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const path = '/missing/.codex/skills/demo';
      const entry = InstalledSkill(
        inventoryKey: 'hub:github.com/example/skills:demo',
        name: 'demo',
        packagePath: 'github.com/example/skills',
        path: path,
        agents: ['codex'],
        targetCount: 1,
        versions: ['v1'],
        health: InstallationHealth.missing,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: path,
            version: 'v1',
            health: InstallationHealth.missing,
          ),
        ],
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            libraryEntries: const [entry],
            localDetailError: const SkillsException('cannot read'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('demo').first);
      await tester.pumpAndSettle();

      expect(find.text(path), findsNothing);
      expect(find.text('Target missing'), findsNothing);
      await tester.tap(
        find.byKey(const Key('installation-scope-toggle-global')),
      );
      await tester.pumpAndSettle();
      expect(find.text(path), findsOneWidget);
      expect(find.text('Target missing'), findsOneWidget);
      expect(find.text('Can’t read this Skill'), findsOneWidget);
    },
  );

  testWidgets(
    'Library selection toolbar springs through entrance, exit, and reversal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            libraryEntries: const [
              InstalledSkill(
                inventoryKey: 'hub:github.com/example/skills:demo',
                name: 'demo',
                packagePath: 'github.com/example/skills',
                path: '/Users/test/.codex/skills/demo',
                agents: ['codex'],
                targetCount: 1,
                versions: ['v1'],
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.global,
                    path: '/Users/test/.codex/skills/demo',
                    version: 'v1',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      final selection = find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills:demo'),
      );
      const visibleKey = ValueKey('selection-bar-visible');
      await tester.tap(selection);
      await tester.pump();
      expect(find.byKey(visibleKey), findsOneWidget);
      expect(
        find.byKey(const Key('library-selection-bar-slide-transition')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);

      await tester.tap(find.byTooltip('Clear selection'));
      await tester.pump();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsNothing);

      await tester.tap(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear selection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final exitingFade = tester.widget<FadeTransition>(
        find.byKey(const Key('library-selection-bar-fade-transition')),
      );
      expect(exitingFade.opacity.value, inExclusiveRange(.45, .6));
      await tester.tap(selection);
      await tester.pump();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    },
  );
}
