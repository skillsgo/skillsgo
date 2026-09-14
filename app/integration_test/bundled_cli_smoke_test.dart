/*
 * [INPUT]: Depends on the production desktop bundle, DesktopSkillsGateway startup handshake, and rendered SkillsGo App root.
 * [OUTPUT]: Verifies that the platform-bundled CLI is executable and the real desktop App renders with it available.
 * [POS]: Serves as the minimal cross-platform App E2E gate for macOS, Windows, and Linux runners.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/infrastructure/desktop_skills_gateway.dart';
import 'package:skillsgo/main.dart' as skillsgo;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts with the platform-bundled CLI', (tester) async {
    final gateway = DesktopSkillsGateway(allowDeveloperCliOverride: false);
    final status = await gateway.detectCli();
    expect(status.isReady, isTrue, reason: status.message);

    await skillsgo.runSkillsGoApp(initializeBinding: false, gateway: gateway);
    await tester.pump();
    expect(find.byType(SkillsGoApp), findsOneWidget);
  });
}
