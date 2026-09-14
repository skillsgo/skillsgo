/*
 * [INPUT]: Depends on SettingsScreen gateway state, CLI/Agent catalogs, Hub health, risk policy, adoption-backup records, localized status copy, and diagnostics.
 * [OUTPUT]: Provides Agent detection/recovery, the single Hub Origin, managed-backup listing and restore controls, connection state, and Personal risk-policy settings.
 * [POS]: Serves as the CLI, Agent, service-origin, and policy segment of the Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

extension _IntegrationSettings on _SettingsScreenState {
  Widget _agentSettings() {
    final cliSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.l10n.agentsSettingsTitle)),
            if (detecting)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              StatusChip(
                label: status?.isReady == true
                    ? context.l10n.ready
                    : cliAvailabilityLabel(context, status?.availability),
                color: status?.isReady == true
                    ? context.skillsComponents.statusSuccess
                    : context.skillsComponents.statusAttention,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          status?.isReady == true
              ? '${status!.path} · v${status!.version}'
              : status == null
              ? context.l10n.detecting
              : cliStatusMessage(context, status!),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kReleaseMode) ...[
              SkillsInput(
                key: const Key('cli-path'),
                controller: controller,
                placeholder: const Text('/path/to/development/skillsgo'),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!kReleaseMode)
                  SkillsButton(
                    enabled: !detecting,
                    onPressed: save,
                    child: Text(context.l10n.saveAndDetect),
                  ),
                SkillsButton.outline(
                  enabled: !detecting,
                  onPressed: detect,
                  child: Text(context.l10n.detectAgain),
                ),
                if (!kReleaseMode)
                  SkillsButton.outline(
                    enabled: !detecting,
                    onPressed: clear,
                    child: Text(context.l10n.clearCustomPath),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cliSection,
        if (agentInspectionError != null) ...[
          const SizedBox(height: 14),
          Text(
            context.l10n.agentInspectionFailed,
            style: TextStyle(color: context.skillsComponents.statusAttention),
          ),
        ],
        if (agentCatalog != null) ...[
          const SizedBox(height: 14),
          _agentCatalogCard(agentCatalog!),
        ],
      ],
    );
  }

  Widget _agentCatalogCard(AgentCatalog catalog) {
    final installed = catalog.agents.where((agent) => agent.installed).toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
    final notInstalled =
        catalog.agents.where((agent) => !agent.installed).toList()..sort(
          (left, right) => left.displayName.compareTo(right.displayName),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SkillsSeparator.horizontal(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 22),
        _agentGroup(
          key: const Key('installed-agents-group'),
          title: context.l10n.installedAgentsTitle(installed.length),
          agents: installed,
        ),
        const SizedBox(height: 28),
        SkillsSeparator.horizontal(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 22),
        _agentGroup(
          key: const Key('not-installed-agents-group'),
          title: context.l10n.notInstalledAgentsTitle(notInstalled.length),
          description: context.l10n.notInstalledAgentsDescription,
          agents: notInstalled,
        ),
      ],
    );
  }

  Widget _agentGroup({
    required Key key,
    required String title,
    String? description,
    required List<AgentStatus> agents,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      if (description != null) ...[
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 10),
      for (var index = 0; index < agents.length; index++) ...[
        _AgentStatusRow(status: agents[index]),
        if (index != agents.length - 1)
          SkillsSeparator.horizontal(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    ],
  );

  Widget _hubSettings() => Column(
    key: const Key('hub-origin-settings'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _settingsHeading(
        context.l10n.hubSettingsTitle,
        context.l10n.hubSettingsDescription,
      ),
      const SizedBox(height: 18),
      SkillsInput(
        key: const Key('hub-origin'),
        controller: hubController,
        placeholder: const Text('https://hub.example.com'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SkillsButton(
            enabled: !testingHub,
            onPressed: saveHub,
            child: Text(context.l10n.saveOrigin),
          ),
          SkillsButton.outline(
            enabled: !testingHub,
            onPressed: testHub,
            child: Text(context.l10n.testConnection),
          ),
          SkillsButton.outline(
            enabled: !testingHub,
            onPressed: resetHub,
            child: Text(context.l10n.resetDefault),
          ),
        ],
      ),
      if (hubStatus != null) ...[
        const SizedBox(height: 14),
        Text(
          hubStatus!.isReady
              ? context.l10n.connectionReady
              : '${context.l10n.connectionFailed}: ${hubStatusMessage(context, hubStatus!)}',
          style: TextStyle(
            color: hubStatus!.isReady
                ? context.skillsComponents.statusSuccess
                : context.skillsComponents.statusAttention,
          ),
        ),
      ],
    ],
  );

  Widget _policySettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _settingsHeading(
        context.l10n.riskPolicyTitle,
        context.l10n.riskPolicyDescription,
      ),
      const SizedBox(height: 18),
      SkillsSwitch(
        value: true,
        enabled: false,
        label: Text(context.l10n.confirmHighRisk),
        sublabel: Text(context.l10n.confirmHighRiskDescription),
      ),
      const SizedBox(height: 14),
      SkillsSwitch(
        key: const Key('critical-risk-override'),
        value: riskPolicy?.allowCriticalOverride ?? false,
        onChanged: setCriticalOverride,
        label: Text(context.l10n.allowCriticalOverride),
        sublabel: Text(context.l10n.allowCriticalOverrideDescription),
      ),
    ],
  );

  Widget _managedBackupsSettings() {
    final backups = _recoverableManagedBackups;
    final initialLoading = managedBackups == null && loadingManagedBackups;
    return Column(
      key: const Key('managed-backups-settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _settingsHeading(
                context.l10n.managedBackupsTitle,
                context.l10n.managedBackupsDescription,
              ),
            ),
            if (!initialLoading)
              IconButton(
                key: const Key('managed-backups-refresh'),
                tooltip: context.l10n.refresh,
                onPressed: loadingManagedBackups
                    ? null
                    : () => unawaited(_loadManagedBackups()),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: 19,
                  strokeWidth: 1.8,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (initialLoading)
          const Center(
            key: Key('managed-backups-loading'),
            child: CircularProgressIndicator(),
          )
        else if (managedBackups == null && managedBackupsError != null)
          _managedBackupsError()
        else ...[
          if (loadingManagedBackups) ...[
            const SkillsProgress(
              key: Key('managed-backups-refreshing'),
              minHeight: 2,
            ),
            const SizedBox(height: 14),
          ],
          if (managedBackupsError != null) ...[
            _managedBackupsError(compact: true),
            const SizedBox(height: 16),
          ],
          if (backups.isEmpty)
            _managedBackupsEmpty()
          else ...[
            Text(
              context.l10n.managedBackupsCount(backups.length),
              key: const Key('managed-backups-count'),
              style: context.skillsTypography.bodySecondary,
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < backups.length; index++) ...[
              _managedBackupCard(backups[index]),
              if (index != backups.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ],
    );
  }

  Widget _managedBackupsError({bool compact = false}) => Column(
    key: compact
        ? const Key('managed-backups-inline-error')
        : const Key('managed-backups-error'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkillsAlert.destructive(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 19,
          strokeWidth: 1.8,
        ),
        title: Text(context.l10n.managedBackupsLoadFailed),
        description: Text(context.l10n.tryAgain),
      ),
      if (!compact) ...[
        const SizedBox(height: 14),
        SkillsButton.outline(
          key: const Key('managed-backups-retry'),
          enabled: !loadingManagedBackups,
          onPressed: () => unawaited(_loadManagedBackups()),
          child: Text(context.l10n.tryAgain),
        ),
      ],
    ],
  );

  Widget _managedBackupsEmpty() => SkillsAlert(
    key: const Key('managed-backups-empty'),
    icon: HugeIcon(
      icon: HugeIcons.strokeRoundedArchiveRestore,
      size: 19,
      strokeWidth: 1.8,
    ),
    title: Text(context.l10n.managedBackupsEmpty),
    description: Text(context.l10n.managedBackupsDescription),
  );

  Widget _managedBackupCard(AdoptionBackup backup) {
    final restoring = restoringManagedBackupIds.contains(backup.id);
    final location = backup.scope == InstallationScope.project
        ? (backup.projectRoot.isEmpty
              ? context.l10n.projectScope
              : backup.projectRoot)
        : context.l10n.globalScope;
    final statusColor = backup.status == 'restore-failed'
        ? context.skillsComponents.statusAttention
        : context.skillsComponents.statusSuccess;
    return SkillsCard(
      key: ValueKey('managed-backup-${backup.id}'),
      leading: HugeIcon(
        icon: HugeIcons.strokeRoundedArchiveRestore,
        size: 22,
        strokeWidth: 1.7,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(backup.name),
      description: Text('${backup.packagePath}@${backup.version}\n$location'),
      footer: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip(
            label: backup.status == 'restore-failed'
                ? context.l10n.managedBackupRestoreFailed
                : context.l10n.adoptionBackupRetention,
            color: statusColor,
          ),
          Text(
            context.l10n.managedBackupExpiresAt(
              _managedBackupDate(backup.expiresAt),
            ),
            style: context.skillsTypography.caption,
          ),
        ],
      ),
      trailing: SecondaryCapsuleButton(
        key: ValueKey('managed-backup-restore-${backup.id}'),
        label: restoring
            ? context.l10n.loading
            : context.l10n.adoptionBackupRestore,
        icon: HugeIcons.strokeRoundedArrowTurnBackward,
        onPressed: restoring
            ? null
            : () => unawaited(_restoreManagedBackup(backup)),
      ),
    );
  }

  String _managedBackupDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Future<void> _restoreManagedBackup(AdoptionBackup backup) async {
    if (restoringManagedBackupIds.contains(backup.id)) return;
    final confirmed = await showSkillsDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.adoptionBackupRestoreTitle),
        content: Text(context.l10n.adoptionBackupRestoreMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: ValueKey('managed-backup-restore-confirm-${backup.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.adoptionBackupRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    updateState(() => restoringManagedBackupIds.add(backup.id));
    try {
      await widget.gateway.restoreAdoptionBackup(backup.id);
      await _loadManagedBackups();
      if (mounted) {
        updateState(() => notice = context.l10n.managedBackupRestored);
      }
    } on Object {
      if (mounted) {
        updateState(() => notice = context.l10n.managedBackupRestoreFailed);
      }
    } finally {
      if (mounted) {
        updateState(() => restoringManagedBackupIds.remove(backup.id));
      }
    }
  }
}
