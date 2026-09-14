/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, clipboard services, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Library loading, local refresh, all-provenance inventory, one stable header, compact Package grouping, evidence-aware ranking, contribution actions and semantics, composable Global/Project filters and governance, permission-denied settings/retry recovery, responsive text scaling, inventory resilience, location navigation, reviewed External Source matching, and Adoption console geometry.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui' show ImageFilter, PointerDeviceKind, SemanticsAction, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('Library budget renders live analytics progress', (tester) async {
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'pending',
          name: 'pending',
          description: 'Pending usage',
          path: '/tmp/pending',
          packagePath: 'github.com/acme/skills',
          agents: ['codex'],
          targetCount: 1,
          usageState: SkillUsageState.loading,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/pending',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    gateway.emitAnalyticsProgress(
      const AnalyticsSyncProgress(
        revision: 1,
        phase: AnalyticsSyncPhase.syncing,
        sessionsDone: 3,
        sessionsTotal: 5,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('60% · 3/5'), findsOneWidget);
    final progress = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const Key('library-unused-budget-45-days')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(progress.value, .6);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('library-unused-budget-45-days')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Library budget follows context and toggles the 45-day usage filter',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      InstalledSkill skill(
        String name, {
        required int hits,
        required SkillUsageState usageState,
      }) => InstalledSkill(
        inventoryKey: name,
        name: name,
        description: 'Useful metadata',
        path: '/tmp/$name',
        packagePath: 'github.com/acme/skills',
        agents: const ['codex'],
        targetCount: 1,
        hits45Days: hits,
        hits90Days: hits,
        usageState: usageState,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/tmp/$name',
            version: 'v1',
          ),
        ],
      );
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            libraryEntries: [
              skill('unused', hits: 0, usageState: SkillUsageState.available),
              skill('active', hits: 3, usageState: SkillUsageState.available),
              skill(
                'unknown',
                hits: 0,
                usageState: SkillUsageState.unavailable,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library-budget-insights')), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('library-unused-budget-45-days')),
            )
            .label,
        contains('≥'),
      );

      await tester.enterText(find.byKey(const Key('library-search')), 'active');
      await tester.pumpAndSettle();
      final residentBefore = tester
          .getSemantics(find.byKey(const Key('library-unused-budget-45-days')))
          .label;
      await tester.enterText(find.byKey(const Key('library-search')), 'unused');
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('library-unused-budget-45-days')),
            )
            .label,
        residentBefore,
      );

      await tester.enterText(find.byKey(const Key('library-search')), '');
      await tester.tap(find.byKey(const Key('library-unused-budget-45-days')));
      await tester.pumpAndSettle();
      expect(find.text('unused'), findsWidgets);
      expect(find.text('active'), findsNothing);
      expect(find.text('unknown'), findsNothing);
      final selectedBudgetSemantics = find.ancestor(
        of: find.byKey(const Key('library-unused-budget-45-days')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected != null,
        ),
      );
      expect(
        tester.getSemantics(selectedBudgetSemantics).flagsCollection.isSelected,
        Tristate.isTrue,
      );

      await tester.tap(find.byKey(const Key('library-unused-budget-45-days')));
      await tester.pumpAndSettle();
      expect(find.text('active'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Library announces sort and usage evidence without color', (
    tester,
  ) async {
    String? copiedPrompt;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedPrompt =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    InstalledSkill skill(String name, SkillUsageState state, {int hits = 0}) =>
        InstalledSkill(
          inventoryKey: name,
          name: name,
          path: '/tmp/$name',
          packagePath: 'github.com/acme/skills',
          agents: const ['codex'],
          targetCount: 1,
          hits45Days: hits,
          hits90Days: hits,
          usageState: state,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/$name',
              version: 'v1',
            ),
          ],
        );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryEntries: [
            skill('zero', SkillUsageState.available),
            skill('loading', SkillUsageState.loading),
            skill('unavailable', SkillUsageState.unavailable),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('library-usage-45-zero')))
          .label,
      contains('45d: 0 calls'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('library-usage-45-loading')))
          .label,
      contains('45d: Counting'),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('library-usage-45-unavailable')),
          )
          .label,
      contains('45d: Usage unavailable'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('library-usage-45-unavailable')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const Key('library-usage-contribution-message')),
      findsOneWidget,
    );
    expect(find.textContaining('SkillsGo is open source'), findsOneWidget);
    expect(find.textContaining('cli/internal/skillusage'), findsNothing);
    expect(
      find.byKey(const Key('library-usage-copy-contribution-prompt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-usage-open-contribution-repository')),
      findsOneWidget,
    );
    final copyButton = tester.widget<TextButton>(
      find.byKey(const Key('library-usage-copy-contribution-prompt')),
    );
    copyButton.onPressed!();
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
    expect(copiedPrompt, contains('https://github.com/skillsgo/skillsgo'));
    expect(copiedPrompt, contains('cli/internal/skillusage'));
    expect(copiedPrompt, contains('Codex (codex)'));
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('library-sort-hits45Days')))
          .value,
      'Package grouped',
    );

    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('library-sort-hits45Days')))
          .value,
      'Descending',
    );
  });

  testWidgets('Library uses one stable header across compact Package groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 720));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    InstalledSkill skill(
      String name,
      String packagePath, {
      LibraryProvenance provenance = LibraryProvenance.hub,
    }) => InstalledSkill(
      inventoryKey: '$packagePath:$name',
      name: name,
      path: '/tmp/$name',
      packagePath: packagePath,
      provenance: provenance,
      agents: const ['codex'],
      targetCount: 1,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/tmp/$name',
          version: provenance == LibraryProvenance.hub ? 'v1' : '',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryEntries: [
            skill('alpha', 'github.com/acme/alpha-skills'),
            skill('beta', 'github.com/acme/beta-skills'),
            skill('local', '', provenance: LibraryProvenance.external),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('Skill'), findsOneWidget);
    expect(find.text('45d'), findsOneWidget);
    expect(find.text('90d'), findsOneWidget);
    expect(find.text('Installation'), findsOneWidget);
    expect(
      find.byKey(const Key('library-inventory-column-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('library-package-group-github.com/acme/alpha-skills'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('library-package-group-github.com/acme/beta-skills'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('library-content-count-all-skills')))
          .height,
      17,
    );
    final allSkillsCount = find.byKey(
      const Key('library-content-count-all-skills'),
    );
    expect(
      tester
          .getCenter(
            find.descendant(of: allSkillsCount, matching: find.text('3')),
          )
          .dy,
      closeTo(tester.getCenter(allSkillsCount).dy - 0.75, 0.1),
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey(
                'library-package-count-github.com/acme/alpha-skills',
              ),
            ),
          )
          .height,
      17,
    );
    final allSkills = find.byKey(const Key('library-content-all-skills'));
    final selectVisible = find.byKey(const Key('library-select-visible'));
    final inventoryHeader = find.byKey(
      const Key('library-inventory-column-header'),
    );
    final firstGroup = find.byKey(
      const Key('library-package-group-github.com/acme/alpha-skills'),
    );
    final firstRow = find.byKey(
      const Key('library-row-github.com/acme/alpha-skills:alpha'),
    );
    expect(
      tester.getBottomLeft(allSkills).dy,
      lessThan(tester.getTopLeft(inventoryHeader).dy),
    );
    expect(
      tester.getTopLeft(allSkills).dx,
      closeTo(tester.getTopLeft(selectVisible).dx, 1),
    );
    expect(
      tester.getBottomLeft(inventoryHeader).dy,
      lessThan(tester.getTopLeft(firstGroup).dy),
    );
    expect(
      tester.getBottomLeft(firstGroup).dy,
      lessThan(tester.getTopLeft(firstRow).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Library renders and sorts Codex usage columns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    InstalledSkill skill(String name, int hits45Days, int hits90Days) =>
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills:$name',
          name: name,
          path: '/tmp/$name',
          packagePath: 'github.com/example/skills',
          agents: const ['codex'],
          targetCount: 1,
          hits45Days: hits45Days,
          hits90Days: hits90Days,
          usageState: SkillUsageState.available,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/$name',
              version: 'v1',
            ),
          ],
        );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          language: AppLanguage.simplifiedChinese,
          libraryEntries: [skill('alpha', 2, 20), skill('beta', 8, 9)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('45 天调用'), findsOneWidget);
    expect(find.text('90 天调用'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('library-usage-45-hub:github.com/example/skills:alpha'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('library-usage-90-hub:github.com/example/skills:alpha'),
      ),
      findsOneWidget,
    );
    final theme = Theme.of(
      tester.element(find.byKey(const ValueKey('library-sort-hits45Days'))),
    );
    HugeIcon sortIcon(String window) => tester.widget<HugeIcon>(
      find.byKey(ValueKey('library-sort-icon-$window')),
    );
    expect(sortIcon('hits45Days').icon, HugeIcons.strokeRoundedSorting01);
    expect(sortIcon('hits45Days').color, theme.colorScheme.outline);
    expect(sortIcon('hits90Days').icon, HugeIcons.strokeRoundedSorting01);
    expect(sortIcon('hits90Days').color, theme.colorScheme.outline);

    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('beta')).dy,
      lessThan(tester.getTopLeft(find.text('alpha')).dy),
    );
    expect(sortIcon('hits45Days').icon, HugeIcons.strokeRoundedArrowDown01);
    expect(sortIcon('hits45Days').color, theme.colorScheme.primary);
    expect(sortIcon('hits90Days').icon, HugeIcons.strokeRoundedSorting01);
    expect(sortIcon('hits90Days').color, theme.colorScheme.outline);

    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('alpha')).dy,
      lessThan(tester.getTopLeft(find.text('beta')).dy),
    );
    expect(sortIcon('hits45Days').icon, HugeIcons.strokeRoundedArrowUp01);
    expect(sortIcon('hits45Days').color, theme.colorScheme.primary);

    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(sortIcon('hits45Days').icon, HugeIcons.strokeRoundedSorting01);
    expect(sortIcon('hits45Days').color, theme.colorScheme.outline);
    expect(find.text('example/skills'), findsOneWidget);
  });

  testWidgets('usage ranking preserves source and evidence semantics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    InstalledSkill skill(
      String name,
      String packagePath,
      int hits, {
      SkillUsageState usageState = SkillUsageState.available,
      LibraryProvenance provenance = LibraryProvenance.hub,
      String adoptionPackagePath = '',
    }) => InstalledSkill(
      inventoryKey: '$packagePath:$name:${usageState.name}',
      name: name,
      path: '/tmp/$name-${usageState.name}',
      packagePath: packagePath,
      adoptionPackagePath: adoptionPackagePath,
      provenance: provenance,
      agents: const ['codex'],
      targetCount: 1,
      hits45Days: hits,
      hits90Days: hits,
      usageState: usageState,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/tmp/$name-${usageState.name}',
          version: provenance == LibraryProvenance.hub ? 'v1' : '',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryEntries: [
            skill('same', 'github.com/acme/zeta', 4),
            skill('same', 'github.com/acme/alpha', 4),
            skill('zero', 'github.com/acme/zero', 0),
            skill(
              'loading',
              'github.com/acme/loading',
              99,
              usageState: SkillUsageState.loading,
            ),
            skill(
              'unavailable',
              'github.com/acme/unavailable',
              100,
              usageState: SkillUsageState.unavailable,
            ),
            skill(
              'external',
              '',
              2,
              provenance: LibraryProvenance.external,
              adoptionPackagePath: 'github.com/local/external-skills',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();

    double top(String inventoryKey) =>
        tester.getTopLeft(find.byKey(ValueKey('library-row-$inventoryKey'))).dy;
    expect(
      top('github.com/acme/alpha:same:available'),
      lessThan(top('github.com/acme/zeta:same:available')),
    );
    expect(
      top('github.com/acme/zero:zero:available'),
      lessThan(top('github.com/acme/loading:loading:loading')),
    );
    expect(
      top('github.com/acme/loading:loading:loading'),
      lessThan(top('github.com/acme/unavailable:unavailable:unavailable')),
    );
    expect(find.text('acme/alpha'), findsOneWidget);
    expect(
      find.text('Other Installation · local/external-skills'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(
      top('github.com/acme/zero:zero:available'),
      lessThan(top('github.com/acme/loading:loading:loading')),
    );

    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<HugeIcon>(
            find.byKey(const ValueKey('library-sort-icon-hits45Days')),
          )
          .icon,
      HugeIcons.strokeRoundedSorting01,
    );
  });

  testWidgets('Library filters only trustworthy 45/90-day unused Skills', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    InstalledSkill skill(
      String name, {
      required int hits45Days,
      required int hits90Days,
      SkillUsageState usageState = SkillUsageState.available,
    }) => InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:$name',
      name: name,
      path: '/tmp/$name',
      packagePath: 'github.com/example/skills',
      agents: const ['codex'],
      targetCount: 1,
      hits45Days: hits45Days,
      hits90Days: hits90Days,
      usageState: usageState,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/tmp/$name',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          language: AppLanguage.simplifiedChinese,
          libraryEntries: [
            skill('unused-90', hits45Days: 0, hits90Days: 0),
            skill('unused-45', hits45Days: 0, hits90Days: 3),
            skill('active', hits45Days: 2, hits90Days: 5),
            skill(
              'unknown',
              hits45Days: 0,
              hits90Days: 0,
              usageState: SkillUsageState.unavailable,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('筛选'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('45 天未调用'), findsOneWidget);
    expect(find.text('90 天未调用'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('library-usage-filter-unused45Days')),
    );
    await tester.pumpAndSettle();
    expect(find.text('unused-90'), findsOneWidget);
    expect(find.text('unused-45'), findsOneWidget);
    expect(find.text('active'), findsNothing);
    expect(find.text('unknown'), findsNothing);

    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('library-usage-filter-unused90Days')),
    );
    await tester.pumpAndSettle();
    expect(find.text('unused-90'), findsOneWidget);
    expect(find.text('unused-45'), findsNothing);
    expect(find.text('unknown'), findsNothing);
  });

  testWidgets('Library combines management usage Agent and search filters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(980, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    InstalledSkill skill(
      String name, {
      required String agent,
      required int hits,
      LibraryProvenance provenance = LibraryProvenance.hub,
    }) => InstalledSkill(
      inventoryKey: '$agent:$name',
      name: name,
      path: '/tmp/$name',
      packagePath: provenance == LibraryProvenance.hub
          ? 'github.com/acme/skills'
          : '',
      provenance: provenance,
      agents: [agent],
      targetCount: 1,
      hits45Days: hits,
      hits90Days: hits,
      usageState: SkillUsageState.available,
      targets: [
        SkillInstallationTarget(
          agent: agent,
          scope: InstallationScope.global,
          path: '/tmp/$name',
          version: provenance == LibraryProvenance.hub ? 'v1' : '',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          agentNames: const ['codex', 'claude-code'],
          libraryEntries: [
            skill('managed-unused-codex', agent: 'codex', hits: 0),
            skill('managed-active-codex', agent: 'codex', hits: 3),
            skill('managed-unused-claude', agent: 'claude-code', hits: 0),
            skill(
              'external-unused-codex',
              agent: 'codex',
              hits: 0,
              provenance: LibraryProvenance.external,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    final allManagement = find.byKey(
      const ValueKey('library-management-filter-all'),
    );
    expect(tester.getSize(allManagement).width, greaterThanOrEqualTo(196));
    expect(tester.getSize(allManagement).height, lessThanOrEqualTo(36));
    Color? menuBackground(Finder item) => tester
        .widget<MenuItemButton>(
          find.descendant(of: item, matching: find.byType(MenuItemButton)),
        )
        .style
        ?.backgroundColor
        ?.resolve({});
    expect(menuBackground(allManagement), Colors.transparent);
    await tester.tap(
      find.byKey(const ValueKey('library-management-filter-managed')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    expect(
      menuBackground(
        find.byKey(const ValueKey('library-management-filter-managed')),
      ),
      isNot(Colors.transparent),
    );
    await tester.tap(
      find.byKey(const ValueKey('library-usage-filter-unused45Days')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('library-filter'))).value,
      '2',
    );
    expect(find.text('managed-unused-codex'), findsOneWidget);
    expect(find.text('managed-unused-claude'), findsOneWidget);
    expect(find.text('managed-active-codex'), findsNothing);
    expect(find.text('external-unused-codex'), findsNothing);

    await tester.tap(find.byKey(const Key('library-agent-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('managed-unused-codex'), findsOneWidget);
    expect(find.text('managed-unused-claude'), findsNothing);

    await tester.enterText(librarySearchInput(), 'not-present');
    await tester.pumpAndSettle();
    expect(find.text('No matching Skills'), findsOneWidget);
  });

  testWidgets('Project context composes filtering ranking and governance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const project = AddedProject(
      id: 'alpha',
      name: 'Project Alpha',
      path: '/work/alpha',
      accessState: ProjectAccessState.accessible,
    );
    InstalledSkill skill(
      String name,
      int hits, {
      LibraryProvenance provenance = LibraryProvenance.hub,
    }) => InstalledSkill(
      inventoryKey: 'project:$name',
      name: name,
      path: '/work/alpha/.agents/skills/$name',
      packagePath: provenance == LibraryProvenance.hub
          ? 'github.com/acme/skills'
          : '',
      provenance: provenance,
      agents: const ['codex'],
      projects: const ['/work/alpha'],
      targetCount: 1,
      hits45Days: hits,
      hits90Days: hits,
      usageState: SkillUsageState.available,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work/alpha',
          path: '/work/alpha/.agents/skills/$name',
          version: provenance == LibraryProvenance.hub ? 'v1' : '',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          addedProjects: const [project],
          libraryEntries: [
            skill('managed-unused-project', 0),
            skill('managed-active-project', 5),
            skill(
              'external-unused-project',
              0,
              provenance: LibraryProvenance.external,
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

    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('library-management-filter-managed')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('library-usage-filter-unused45Days')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-sort-hits45Days')));
    await tester.pumpAndSettle();
    expect(find.text('managed-unused-project'), findsOneWidget);
    expect(find.text('managed-active-project'), findsNothing);
    expect(find.text('external-unused-project'), findsNothing);

    await tester.enterText(librarySearchInput(), 'does-not-match');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-content-needs-attention')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-attention-other-installation')),
    );
    await tester.pumpAndSettle();
    expect(find.text('external-unused-project'), findsOneWidget);
    expect(find.text('managed-unused-project'), findsNothing);
  });

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
        ),
        InstalledSkill(
          inventoryKey: 'external:second',
          name: 'ask-matt',
          description: 'Route a request to the best matching skill.',
          adoptionPackagePath: 'github.com/example/skills',
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
      await tester.pumpAndSettle();
      final provenanceIcon = find.byKey(
        const Key('library-external-skills-icon'),
      );
      expect(provenanceIcon, findsOneWidget);
      expect(
        tester.widget<HugeIcon>(provenanceIcon).icon,
        HugeIcons.strokeRoundedFolderOpen,
      );
      expect(find.text('Other Installation'), findsOneWidget);
      expect(
        find.byKey(const Key('library-external-skills-count')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('library-external-skills-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Manage existing skills'), findsOneWidget);
      expect(
        find.byKey(const Key('library-adoption-review-description')),
        findsOneWidget,
      );
      expect(
        tester.getTopRight(find.text('Other Installation')).dx,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const Key('library-adoption-review-enter')),
              )
              .dx,
        ),
      );
      await tester.tap(find.byKey(const Key('library-adoption-review-enter')));
      await tester.pumpAndSettle();

      expect(gateway.queries, ['ask-matt', 'ask-matt']);
      expect(gateway.sourceQueries.map((query) => query.packagePath), [
        '',
        'github.com/example/skills',
      ]);
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
      expect(
        find.byKey(const Key('library-adoption-confirmation-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library-adoption-confirmation-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library-adoption-confirmation-effects')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('batch-adoption-dialog')), findsNothing);
      await tester.tap(
        find.byKey(const Key('library-adoption-confirmation-cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('library-adoption-confirmation-dialog')),
        findsNothing,
      );
      expect(find.byKey(const Key('batch-adoption-dialog')), findsNothing);
      await tester.tap(
        find.byKey(const Key('library-adoption-review-confirm')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('library-adoption-confirmation-confirm')),
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

    expect(tester.getTopLeft(stickyAction).dy, lessThan(initialTop));
    expect(
      tester.getTopLeft(stickyAction).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const ValueKey('library-results'))).dy,
        .5,
      ),
    );
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
      find.byKey(const Key('library-external-skills-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-adoption-review-exit')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<HugeIcon>(
            find.byKey(const Key('library-adoption-review-cancel-icon')),
          )
          .icon,
      HugeIcons.strokeRoundedCancel01,
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

    final refreshCompleter = Completer<List<InstalledSkill>>();
    gateway.libraryCompleter = refreshCompleter;
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
     final refreshButton = find.byKey(const Key('refresh-local-library'));
     await tester.ensureVisible(refreshButton);
     await tester.tap(refreshButton);
    await tester.pump();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pump();

    expect(find.text('local-skill'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-skeleton')), findsNothing);
     refreshCompleter.completeError(const SkillsException('refresh failed'));
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
     final refresh = find.byKey(const Key('refresh-local-library'));
     await tester.ensureVisible(refresh);
     await tester.tap(refresh);
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
    expect(libraryLocation('Global Skills'), findsOneWidget);
    expect(libraryLocation('External Skills'), findsNothing);
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
    'Global includes managed and local existing Skills without a dedicated External route',
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
      expect(libraryLocation('External Skills'), findsNothing);

      await tester.tap(find.byKey(const Key('library-filter-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Management status'), findsOneWidget);
      expect(find.text('Usage status'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('library-management-filter-managed')),
      );
      await tester.pumpAndSettle();
      expect(find.text('managed-skill'), findsOneWidget);
      expect(find.text('external-skill'), findsNothing);

      await tester.tap(find.byKey(const Key('library-filter-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('library-management-filter-otherInstallation'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('managed-skill'), findsNothing);
      expect(find.text('external-skill'), findsOneWidget);
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

  testWidgets('permission-denied Project offers settings and retry recovery', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      installed: false,
      addedProjects: const [
        AddedProject(
          id: 'permission-denied',
          name: 'Private Project',
          path: '/Users/test/Documents/private-project',
          accessState: ProjectAccessState.permissionDenied,
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(libraryLocation('Private Project — unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Project permission is required'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final projectLoadsBeforeRetry = gateway.projectLoads;
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(gateway.localScanPrivacySettingsOpens, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(gateway.projectLoads, greaterThan(projectLoadsBeforeRetry));
    debugDefaultTargetPlatformOverride = null;
  });

  for (final failure in <({String name, bool result, Object? error})>[
    (name: 'false result', result: false, error: null),
    (name: 'exception', result: true, error: StateError('launch failed')),
  ]) {
    testWidgets(
      'permission settings ${failure.name} shows inline recovery copy',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gateway = FakeSkillsGateway(
          installed: false,
          localScanPrivacySettingsResult: failure.result,
          localScanPrivacySettingsError: failure.error,
          addedProjects: const [
            AddedProject(
              id: 'permission-denied',
              name: 'Private Project',
              path: '/Users/test/Documents/private-project',
              accessState: ProjectAccessState.permissionDenied,
            ),
          ],
        );

        await tester.pumpWidget(SkillsGoApp(gateway: gateway));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('primary-destination-library')));
        await tester.pumpAndSettle();
        await tester.tap(libraryLocation('Private Project — unavailable'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Couldn’t open System Settings. Open it manually, then try again.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('permission recovery hides macOS settings action on Windows', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      installed: false,
      addedProjects: const [
        AddedProject(
          id: 'permission-denied',
          name: 'Private Project',
          path: r'C:\Users\test\Documents\private-project',
          accessState: ProjectAccessState.permissionDenied,
        ),
      ],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(libraryLocation('Private Project — unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
