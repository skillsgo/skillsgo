/*
 * [INPUT]: Depends on SettingsScreen gateway state, CLI/Agent catalogs, Hub health, risk policy, localized status copy, and diagnostics.
 * [OUTPUT]: Provides Agent detection/recovery, Hub origin, connection state, and Personal risk-policy settings.
 * [POS]: Serves as the CLI, Agent, Hub, and policy segment of the Settings journey.
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
}
