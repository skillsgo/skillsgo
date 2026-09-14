/*
 * [INPUT]: Uses PackageDetailScreen, generated localization delegates, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Package card continuity and README presentation when independently loaded CDN content succeeds or fails.
 * [POS]: Serves as the rendered public seam for the Package-centered detail journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/l10n/app_localizations.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/app_providers.dart';
import 'package:skillsgo/ui/package_detail_screen.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  testWidgets('root README request contains no empty fragment', (tester) async {
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [skillsGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: buildSkillsTheme(const Color(0xFF5865F2)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PackageDetailScreen(
            gateway: gateway,
            packagePath: 'example/skills',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.packageReadmeRequests, hasLength(1));
    expect(gateway.packageReadmeRequests.single.hasFragment, isFalse);
  });

  testWidgets('README failure preserves Package card without a Skill list', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      packageReadmeError: const SkillsException(
        'CDN unavailable',
        kind: SkillsFailureKind.artifactUnavailable,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [skillsGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: buildSkillsTheme(const Color(0xFF5865F2)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PackageDetailScreen(
            gateway: gateway,
            packagePath: 'example/skills',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('package-summary-card')), findsOneWidget);
    final detailSurface = tester.widget<Material>(
      find.byKey(const Key('package-detail-surface')),
    );
    expect(detailSurface.type, MaterialType.transparency);
    final backMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('package-detail-back')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(backMaterial.shape, isA<CircleBorder>());
    expect(find.text('example/skills'), findsOneWidget);
    expect(
      find.byKey(const Key('package-detail-skill-skills/flutter-pro')),
      findsNothing,
    );
    expect(find.text('Flutter Pro'), findsNothing);
    expect(find.text('README'), findsNothing);
    expect(find.byKey(const Key('package-readme-error')), findsOneWidget);
  });

  testWidgets('failed Package refresh keeps the current card and README', (
    tester,
  ) async {
    final refresh = Completer<PackageDetail>();
    final gateway = FakeSkillsGateway(
      packageDetailRefreshCompleter: refresh,
      packageUpdateResult: const PackageUpdateCheckResult(
        packagePath: 'example/skills',
        status: PackageUpdateCheckStatus.upToDate,
        version: 'v1.2.4',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [skillsGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: buildSkillsTheme(const Color(0xFF5865F2)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PackageDetailScreen(
            gateway: gateway,
            packagePath: 'example/skills',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('package-check-update')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('package-detail-refreshing')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    expect(find.byKey(const Key('package-summary-card')), findsOneWidget);
    expect(find.byKey(const Key('package-readme-content')), findsOneWidget);

    refresh.completeError(
      const SkillsException(
        'refresh unavailable',
        kind: SkillsFailureKind.artifactUnavailable,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-detail-refreshing')), findsNothing);
    expect(
      find.byKey(const Key('package-detail-refresh-error')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('package-summary-card')), findsOneWidget);
    expect(find.byKey(const Key('package-readme-content')), findsOneWidget);
  });
}
