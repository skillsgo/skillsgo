/*
 * [INPUT]: Depends on SettingsScreen state, localized headings, reminder values, onboarding reset and Library refresh state, and shared setting controls.
 * [OUTPUT]: Provides route content selection, reminder controls, reusable headings, Advanced settings, Mandatory Onboarding reset UI, and the explicit local Library refresh action.
 * [POS]: Serves as the general section composition of the Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

extension _SettingsSections on _SettingsScreenState {
  Widget _settingsPage() => ListView(
    controller: scrollController,
    padding: const EdgeInsets.only(top: 12),
    children: [
      if (notice != null) ...[
        Text(
          notice!,
          style: TextStyle(color: context.skillsComponents.statusSuccess),
        ),
        const SizedBox(height: 12),
      ],
      switch (selectedRoute) {
        _SettingsRoute.general => _generalSettings(),
        _SettingsRoute.reminders => _reminderSettings(),
        _SettingsRoute.agents => _agentSettings(),
        _SettingsRoute.advanced => _advancedSettings(),
      },
    ],
  );

  Widget _reminderSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SkillsSwitch(
        key: const Key('update-reminder'),
        value: reminderSettings.updateAvailable,
        onChanged: _setUpdateReminder,
        label: _inlineReminderLabel(
          key: const Key('update-reminder-label'),
          title: context.l10n.updateReminderTitle,
          description: context.l10n.updateReminderDescription,
        ),
      ),
      const SizedBox(height: 18),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 18),
      SkillsSwitch(
        key: const Key('security-reminder'),
        value: reminderSettings.securityAdvisory,
        onChanged: _setSecurityReminder,
        label: _inlineReminderLabel(
          key: const Key('security-reminder-label'),
          title: context.l10n.securityReminderTitle,
          description: context.l10n.securityReminderDescription,
        ),
      ),
    ],
  );

  Widget _inlineReminderLabel({
    required Key key,
    required String title,
    required String description,
  }) => Text.rich(
    key: key,
    TextSpan(
      children: [
        TextSpan(
          text: title,
          style: context.skillsTypography.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: '  $description',
          style: context.skillsTypography.bodySecondary,
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  Widget _settingsHeading(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    ],
  );

  Widget _advancedSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _hubSettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _policySettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _onboardingSettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _libraryRefreshSettings(),
    ],
  );

  Widget _onboardingSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _settingsHeading(
        context.l10n.restartOnboardingTitle,
        context.l10n.restartOnboardingDescription,
      ),
      const SizedBox(height: 18),
      SkillsButton.outline(
        key: const Key('restart-onboarding'),
        enabled: !restartingOnboarding,
        onPressed: () => unawaited(_restartOnboarding()),
        child: Text(
          restartingOnboarding
              ? context.l10n.loading
              : context.l10n.restartOnboardingAction,
        ),
      ),
    ],
  );

  Future<void> _restartOnboarding() async {
    updateState(() => restartingOnboarding = true);
    try {
      await widget.onRestartOnboarding();
    } on Object {
      if (!mounted) return;
      updateState(() {
        restartingOnboarding = false;
        notice = context.l10n.restartOnboardingFailed;
      });
    }
  }

  Widget _libraryRefreshSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _settingsHeading(
        context.l10n.libraryRefreshSettingsTitle,
        context.l10n.libraryRefreshSettingsDescription,
      ),
      const SizedBox(height: 18),
      SkillsButton.outline(
        key: const Key('refresh-local-library'),
        enabled: !refreshingLibrary,
        onPressed: () => unawaited(_refreshLocalLibrary()),
        child: Text(
          refreshingLibrary
              ? context.l10n.libraryRefreshSettingsPending
              : context.l10n.libraryRefreshSettingsAction,
        ),
      ),
      if (libraryRefreshSucceeded case final succeeded?) ...[
        const SizedBox(height: 12),
        Text(
          succeeded
              ? context.l10n.libraryRefreshSettingsSuccess
              : context.l10n.libraryRefreshSettingsFailed,
          style: TextStyle(
            color: succeeded
                ? context.skillsComponents.statusSuccess
                : context.skillsComponents.statusAttention,
          ),
        ),
      ],
    ],
  );

  Future<void> _refreshLocalLibrary() async {
    if (refreshingLibrary) return;
    updateState(() {
      refreshingLibrary = true;
      libraryRefreshSucceeded = null;
    });
    await ref.read(libraryProvider.notifier).refresh();
    if (!mounted) return;
    final refreshed = ref.read(libraryProvider);
    final failed = refreshed.hasError || refreshed.value?.refreshError != null;
    updateState(() {
      refreshingLibrary = false;
      libraryRefreshSucceeded = !failed;
    });
  }
}
