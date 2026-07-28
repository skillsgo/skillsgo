/*
 * [INPUT]: Depends on resolved installation-version actions and generated localized copy.
 * [OUTPUT]: Provides concise localized Install, Installed, Upgrade, or Downgrade labels for a resolved action.
 * [POS]: Serves as the presentation adapter for version-aware confirmation controls after installation intent is established.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/widgets.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';

String installationVersionActionCopy(
  BuildContext context,
  InstallationVersionAction action,
) => switch (action) {
  InstallationVersionAction.install => AppLocalizations.of(context).install,
  InstallationVersionAction.installed => AppLocalizations.of(
    context,
  ).installedCell,
  InstallationVersionAction.upgrade => AppLocalizations.of(context).upgrade,
  InstallationVersionAction.downgrade => AppLocalizations.of(context).downgrade,
};
