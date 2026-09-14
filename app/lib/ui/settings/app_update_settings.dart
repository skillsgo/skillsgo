/*
 * [INPUT]: Depends on SettingsScreen's AppUpdater, stable production feed/channel, automatic-check cadence, localized copy, and native button/status components.
 * [OUTPUT]: Renders the configured update address plus explicit unavailable/checking/current/available/applying/error App-update states and drives single-flight manual, timed, resumed, or update-and-restart actions.
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
        if (source != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            source.toString(),
            key: const Key('app-update-source'),
            style: context.skillsTypography.caption.copyWith(
              color: context.skillsColors.foregroundMuted,
            ),
          ),
        ],
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

  Future<void> _checkAppUpdate({bool automatic = false}) async {
    final source = widget.appUpdateSource;
    if (source == null ||
        _appUpdateCheckInFlight ||
        appUpdatePhase == _AppUpdatePhase.checking ||
        appUpdatePhase == _AppUpdatePhase.applying) {
      return;
    }
    _appUpdateCheckInFlight = true;
    if (!automatic) {
      updateState(() {
        appUpdatePhase = _AppUpdatePhase.checking;
        appUpdateError = null;
      });
    }
    try {
      final check = await widget.appUpdater.checkForUpdate(
        source,
        channel: widget.appUpdateChannel,
      );
      if (mounted) {
        updateState(() {
          appUpdateCheck = check;
          appUpdatePhase = check.updateAvailable
              ? _AppUpdatePhase.available
              : _AppUpdatePhase.current;
        });
      }
    } on Object catch (error) {
      if (mounted && !automatic) {
        updateState(() {
          appUpdateError = error;
          appUpdatePhase = _AppUpdatePhase.error;
        });
      }
    } finally {
      _appUpdateCheckInFlight = false;
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
        channel: widget.appUpdateChannel,
      );
      if (!applied && mounted) {
        final check = await widget.appUpdater.checkForUpdate(
          source,
          channel: widget.appUpdateChannel,
        );
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
