/*
 * [INPUT]: Composes capability-specific SkillsGateway test-double mixins over shared controllable state and canonical domain fixtures.
 * [OUTPUT]: Provides FakeSkillsGateway for rendered App and gateway-adjacent behavior tests.
 * [POS]: Serves as the stable test boundary that hides scenario controls behind the production gateway contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:skillsgo/domain/skills_gateway.dart';

import 'skill_fixtures.dart';

part 'fake_gateway/fake_gateway_core.dart';
part 'fake_gateway/fake_gateway_system.dart';
part 'fake_gateway/fake_gateway_inventory.dart';
part 'fake_gateway/fake_gateway_installation.dart';
part 'fake_gateway/fake_gateway_target_management.dart';
part 'fake_gateway/fake_gateway_updates.dart';

class FakeSkillsGateway = FakeSkillsGatewayCore
    with
        FakeGatewaySystem,
        FakeGatewayInventory,
        FakeGatewayInstallation,
        FakeGatewayTargetManagement,
        FakeGatewayUpdates;
