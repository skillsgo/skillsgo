/*
 * [INPUT]: Depends on all maintained rendered macOS App Journey registrations and the Flutter integration-test binding.
 * [OUTPUT]: Registers every App E2E Journey in one Flutter test executable so App, Xcode, and bundled CLI compilation occur once per suite.
 * [POS]: Serves as the default aggregate entry point orchestrated by e2e/app/run.sh while individual Journey files remain focusable.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:integration_test/integration_test.dart';

import 'catalog_update_check_test.dart' as catalog_update;
import 'machine_failure_recovery_test.dart' as machine_failure;
import 'repository_install_all_test.dart' as repository_install;
import 'takeover_management_test.dart' as takeover;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  repository_install.registerRepositoryInstallAllJourney();
  catalog_update.registerCatalogUpdateCheckJourney();
  takeover.registerTakeoverManagementJourney();
  machine_failure.registerMachineFailureRecoveryJourney();
}
