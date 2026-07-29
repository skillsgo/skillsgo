/*
 * [INPUT]: Uses a ProviderContainer, injected UTC clock, deterministic installed Package target, and controllable FakeSkillsGateway update checks.
 * [OUTPUT]: Specifies App-scoped update-check TTL selection, persisted-cache reuse, and concurrent single-flight behavior.
 * [POS]: Serves as the fast policy contract for the shared update coordinator independently of rendered Library widgets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/app_providers.dart';
import 'package:skillsgo/ui/update_check_controller.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  const key = 'github.com/test/skills\u0000global\u0000';
  final skill = InstalledSkill(
    inventoryKey: 'hub:github.com/test/skills:demo',
    name: 'demo',
    path: '/tmp/demo',
    agents: const ['codex'],
    targetCount: 1,
    packagePath: 'github.com/test/skills',
    versions: const ['v1.0.0'],
    targets: const [
      SkillInstallationTarget(
        agent: 'codex',
        scope: InstallationScope.global,
        path: '/tmp/demo',
        version: 'v1.0.0',
      ),
    ],
  );

  test(
    'automatic checks reuse a complete persisted result for six hours',
    () async {
      final now = DateTime.utc(2026, 7, 29, 12);
      final gateway = FakeSkillsGateway(
        updateCheckCache: UpdateCheckCache(
          checkedAt: now.subtract(const Duration(hours: 3)),
          results: const {key: UpdateAvailability(state: UpdateState.upToDate)},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          skillsGatewayProvider.overrideWithValue(gateway),
          updateCheckClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateCheckProvider.future);
      final results = await container.read(updateCheckProvider.notifier).check([
        skill,
      ], trigger: UpdateCheckTrigger.automatic);

      expect(results[key]?.state, UpdateState.upToDate);
      expect(gateway.updateChecks, 0);
    },
  );

  test('Updates view uses its shorter two-minute freshness window', () async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final gateway = FakeSkillsGateway(
      updateCheckCache: UpdateCheckCache(
        checkedAt: now.subtract(const Duration(minutes: 3)),
        results: const {key: UpdateAvailability(state: UpdateState.upToDate)},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        skillsGatewayProvider.overrideWithValue(gateway),
        updateCheckClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await container.read(updateCheckProvider.future);
    await container.read(updateCheckProvider.notifier).check([
      skill,
    ], trigger: UpdateCheckTrigger.updatesView);

    expect(gateway.updateChecks, 1);
    expect(gateway.updateCheckCache?.checkedAt, now);
  });

  test('concurrent callers share one CLI-backed check', () async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final pending = Completer<Map<String, UpdateAvailability>>();
    final gateway = FakeSkillsGateway(updateCheckCompleter: pending);
    final container = ProviderContainer(
      overrides: [
        skillsGatewayProvider.overrideWithValue(gateway),
        updateCheckClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await container.read(updateCheckProvider.future);
    final controller = container.read(updateCheckProvider.notifier);
    final first = controller.check([
      skill,
    ], trigger: UpdateCheckTrigger.automatic);
    final second = controller.check([
      skill,
    ], trigger: UpdateCheckTrigger.updatesView);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.updateChecks, 1);

    pending.complete(const {
      key: UpdateAvailability(
        state: UpdateState.available,
        toVersion: 'v1.1.0',
      ),
    });
    expect(await first, await second);
    expect(gateway.updateChecks, 1);
  });
}
