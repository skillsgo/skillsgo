/*
 * [INPUT]: Depends on SettingsScreen state, localized headings, reminder values, onboarding reset, Library refresh and App diagnostic-log state, Mermaid gallery navigation, and shared setting controls.
 * [OUTPUT]: Provides route content selection, reminder controls, managed-backup route content, reusable headings, Advanced settings, Mandatory Onboarding reset UI, local Library refresh, bounded diagnostic-log controls, and the final Mermaid gallery entry.
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
        _SettingsRoute.backups => _managedBackupsSettings(),
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
      _appUpdateSettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _hubSettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
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
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _diagnosticLogSettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _mermaidGallerySettings(),
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

  Widget _diagnosticLogSettings() {
    final info = diagnosticLogInfo;
    final size = info == null ? '—' : _formatBytes(info.totalBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsHeading(
          context.l10n.diagnosticLogsTitle,
          context.l10n.diagnosticLogsDescription(size),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SkillsButton.outline(
              key: const Key('view-live-diagnostic-logs'),
              enabled: !managingDiagnosticLogs,
              onPressed: _openDiagnosticLogViewer,
              child: Text(context.l10n.viewLiveLogs),
            ),
            SkillsButton.outline(
              key: const Key('open-diagnostic-logs'),
              enabled: !managingDiagnosticLogs,
              onPressed: () => unawaited(_openDiagnosticLogs()),
              child: Text(context.l10n.openLogFolder),
            ),
            SkillsButton.outline(
              key: const Key('export-diagnostic-logs'),
              enabled: !managingDiagnosticLogs,
              onPressed: () => unawaited(_exportDiagnosticLogs()),
              child: Text(context.l10n.exportLogs),
            ),
            SkillsButton.outline(
              key: const Key('clear-diagnostic-logs'),
              enabled: !managingDiagnosticLogs && (info?.totalBytes ?? 0) > 0,
              onPressed: () => unawaited(_clearDiagnosticLogs()),
              child: Text(context.l10n.clearLogs),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openDiagnosticLogs() async {
    await _manageDiagnosticLogs(widget.gateway.openDiagnosticLogDirectory);
  }

  void _openDiagnosticLogViewer() {
    updateState(() => showingDiagnosticLogs = true);
  }

  Future<void> _exportDiagnosticLogs() async {
    await _manageDiagnosticLogs(() async {
      final exported = await widget.gateway.exportDiagnosticLogs();
      if (mounted && exported) notice = context.l10n.logsExported;
    });
  }

  Future<void> _clearDiagnosticLogs() async {
    await _manageDiagnosticLogs(() async {
      await widget.gateway.clearDiagnosticLogs();
      if (mounted) notice = context.l10n.logsCleared;
    });
  }

  Future<void> _manageDiagnosticLogs(Future<void> Function() action) async {
    if (managingDiagnosticLogs) return;
    updateState(() => managingDiagnosticLogs = true);
    try {
      await action();
      final info = await widget.gateway.loadDiagnosticLogInfo();
      if (mounted) updateState(() => diagnosticLogInfo = info);
    } on Object {
      if (mounted) updateState(() => notice = context.l10n.logActionFailed);
    } finally {
      if (mounted) updateState(() => managingDiagnosticLogs = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kib = bytes / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
    return '${(kib / 1024).toStringAsFixed(1)} MB';
  }

  Widget _mermaidGallerySettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Mermaid',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 18),
      SkillsButton.outline(
        key: const Key('open-mermaid-gallery'),
        onPressed: _openMermaidGallery,
        child: const Text('Mermaid'),
      ),
    ],
  );

  void _openMermaidGallery() {
    updateState(() => showingMermaidGallery = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) scrollController.jumpTo(0);
    });
  }
}
