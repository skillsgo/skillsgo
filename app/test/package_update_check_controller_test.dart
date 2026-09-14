/*
 * [INPUT]: Uses the shared Package update-check controller with a controllable SkillsGateway.
 * [OUTPUT]: Specifies duplicate-check coalescing and transition from an accepted update to a newly published Package Version.
 * [POS]: Serves as business-state coverage shared by Package-card and Skill-detail update entry points.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/package_update_check_controller.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  test('coalesces concurrent checks for the same Package', () async {
    final pending = Completer<PackageUpdateCheckResult>();
    final gateway = FakeSkillsGateway(packageUpdateCompleter: pending);
    final controller = PackageUpdateCheckController(gateway, 'example/skills');
    addTearDown(controller.dispose);

    final first = controller.check('v1.2.3');
    final second = controller.check('v1.2.3');
    expect(gateway.packageUpdateChecks, ['example/skills']);
    pending.complete(
      const PackageUpdateCheckResult(
        packagePath: 'example/skills',
        status: PackageUpdateCheckStatus.upToDate,
        version: 'v1.2.3',
      ),
    );

    expect((await first).phase, PackageUpdateOperationPhase.upToDate);
    expect((await second).phase, PackageUpdateOperationPhase.upToDate);
    expect(gateway.packageUpdateChecks, hasLength(1));
  });

  test('reports updated after the accepted Version becomes current', () async {
    final gateway = FakeSkillsGateway(
      packageUpdateResult: const PackageUpdateCheckResult(
        packagePath: 'example/skills',
        status: PackageUpdateCheckStatus.updating,
        version: 'v1.3.0',
      ),
      discoveryPages: {
        'search:0': const DiscoveryPage(
          skills: [],
          module: PackageSummary(id: 'example/skills', latestVersion: 'v1.3.0'),
        ),
      },
    );
    final controller = PackageUpdateCheckController(
      gateway,
      'example/skills',
      pollInterval: Duration.zero,
      maximumPolls: 1,
    );
    addTearDown(controller.dispose);

    final result = await controller.check('v1.2.3');

    expect(result.phase, PackageUpdateOperationPhase.updated);
    expect(result.version, 'v1.3.0');
  });

  test('treats an already-published newer Version as updated', () async {
    final gateway = FakeSkillsGateway(
      packageUpdateResult: const PackageUpdateCheckResult(
        packagePath: 'example/skills',
        status: PackageUpdateCheckStatus.upToDate,
        version: 'v1.3.0',
      ),
    );
    final controller = PackageUpdateCheckController(gateway, 'example/skills');
    addTearDown(controller.dispose);

    final result = await controller.check('v1.2.3');

    expect(result.phase, PackageUpdateOperationPhase.updated);
    expect(result.version, 'v1.3.0');
  });
}
