/*
 * [INPUT]: Uses the Flutter test runner entry point and the SkillsGo native pending-indicator test seam.
 * [OUTPUT]: Runs every App test with the pending-indicator rotation frozen so rendered statistics surfaces reach quiescence.
 * [POS]: Serves as the workspace-wide bootstrap for the App test directory; integration tests keep live motion because the harness never reaches them.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:skillsgo/ui/native_components.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Library statistics intentionally rotate until the local archive
  // observation completes, which never happens inside a rendered test. Freezing
  // that single indicator keeps every other animation at full fidelity while
  // rendered suites still settle; the focused pending-indicator test turns the
  // rotation back on for its own assertions.
  debugPendingIndicatorMotionEnabled = false;
  await testMain();
}
