/*
 * [INPUT]: Depends on SettingsScreen's AppUpdater, stable production feed, localized copy, and native button/status components.
 * [OUTPUT]: Renders explicit unavailable/checking/current/available/applying/error App-update states and drives check or update-and-restart actions.
 * [POS]: Serves as the App-binary update segment of Advanced Settings, independent from Package update reminders.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

enum _AppUpdatePhase { ready, checking, current, available, applying, error }

extension _AppUpdateSettings on _SettingsScreenState {
  Widget _appUpdateSettings() {
    final source = widget.appUpdateSource;
    final check = appUpdateCheck;
    final error = appUpdateError;
    final message = switch ((source, appUpdatePhase)) {
      (null, _) => context.l10n.appUpdateNotConfigured,
      (_, _AppUpdatePhase.checking) => context.l10n.appUpdateChecking,
      (_, _AppUpdatePhase.applying) => context.l10n.appUpdateApplying,
      (_, _AppUpdatePhase.error) => context.l10n.appUpdateCheckFailed,
      (_, _AppUpdatePhase.available) => context.l10n.appUpdateAvailable(
        check!.availableVersion!,
      ),
      (_, _AppUpdatePhase.current) => context.l10n.appUpdateCurrent(
        check!.currentVersion,
      ),
      _ => context.l10n.appUpdateReady,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsHeading(
          context.l10n.appUpdateTitle,
          context.l10n.appUpdateDescription,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          key: const Key('app-update-status'),
          style: TextStyle(
            color: error == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : context.skillsComponents.statusAttention,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SkillsButton.outline(
              key: const Key('check-app-update'),
              enabled:
                  source != null &&
                  appUpdatePhase != _AppUpdatePhase.checking &&
                  appUpdatePhase != _AppUpdatePhase.applying,
              onPressed: () => unawaited(_checkAppUpdate()),
              child: Text(context.l10n.appUpdateCheckAction),
            ),
            if (check?.updateAvailable == true)
              SkillsButton(
                key: const Key('apply-app-update'),
                enabled:
                    appUpdatePhase != _AppUpdatePhase.checking &&
                    appUpdatePhase != _AppUpdatePhase.applying,
                onPressed: () => unawaited(_applyAppUpdate()),
                child: Text(context.l10n.appUpdateApplyAction),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _checkAppUpdate() async {
    final source = widget.appUpdateSource;
    if (source == null ||
        appUpdatePhase == _AppUpdatePhase.checking ||
        appUpdatePhase == _AppUpdatePhase.applying) {
      return;
    }
    updateState(() {
      appUpdatePhase = _AppUpdatePhase.checking;
      appUpdateError = null;
    });
    try {
      final check = await widget.appUpdater.checkForUpdate(source);
      if (mounted) {
        updateState(() {
          appUpdateCheck = check;
          appUpdatePhase = check.updateAvailable
              ? _AppUpdatePhase.available
              : _AppUpdatePhase.current;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        updateState(() {
          appUpdateError = error;
          appUpdatePhase = _AppUpdatePhase.error;
        });
      }
    }
  }

  Future<void> _applyAppUpdate() async {
    final source = widget.appUpdateSource;
    if (source == null || appUpdatePhase == _AppUpdatePhase.applying) return;
    updateState(() {
      appUpdatePhase = _AppUpdatePhase.applying;
      appUpdateError = null;
    });
    try {
      final applied = await widget.appUpdater.applyAvailableUpdateAndRestart(
        source,
      );
      if (!applied && mounted) {
        final check = await widget.appUpdater.checkForUpdate(source);
        if (mounted) {
          updateState(() {
            appUpdateCheck = check;
            appUpdatePhase = check.updateAvailable
                ? _AppUpdatePhase.available
                : _AppUpdatePhase.current;
          });
        }
      } else if (mounted) {
        updateState(() => appUpdatePhase = _AppUpdatePhase.ready);
      }
    } on Object catch (error) {
      if (mounted) {
        updateState(() {
          appUpdateError = error;
          appUpdatePhase = _AppUpdatePhase.error;
        });
      }
    }
  }
}
