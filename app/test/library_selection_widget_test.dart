/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Unified Library grouping, degraded Hub behavior, local detail diagnostics, and selection motion.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/subscription_segmented_switch.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
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
        inventoryKey: 'hub:github.com/acme/skills/-/hub-demo',
        name: 'hub-demo',
        path: '/work/alpha/.agents/skills/hub-demo',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'github.com/acme/skills/-/hub-demo',
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
      const localEntry = InstalledSkill(
        inventoryKey: 'local:private',
        name: 'private-local',
        path: '/Users/test/.codex/skills/private-local',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'local.skillsgo/abc/private-local',
        provenance: LibraryProvenance.local,
        versions: ['local-abc'],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/Users/test/.codex/skills/private-local',
            version: 'local-abc',
          ),
        ],
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [project],
        libraryEntries: const [hubEntry, localEntry],
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
      await tester.pumpAndSettle();
      await tester.tap(libraryLocation('Project Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Can’t connect to SkillsGo'), findsOneWidget);
      expect(find.text('hub-demo'), findsOneWidget);

      await tester.tap(libraryLocation('All Skills'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();
      expect(find.text('hub-demo'), findsOneWidget);
      expect(find.text('private-local'), findsOneWidget);
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
        inventoryKey: 'hub:github.com/example/skills/-/demo',
        name: 'demo',
        description: 'Coordinates reliable multi-Agent skill workflows.',
        skillId: 'github.com/example/skills/-/demo',
        path: '/Users/test/.codex/skills/demo',
        agents: ['claude-code', 'codex'],
        targetCount: 3,
        projects: ['/work/alpha', '/work/beta'],
        versions: ['v1', 'v2'],
        versionDivergence: true,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
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
              InstallationScope.user,
              InstallationScope.project,
            ],
          ),
          AgentStatus(
            id: 'claude-code',
            displayName: 'Claude Code',
            installed: true,
            supportedScopes: [
              InstallationScope.user,
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
      expect(
        find.byKey(const Key('library-scope-project-alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library-scope-project-beta')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('library-scope-project-alpha')))
            .dx,
        greaterThan(tester.getTopLeft(find.text('demo').first).dx),
      );
      final projectHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await projectHover.addPointer(
        location: tester.getCenter(
          find.byKey(const Key('library-scope-project-alpha')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('/work/alpha'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('copy-project-path-alpha')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const Key('copy-project-path-copied-alpha')),
        findsOneWidget,
      );
      await projectHover.moveTo(tester.getCenter(find.text('Claude Code')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('/work/alpha'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      await projectHover.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha'), findsNothing);
      expect(find.text('Claude Code'), findsNothing);
      await projectHover.removePointer();
      await tester.tap(find.byKey(const Key('library-agent-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Cursor'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(libraryLocation('Project Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Version divergence'), findsNothing);
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
      await tester.tap(find.byKey(const Key('installation-scope-toggle-user')));
      await tester.pumpAndSettle();
      expect(find.text('/work/alpha/.claude/skills/demo'), findsWidgets);
      expect(find.text('/Users/test/.codex/skills/demo'), findsWidgets);
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
      expect(find.byKey(const Key('library-update-filter')), findsOneWidget);
      expect(find.byType(SubscriptionSegmentedSwitch), findsOneWidget);
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
        inventoryKey: 'hub:github.com/example/skills/-/demo',
        name: 'demo',
        skillId: 'github.com/example/skills/-/demo',
        path: path,
        agents: ['codex'],
        targetCount: 1,
        versions: ['v1'],
        health: InstallationHealth.missing,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
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
      await tester.tap(find.byKey(const Key('installation-scope-toggle-user')));
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
                inventoryKey: 'hub:github.com/example/skills/-/demo',
                name: 'demo',
                skillId: 'github.com/example/skills/-/demo',
                path: '/Users/test/.codex/skills/demo',
                agents: ['codex'],
                targetCount: 1,
                versions: ['v1'],
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.user,
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
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      );
      const visibleKey = ValueKey('selection-bar-visible');
      await tester.tap(selection);
      await tester.pump();
      expect(find.byKey(visibleKey), findsOneWidget);
      final selectionBarSwitcher = find.byKey(
        const Key('library-selection-bar-switcher'),
      );
      expect(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(SlideTransition),
        ),
        findsWidgets,
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
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(FadeTransition),
        ),
      );
      expect(exitingFade.opacity.value, inExclusiveRange(.45, .6));
      await tester.tap(selection);
      await tester.pump();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    },
  );

  testWidgets(
    'Library selection toolbar removes translation for reduced motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            libraryEntries: const [
              InstalledSkill(
                inventoryKey: 'hub:github.com/example/skills/-/demo',
                name: 'demo',
                skillId: 'github.com/example/skills/-/demo',
                path: '/Users/test/.codex/skills/demo',
                agents: ['codex'],
                targetCount: 1,
                versions: ['v1'],
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.user,
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
      await tester.tap(
        find.byKey(
          const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
        ),
      );
      await tester.pump();

      final selectionBarSwitcher = find.byKey(
        const Key('library-selection-bar-switcher'),
      );
      expect(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: selectionBarSwitcher,
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    },
  );
}
