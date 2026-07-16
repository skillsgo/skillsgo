/*
 * [INPUT]: Depends on Riverpod and the SkillsGateway domain contract.
 * [OUTPUT]: Provides the application-scoped SkillsGateway dependency to UI state controllers.
 * [POS]: Serves as the explicit dependency-injection boundary for Riverpod-managed App state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';

final skillsGatewayProvider = Provider<SkillsGateway>((ref) {
  throw StateError('skillsGatewayProvider must be overridden at the App root.');
});
