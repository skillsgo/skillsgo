/*
 * [INPUT]: Uses the deep Installation Request controller with a controllable SkillsGateway test double.
 * [OUTPUT]: Specifies single-Skill success, all-target failure classification, Repository snapshot-version sequencing without detail re-resolution, and exception capture.
 * [POS]: Serves as the controller-level regression suite for installation orchestration independently of rendered selectors.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/install_operation_controller.dart';

import 'support/fake_skills_gateway.dart';

const _selection = InstallationTargetSelection(
  scope: InstallationScope.user,
  agent: 'codex',
);

void main() {
  test('single-Skill request exposes aggregate success', () async {
    final gateway = FakeSkillsGateway();
    final controller = InstallOperationController(gateway);
    addTearDown(controller.dispose);

    final state = await controller.submit(
      InstallationRequest.skill(
        defaultSearchResults.first,
        'v1.2.3',
        selections: [_selection],
        riskPolicy: PersonalRiskPolicy(),
      ),
    );

    expect(state.operating, isFalse);
    expect(state.succeeded, isTrue);
    expect(state.executions, hasLength(1));
    expect(state.error, isNull);
    expect(gateway.installCalls, 1);
  });

  test('an execution with no successful targets is a failed request', () async {
    final gateway = FakeSkillsGateway(
      installFailures: const [
        <String>{'codex'},
      ],
    );
    final controller = InstallOperationController(gateway);
    addTearDown(controller.dispose);

    final state = await controller.submit(
      InstallationRequest.skill(
        defaultSearchResults.first,
        'v1.2.3',
        selections: [_selection],
        riskPolicy: PersonalRiskPolicy(),
      ),
    );

    expect(state.succeeded, isFalse);
    expect(state.executions.single.hasSuccess, isFalse);
    expect(state.error, isA<StateError>());
  });

  test(
    'Repository request resolves and installs every member in order',
    () async {
      const second = SkillSummary(
        id: 'example/skills/dart-pro',
        installName: 'dart-pro',
        name: 'Dart Pro',
        source: 'example/skills',
        installs: 42,
        latestVersion: 'v1.2.0',
      );
      final gateway = FakeSkillsGateway();
      final controller = InstallOperationController(gateway);
      addTearDown(controller.dispose);

      final state = await controller.submit(
        InstallationRequest.repository(
          [defaultSearchResults.first, second],
          selections: [_selection],
          riskPolicy: PersonalRiskPolicy(),
        ),
      );

      expect(state.succeeded, isTrue);
      expect(state.executions, hasLength(2));
      expect(state.executions.map((item) => item.skillId), [
        defaultSearchResults.first.id,
        second.id,
      ]);
      expect(state.executions.map((item) => item.version), ['main', 'v1.2.0']);
      expect(gateway.detailLoads, 0);
      expect(gateway.installCalls, 2);
    },
  );

  test('gateway exception becomes stable request error state', () async {
    final gateway = FakeSkillsGateway(
      installPlanErrors: const [
        SkillsException('conflict', kind: SkillsFailureKind.validation),
      ],
    );
    final controller = InstallOperationController(gateway);
    addTearDown(controller.dispose);

    final state = await controller.submit(
      InstallationRequest.skill(
        defaultSearchResults.first,
        'v1.2.3',
        selections: [_selection],
        riskPolicy: PersonalRiskPolicy(),
      ),
    );

    expect(state.operating, isFalse);
    expect(state.succeeded, isFalse);
    expect(state.executions, isEmpty);
    expect(state.error, isA<SkillsException>());
  });
}
