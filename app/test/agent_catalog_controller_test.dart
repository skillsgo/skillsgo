/*
 * [INPUT]: Uses Riverpod, the App-scoped Agent catalog controller, and a controllable SkillsGateway test double.
 * [OUTPUT]: Specifies that an in-flight Agent inspection completes without writing through a disposed provider.
 * [POS]: Serves as the lifecycle regression suite for the shared Agent capability source.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/agent_catalog_controller.dart';
import 'package:skillsgo/ui/app_providers.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  test(
    'a completed request never writes through a disposed provider',
    () async {
      final inspection = Completer<AgentCatalog>();
      final gateway = FakeSkillsGateway(agentInspectionCompleter: inspection);
      final container = ProviderContainer(
        overrides: [skillsGatewayProvider.overrideWithValue(gateway)],
      );

      final refresh = container.read(agentCatalogProvider.notifier).refresh();
      container.dispose();
      const catalog = AgentCatalog(schemaVersion: 1, agents: []);
      inspection.complete(catalog);

      await expectLater(refresh, completion(catalog));
    },
  );
}
