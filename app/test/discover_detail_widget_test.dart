/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Discover card installation entry points, remote detail evidence, motion, and theme behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/agent_logo.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets(
    'desktop pull refresh keeps content and uses the ink-drop loader',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final initial = Completer<DiscoveryPage>()
        ..complete(
          const DiscoveryPage(
            skills: [
              SkillSummary(
                id: 'github.com/acme/original',
                installName: 'original',
                name: 'Original',
                source: 'github.com/acme/original',
                installs: 2,
              ),
            ],
          ),
        );
      final refresh = Completer<DiscoveryPage>();
      final gateway = FakeSkillsGateway(
        discoveryCompleters: [initial, refresh],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('discover-results-hot'))),
      );
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(const Offset(0, 55));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Original'), findsOneWidget);
      expect(find.byKey(const Key('discover-refresh-loading')), findsOneWidget);
      expect(find.byKey(const Key('skills-loading-ink-drop')), findsOneWidget);
      expect(
        find.byKey(const Key('skills-loading-progressive-dots')),
        findsNothing,
      );
      expect(gateway.requestedOffsets, [0, 0]);

      refresh.complete(
        const DiscoveryPage(
          skills: [
            SkillSummary(
              id: 'github.com/acme/refreshed',
              installName: 'refreshed',
              name: 'Refreshed',
              source: 'github.com/acme/refreshed',
              installs: 3,
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('skills-loading-ink-drop')), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('discover-refresh-opacity')),
            )
            .opacity,
        greaterThan(0),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsNothing);
      expect(find.text('Refreshed'), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('discover-refresh-opacity')),
            )
            .opacity,
        0,
      );
      expect(
        TickerMode.valuesOf(
          tester.element(find.byKey(const Key('discover-refresh-opacity'))),
        ).enabled,
        isTrue,
      );
    },
  );

  testWidgets('installed discovery action never repeats the known target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const installedSkill = SkillSummary(
      id: 'github.com/acme/skills/-/planner',
      installName: 'planner',
      name: 'Planner',
      source: 'github.com/acme/skills',
      installs: 10,
      localTargetCount: 1,
    );
    final gateway = FakeSkillsGateway(
      discoveryPages: const {
        'ranking:0': DiscoveryPage(skills: [installedSkill]),
      },
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();

    expect(gateway.installCalls, 0);
    expect(find.text('Set installation location'), findsNothing);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Install'), findsNothing);
  });

  testWidgets(
    'card and detail installation use the shared anchored location selector',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      const project = AddedProject(
        id: 'project-a',
        name: 'Project A',
        path: '/work/project-a',
        accessState: ProjectAccessState.accessible,
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        agentNames: const ['codex', 'claude-code'],
        addedProjects: const [project],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(searchInput(), 'location');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      final card = find.byType(SkillCard).first;
      await tester.tap(
        find.descendant(of: card, matching: find.text('Install')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set installation location'), findsNothing);
      expect(find.text('Install Flutter Pro to'), findsOneWidget);
      expect(find.text('All projects'), findsOneWidget);
      expect(find.text('Selected projects'), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Available to 2 Agents at user level'), findsOneWidget);
      await tester.tap(find.byType(Radio<InstallationScope>).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Project A'), findsOneWidget);
      expect(find.text('0 projects · 2 Agents'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-hero-install')));
      await tester.pumpAndSettle();
      expect(find.text('Set installation location'), findsNothing);
      expect(find.text('Available to 2 Agents at user level'), findsOneWidget);
    },
  );

  testWidgets(
    'installation selector headings share a foreground across themes and seeds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      for (final themeMode in [AppThemeMode.light, AppThemeMode.dark]) {
        for (final seed in ['#FFFFFF', '#5865F2']) {
          final gateway = FakeSkillsGateway(
            installed: false,
            agentNames: const ['codex', 'claude-code'],
            folderTheme: seed,
            themeMode: themeMode,
          );
          await tester.pumpWidget(SkillsGoApp(gateway: gateway));
          await tester.pumpAndSettle();

          final card = find.byType(SkillCard).first;
          await tester.tap(
            find.descendant(of: card, matching: find.text('Install')),
          );
          await tester.pumpAndSettle();

          final installTitle = tester.renderObject<RenderParagraph>(
            find.text('Install Flutter Pro to'),
          );
          final agentsTitle = tester.renderObject<RenderParagraph>(
            find.text('For Agents'),
          );
          expect(
            installTitle.text.style?.color,
            agentsTitle.text.style?.color,
            reason: '$themeMode with $seed seed',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    },
  );

  testWidgets('card installation opens a skeleton before detail resolves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    final detail = Completer<SkillDetail>();
    final gateway = FakeSkillsGateway(
      installed: false,
      detailCompleter: detail,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    final card = find.byType(SkillCard).first;
    await tester.tap(find.descendant(of: card, matching: find.text('Install')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('install-location-skeleton')),
      findsOneWidget,
    );
    expect(find.text('Install Flutter Pro to'), findsOneWidget);
    detail.complete(defaultRemoteDetail);
    await tester.pumpAndSettle();
    expect(find.text('All projects'), findsOneWidget);
  });

  testWidgets(
    'failed card installation keeps the selector open and shows a stacked toast',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        installPlanErrors: const [
          SkillsException(
            'local lock is incompatible',
            kind: SkillsFailureKind.invalidLocalData,
          ),
        ],
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final card = find.byType(SkillCard).first;
      await tester.tap(
        find.descendant(of: card, matching: find.text('Install')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Install Flutter Pro to'), findsOneWidget);
      expect(find.text('Installation could not be completed'), findsOneWidget);
      expect(
        find.textContaining('local installation information is damaged'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('detail-back')), findsNothing);
    },
  );

  testWidgets('auditable detail exposes immutable evidence and files', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Real instructions'), findsOneWidget);
    expect(find.text('Immutable v1.2.3'), findsNothing);
    expect(find.text('Commit commit-abc'), findsNothing);
    expect(find.text('Tree tree-def'), findsNothing);
    expect(find.text('Publisher verified'), findsNothing);
    expect(find.text('Medium risk'), findsNothing);
    final detailAvatarSize = tester.getSize(
      find.byKey(const Key('detail-skill-avatar')),
    );
    expect(detailAvatarSize, const Size.square(116));
    expect(
      find.byKey(const Key('detail-description-markdown')),
      findsOneWidget,
    );
    final summary = tester.widget<Text>(
      find.byKey(const Key('detail-description-markdown')),
    );
    expect(summary.maxLines, 3);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(find.text(defaultRemoteDetail.description), findsOneWidget);
    expect(find.byKey(const Key('detail-sticky-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('detail-scroll-view')), findsOneWidget);
    expect(find.byKey(const Key('detail-compact-identity')), findsNothing);
    expect(find.byKey(const Key('detail-hero-install')), findsOneWidget);
    expect(
      tester
          .widget<PrimaryCapsuleButton>(
            find.byKey(const Key('detail-hero-install')),
          )
          .onPressed,
      isNotNull,
    );
    expect(gateway.agentInspections, 1);
    expect(find.text('Installs'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
    expect(find.text('github.com/example/skills'), findsNothing);
    expect(find.text('12.8K'), findsOneWidget);
    expect(find.text('2026-07-15'), findsOneWidget);
    expect(find.text('24 KB'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-instructions')),
        matching: find.byType(MarkdownBody),
      ),
      findsOneWidget,
    );

    final detailScrollable = find.descendant(
      of: find.byKey(const Key('detail-scroll-view')),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(detailScrollable.first).position.jumpTo(180);
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('detail-compact-identity')))
          .opacity,
      1,
    );
    expect(
      find.textContaining('does not certify artifact safety'),
      findsNothing,
    );
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AgentLogo && widget.agentId == 'codex',
      ),
      findsOneWidget,
    );
    expect(find.text('v1.2.3'), findsOneWidget);

    expect(find.text('Snapshot files'), findsNothing);
    expect(find.text('references/guide.md'), findsNothing);
    expect(find.text('Manifest'), findsNothing);
  });

  testWidgets('detail transition keeps the moving page opaque', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pump(const Duration(milliseconds: 80));

    final detailMotion = find.byKey(const ValueKey('discover-detail-motion'));
    expect(detailMotion, findsOneWidget);
    expect(find.byKey(const ValueKey('discover-list-motion')), findsOneWidget);
    expect(
      find.descendant(of: detailMotion, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: detailMotion, matching: find.byType(ColoredBox)),
      findsWidgets,
    );
  });

  testWidgets('remote detail inherits the selected App theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    const seed = Color(0xFF5865F2);
    final gateway = FakeSkillsGateway(
      folderTheme: '#5865F2',
      themeMode: AppThemeMode.dark,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(searchInput(), 'theme');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    final detailTheme = Theme.of(
      tester.element(find.byKey(const Key('detail-instructions'))),
    );
    final expected = buildSkillsTheme(seed);
    expect(detailTheme.brightness, Brightness.dark);
    expect(detailTheme.colorScheme.primary, expected.colorScheme.primary);
    expect(detailTheme.colorScheme.surface, expected.colorScheme.surface);
  });
}
