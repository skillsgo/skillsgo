/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Library loading, icon-only local refresh, all-provenance Global inventory, inventory resilience, location navigation, filtering, project recovery, locally evidenced External Skills with separate Hub candidate matching, and Batch Adoption console geometry.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui' show ImageFilter, SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
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
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/first/ask-matt',
              version: '',
            ),
          ],
          provenance: LibraryProvenance.external,
          externalSource: ExternalSourceResolution(
            status: ExternalSourceStatus.confirmed,
            confidence: ExternalSourceConfidence.high,
            coordinate: 'github.com/example/original',
            url: 'https://github.com/example/original',
            evidence: [
              ExternalSourceEvidence(
                kind: ExternalSourceEvidenceKind.skillsShLock,
                confidence: ExternalSourceConfidence.high,
                location: '.agents/.skill-lock.json',
                coordinate: 'github.com/example/original',
                url: 'https://github.com/example/original',
                channel: 'skills.sh',
                reference: 'github',
              ),
            ],
          ),
        ),
        InstalledSkill(
          inventoryKey: 'external:second',
          name: 'ask-matt',
          description: 'Route a request to the best matching skill.',
          path: '/tmp/second/ask-matt',
          agents: ['claude'],
          targetCount: 1,
          targets: [
            SkillInstallationTarget(
              agent: 'claude',
              scope: InstallationScope.global,
              path: '/tmp/second/ask-matt',
              version: '',
            ),
          ],
          provenance: LibraryProvenance.external,
        ),
      ];
      final install = Completer<CommandResult>();
      final gateway = FakeSkillsGateway(
        libraryEntries: externalSkills,
        installCompleter: install,
        searchResults: const [
          SkillSummary(
            packagePath: 'github.com/example/skills',
            installName: 'ask-matt',
            name: 'ask-matt',
            latestVersion: 'v3.2.1',
            description: 'Route a request to the best matching skill.',
          ),
          SkillSummary(
            packagePath: 'github.com/example/other',
            installName: 'another-skill',
            name: 'another-skill',
            latestVersion: 'v9',
            description: 'Unrelated candidate.',
          ),
        ],
        sourceCandidates: const [
          AdoptionCandidate(
            packagePath: 'github.com/example/skills',
            name: 'ask-matt',
            path: 'skills/ask-matt',
            description: 'Route a request to the best matching skill.',
            versions: ['v3.2.1', 'v2.0.0', 'v1.0.0'],
            matchScore: 1,
            imageUrl: 'https://github.com/example.png?size=256',
          ),
          AdoptionCandidate(
            packagePath: 'github.com/example/skills-fork',
            name: 'ask-matt',
            path: 'skills/ask-matt',
            description: 'A less similar routing assistant.',
            versions: ['v1.0.0'],
            matchScore: .4,
          ),
          AdoptionCandidate(
            packagePath: 'github.com/example/skills-zh',
            name: 'ask-matt',
            path: 'skills/ask-matt',
            description: '询问哪项技能最适合当前情况。',
            versions: ['v1.0.0'],
            matchScore: 0,
          ),
        ],
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(libraryLocation('External Skills'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const Key('library-adoption-review-enter')))
            .height,
        tester
            .getSize(find.byKey(const Key('library-external-skills-logo')))
            .height,
      );
      await tester.tap(find.byKey(const Key('library-adoption-review-enter')));
      await tester.pumpAndSettle();

      expect(gateway.queries, ['ask-matt']);
      expect(
        find.descendant(
          of: find.byKey(const Key('library-adoption-column-header')),
          matching: find.text('Hub'),
        ),
        findsOneWidget,
      );
      final localSource = tester.widget<Text>(
        find.byKey(
          const ValueKey('library-adoption-local-source-external:first'),
        ),
      );
      expect(localSource.data, contains('github.com/example/original'));
      expect(find.text('example/skills'), findsNWidgets(2));
      expect(
        find.byKey(
          const ValueKey(
            'library-adoption-selected-package-avatar-github.com/example/skills',
          ),
        ),
        findsNWidgets(2),
      );
      expect(
        find.byKey(
          const ValueKey(
            'library-adoption-selected-source-match-github.com/example/skills',
          ),
        ),
        findsNWidgets(2),
      );
      final selectedAvatar = find
          .byKey(
            const ValueKey(
              'library-adoption-selected-package-avatar-github.com/example/skills',
            ),
          )
          .first;
      final selectedMatch = find
          .byKey(
            const ValueKey(
              'library-adoption-selected-source-match-github.com/example/skills',
            ),
          )
          .first;
      expect(
        (tester.getCenter(selectedAvatar).dy -
                tester.getCenter(selectedMatch).dy)
            .abs(),
        lessThan(1),
      );
      await tester.tap(
        find.byKey(const ValueKey('library-adoption-source-external:first')),
      );
      await tester.pumpAndSettle();
      final openSourceChevron = tester.widget<AnimatedRotation>(
        find
            .descendant(
              of: find.byKey(
                const ValueKey('library-adoption-source-external:first'),
              ),
              matching: find.byType(AnimatedRotation),
            )
            .last,
      );
      expect(openSourceChevron.turns, .5);
      final sourceAvatar = find.byKey(
        const ValueKey(
          'library-adoption-source-avatar-github.com/example/skills',
        ),
      );
      final sourceMatch = find.byKey(
        const ValueKey(
          'library-adoption-source-match-github.com/example/skills',
        ),
      );
      final zeroSourceMatch = find.byKey(
        const ValueKey(
          'library-adoption-source-match-github.com/example/skills-zh',
        ),
      );
      expect(sourceAvatar, findsOneWidget);
      expect(sourceMatch, findsOneWidget);
      expect(zeroSourceMatch, findsOneWidget);
      expect(find.text('100% match'), findsNWidgets(3));
      expect(find.text('0% match'), findsOneWidget);
      expect(tester.getSize(sourceMatch).width, 68);
      expect(tester.getSize(zeroSourceMatch).width, 68);
      expect(
        tester.getTopLeft(sourceMatch).dy,
        greaterThan(tester.getBottomLeft(sourceAvatar).dy),
      );
      expect(
        find.byKey(const ValueKey('adoption-dropdown-separator-1')),
        findsOneWidget,
      );
      final separator = tester.widget<Divider>(
        find.byKey(const ValueKey('adoption-dropdown-separator-1')),
      );
      expect(separator.indent, 12);
      expect(separator.endIndent, 12);
      final packageDescription = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'library-adoption-source-description-github.com/example/skills',
          ),
        ),
      );
      expect(packageDescription.maxLines, 2);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'library-adoption-source-avatar-github.com/example/skills',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('v3.2.1'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('library-adoption-version-external:first')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('library-adoption-version-external:first')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('v2.0.0').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('library-adoption-version-external:first'),
          ),
          matching: find.text('v2.0.0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('library-adoption-version-external:second'),
          ),
          matching: find.text('v2.0.0'),
        ),
        findsOneWidget,
      );
      expect(find.text('Confirm SkillsGo management (2/2)'), findsOneWidget);
      expect(find.text('Matching Source…'), findsNothing);

      await tester.tap(
        find.byKey(const Key('library-adoption-review-confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.byKey(const Key('batch-adoption-dialog')), findsOneWidget);
      expect(find.byKey(const Key('batch-adoption-skip')), findsNothing);
      expect(find.byKey(const Key('batch-adoption-confirm')), findsNothing);
      final importingButton = find.byKey(const Key('batch-adoption-importing'));
      expect(importingButton, findsOneWidget);
      expect(
        tester
            .getSemantics(importingButton)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(find.text('Importing…'), findsOneWidget);
      expect(
        find.byKey(const Key('batch-adoption-vintage-stickers')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-adoption-sticker-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-adoption-sticker-text')),
        findsOneWidget,
      );
      final stickerRow = tester.getRect(
        find.byKey(const Key('batch-adoption-vintage-stickers')),
      );
      final imageRegion = tester.getRect(
        find.byKey(const Key('batch-adoption-sticker-image-region')),
      );
      final controlRegion = tester.getRect(
        find.byKey(const Key('batch-adoption-control-region')),
      );
      final textRegion = tester.getRect(
        find.byKey(const Key('batch-adoption-sticker-text-region')),
      );
      expect(imageRegion.width, closeTo(controlRegion.width * 2, .01));
      expect(textRegion.width, closeTo(controlRegion.width * 2, .01));
      expect(controlRegion.center.dx, closeTo(stickerRow.center.dx, .01));
      expect(
        tester.getSize(find.byKey(const Key('batch-adoption-sticker-image'))),
        const Size(108, 76),
      );
      expect(
        tester.getSize(find.byKey(const Key('batch-adoption-sticker-text'))),
        const Size(146, 76),
      );
      final importingFace = tester.widget<DecoratedBox>(
        find.byKey(const Key('batch-adoption-confirm-face-decoration')),
      );
      final importingGradient =
          (importingFace.decoration as BoxDecoration).gradient;
      final refresh = Completer<List<InstalledSkill>>();
      gateway.libraryCompleter = refresh;
      install.complete(
        const CommandResult(
          command: ['skillsgo', 'add'],
          output: ProcessOutput(exitCode: 0, stdout: 'ok', stderr: ''),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        find.byKey(const Key('batch-adoption-close')),
        findsOneWidget,
        reason: 'Import completion must not wait for the story animation.',
      );
      refresh.complete([externalSkills.last]);
      await tester.pumpAndSettle();
      expect(gateway.installCalls, 2);
      expect(gateway.repositoryInstallCalls, 1);
      expect(gateway.adoptionRequests.single, hasLength(2));
      expect(find.byKey(const Key('batch-adoption-close')), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      final settlementValues = find.byKey(
        const Key('batch-adoption-stat-value'),
      );
      final settlementChecks = find.byKey(
        const Key('batch-adoption-benefit-check'),
      );
      expect(settlementValues, findsNWidgets(3));
      expect(settlementChecks, findsNWidgets(4));
      final statRightEdges = [
        for (var index = 0; index < 3; index++)
          tester.getTopRight(settlementValues.at(index)).dx,
      ];
      final checkRightEdges = [
        for (var index = 0; index < 4; index++)
          tester.getTopRight(settlementChecks.at(index)).dx,
      ];
      for (final rightEdge in [...statRightEdges, ...checkRightEdges]) {
        expect(rightEdge, closeTo(checkRightEdges.first, .01));
      }
      final completedFace = tester.widget<DecoratedBox>(
        find.byKey(const Key('batch-adoption-confirm-face-decoration')),
      );
      expect(
        (completedFace.decoration as BoxDecoration).gradient,
        importingGradient,
      );
      expect(
        gateway.installationSkillHistory.map((skill) => skill.packagePath),
        everyElement('github.com/example/skills'),
      );
      expect(gateway.installationVersionHistory, ['v2.0.0', 'v2.0.0']);
      expect(
        gateway.executionSelectionHistory.map(
          (targets) => targets.single.agent,
        ),
        ['codex', 'claude'],
      );
      await tester.tap(find.byKey(const Key('batch-adoption-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library-adoption-select-external:first')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('library-adoption-select-external:second')),
        findsOneWidget,
      );
      expect(find.text('Confirm SkillsGo management (1/1)'), findsOneWidget);
    },
  );

  testWidgets('Adoption actions pin as one group while managed rows scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      libraryEntries: [
        for (var index = 0; index < 10; index++)
          InstalledSkill(
            inventoryKey: 'external:sticky-$index',
            name: 'ask-matt',
            description: 'Route a request to the best matching skill.',
            path: '/tmp/sticky-$index/ask-matt',
            agents: const ['codex'],
            targetCount: 1,
            provenance: LibraryProvenance.external,
            targets: [
              SkillInstallationTarget(
                agent: 'codex',
                scope: InstallationScope.global,
                path: '/tmp/sticky-$index/ask-matt',
                version: '',
              ),
            ],
          ),
      ],
      sourceCandidates: const [
        AdoptionCandidate(
          packagePath: 'github.com/example/skills',
          name: 'ask-matt',
          path: 'skills/ask-matt',
          description: 'Route a request to the best matching skill.',
          versions: ['v1.0.0'],
        ),
      ],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(libraryLocation('External Skills'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SliverPersistentHeader>(find.byType(SliverPersistentHeader))
          .pinned,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('library-adoption-review-enter')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SliverPersistentHeader>(find.byType(SliverPersistentHeader))
          .pinned,
      isTrue,
    );
    final stickyAction = find.byKey(
      const Key('library-adoption-sticky-action'),
    );
    final initialTop = tester.getTopLeft(stickyAction).dy;
    expect(
      (tester.widget<DecoratedBox>(stickyAction).decoration as BoxDecoration)
          .gradient,
      isNull,
    );

    await tester.drag(
      find.byKey(const ValueKey('library-results')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(stickyAction).dy, closeTo(initialTop, .5));
    final pinnedDecoration =
        tester.widget<DecoratedBox>(stickyAction).decoration as BoxDecoration;
    expect(pinnedDecoration.gradient, isA<LinearGradient>());
    final glassGradient = pinnedDecoration.gradient! as LinearGradient;
    expect(glassGradient.colors.map((color) => color.a), [.56, .38]);
    expect(pinnedDecoration.borderRadius, isNull);
    expect(pinnedDecoration.border, isNull);
    expect(
      tester.getSize(stickyAction).width,
      tester
          .getSize(find.byKey(const ValueKey('adoption-configured-rows')))
          .width,
    );
    final glass = tester.widget<BackdropFilter>(
      find.ancestor(of: stickyAction, matching: find.byType(BackdropFilter)),
    );
    expect(glass.enabled, isTrue);
    expect(glass.filter, isA<ImageFilter>());
    expect(
      find.byKey(const Key('library-adoption-sticky-clip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-external-skills-logo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-adoption-review-exit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-adoption-review-confirm')),
      findsOneWidget,
    );
  });

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

  testWidgets('Library refresh icon reloads CLI-installed inventory in place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);

    final refresh = Completer<List<InstalledSkill>>();
    gateway.libraryCompleter = refresh;
    await tester.tap(find.byKey(const Key('library-refresh')));
    await tester.pump();

    expect(find.text('local-skill'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('library-refresh')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    refresh.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('local-skill'), findsNothing);
    expect(find.text('No skills installed yet'), findsOneWidget);
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

    expect(find.text('All Skills'), findsNothing);
    expect(libraryLocation('Global Skills'), findsOneWidget);
    expect(libraryLocation('External Skills'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(libraryLocation('Project Alpha'), findsOneWidget);
    expect(
      tester.getTopLeft(libraryLocation('Project Alpha')).dx,
      tester.getTopLeft(libraryLocation('Global Skills')).dx,
    );
    expect(find.byKey(const Key('library-project-filter')), findsNothing);
    final projectScroll = find.byKey(const Key('side-rail-scroll'));
    final projectScrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('side-rail-scrollbar')),
    );
    expect(projectScrollbar.thickness, 2);
    expect(projectScrollbar.radius, const Radius.circular(999));
    expect(
      find.descendant(of: projectScroll, matching: find.text('Projects')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: projectScroll,
        matching: libraryLocation('Global Skills'),
      ),
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

  testWidgets(
    'Global includes External Skills and External remains dedicated',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            libraryEntries: const [
              InstalledSkill(
                inventoryKey: 'managed',
                name: 'managed-skill',
                path: '/Users/test/.codex/skills/managed-skill',
                agents: ['codex'],
                targetCount: 1,
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.global,
                    path: '/Users/test/.codex/skills/managed-skill',
                    version: 'v1',
                  ),
                ],
              ),
              InstalledSkill(
                inventoryKey: 'external',
                name: 'external-skill',
                path: '/tmp/external-skill',
                agents: ['codex'],
                targetCount: 1,
                provenance: LibraryProvenance.external,
                targets: [
                  SkillInstallationTarget(
                    agent: 'codex',
                    scope: InstallationScope.global,
                    path: '/tmp/external-skill',
                    version: '',
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

      expect(find.text('managed-skill'), findsOneWidget);
      expect(find.text('external-skill'), findsOneWidget);

      await tester.tap(libraryLocation('External Skills'));
      await tester.pumpAndSettle();

      expect(find.text('managed-skill'), findsNothing);
      expect(find.text('external-skill'), findsOneWidget);
      final externalButton = find
          .ancestor(
            of: libraryLocation('External Skills'),
            matching: find.byType(TextButton),
          )
          .first;
      expect(
        tester
            .widget<HugeIcon>(
              find.descendant(
                of: externalButton,
                matching: find.byType(HugeIcon),
              ),
            )
            .icon,
        HugeIcons.strokeRoundedFolderUnknown,
      );
    },
  );

  testWidgets('empty Project section offers a centered inline add link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      installed: false,
      projectsToAdd: const [
        AddedProject(
          id: 'alpha',
          name: 'Project Alpha',
          path: '/work/alpha',
          accessState: ProjectAccessState.accessible,
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    final link = find.byKey(const Key('library-empty-add-project'));
    final rail = find.byKey(const Key('library-location-rail'));
    expect(link, findsOneWidget);
    expect(find.text('Go to Add Project'), findsOneWidget);
    expect(tester.getCenter(link).dx, closeTo(tester.getCenter(rail).dx, 1));
    expect(
      find.descendant(of: link, matching: find.byType(HugeIcon)),
      findsNothing,
    );
    expect(
      tester.widget<TextButton>(link).style?.textStyle?.resolve({})?.fontSize,
      11,
    );

    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(libraryLocation('Project Alpha'), findsOneWidget);
    expect(link, findsNothing);
  });

  testWidgets('Library location body uses the shared depth transition', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.pump();

    final body = find.byKey(const Key('skills-destination-body'));
    final fade = tester.widget<FadeTransition>(body);
    final slide = fade.child! as SlideTransition;
    final scale = slide.child! as ScaleTransition;
    expect(find.text('No Skills yet'), findsOneWidget);
    expect(fade.opacity.value, closeTo(.86, .001));
    expect(slide.position.value.dy, closeTo(.012, .001));
    expect(scale.scale.value, closeTo(.985, .001));

    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(slide.position.value, Offset.zero);
    expect(scale.scale.value, 1);
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

    expect(find.byKey(const Key('library-refresh')), findsOneWidget);

    final global = libraryLocation('Global Skills');
    final addProject = find.byKey(const Key('library-add-project'));
    final firstProject = libraryLocation('Project 00');
    final scroll = find.byKey(const Key('side-rail-scroll'));
    final headerDivider = find.byKey(
      const ValueKey('side-rail-header-divider'),
    );
    final footerDivider = find.byKey(
      const ValueKey('side-rail-footer-divider'),
    );
    final globalTop = tester.getTopLeft(global);
    final addProjectTop = tester.getTopLeft(addProject);
    final headerDividerTop = tester.getTopLeft(headerDivider);
    final footerDividerTop = tester.getTopLeft(footerDivider);
    final firstProjectTop = tester.getTopLeft(firstProject);
    final firstProjectButton = find
        .ancestor(of: firstProject, matching: find.byType(TextButton))
        .first;
    final globalButton = find
        .ancestor(of: global, matching: find.byType(TextButton))
        .first;

    expect(tester.getSize(globalButton).height, 38);
    expect(tester.getSize(firstProjectButton).height, 38);
    final globalIcon = find.descendant(
      of: globalButton,
      matching: find.byType(HugeIcon),
    );
    expect(
      tester.getCenter(globalIcon).dy,
      tester.getCenter(globalButton).dy - 1,
    );
    expect(tester.getCenter(global).dy, tester.getCenter(globalButton).dy);
    expect(
      tester.getCenter(firstProject).dy,
      tester.getCenter(firstProjectButton).dy - 1,
    );
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
          scope: InstallationScope.global,
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
    expect(find.text('project-skill'), findsNothing);
    expect(
      find.byKey(const ValueKey('library-scope-global-global-skill')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('library-scope-project-agents-alpha')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('library-scope-global-agents-global-skill')),
      findsOneWidget,
    );
    await tester.tap(libraryLocation('Global Skills'));
    await tester.pumpAndSettle();
    expect(find.text('global-skill'), findsOneWidget);
    expect(find.text('project-skill'), findsNothing);

    await tester.tap(libraryLocation('Project Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('global-skill'), findsNothing);
    expect(find.text('project-skill'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-scope-project-agents-alpha')),
      findsOneWidget,
    );
  });

  testWidgets('inaccessible Project stays visible without relocation', (
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
    expect(find.text('Relocate'), findsNothing);
    expect(find.text('Remove from List'), findsNothing);
  });
}
