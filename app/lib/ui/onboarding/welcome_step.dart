/*
 * [INPUT]: Depends on Installed Agent catalogs, bundled CLI status, SkillsGo branding, Agent logos, retry actions, and localized welcome copy.
 * [OUTPUT]: Provides the Welcome step, complete Agent grid, Agent chips, and CLI recovery state.
 * [POS]: Serves as the first step of Mandatory Onboarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../onboarding_screen.dart';

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.agents,
    required this.error,
    required this.onRetry,
  });

  final AgentCatalog? agents;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final installed = agents?.installed ?? const <AgentStatus>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/branding/skillsgo-logo.png',
                key: const Key('onboarding-skillsgo-logo'),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.onboardingWelcomeTitle,
                    style: context.skillsTypography.display,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingWelcomeDescription,
                    style: context.skillsTypography.bodySecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Text(
          l10n.onboardingDetectedAgents,
          style: context.skillsTypography.sectionTitle,
        ),
        const SizedBox(height: 16),
        if (error != null)
          SkillsAlert.destructive(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 18,
              strokeWidth: 1.8,
            ),
            title: Text(l10n.onboardingCliErrorTitle),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.onboardingCliErrorDescription),
                const SizedBox(height: 10),
                SkillsButton.ghost(
                  onPressed: onRetry,
                  size: SkillsButtonSize.sm,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          )
        else if (agents == null)
          Semantics(
            liveRegion: true,
            label: l10n.loading,
            child: const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SkillsSkeletonBox(width: 128, height: 44, borderRadius: 12),
                SkillsSkeletonBox(width: 146, height: 44, borderRadius: 12),
              ],
            ),
          )
        else if (installed.isEmpty)
          Text(
            l10n.onboardingNoAgents,
            style: context.skillsTypography.bodySecondary,
          )
        else
          _AgentGrid(agents: installed),
      ],
    );
  }
}

class _AgentGrid extends StatelessWidget {
  const _AgentGrid({required this.agents});

  final List<AgentStatus> agents;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final columnCount = constraints.maxWidth >= 520 ? 3 : 2;
      final itemWidth =
          (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
      return Wrap(
        spacing: spacing,
        runSpacing: 6,
        children: [
          for (final agent in agents)
            SizedBox(
              width: itemWidth,
              child: _AgentChip(agent: agent),
            ),
        ],
      );
    },
  );
}

class _AgentChip extends StatelessWidget {
  const _AgentChip({required this.agent});

  final AgentStatus agent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AgentLogo(agentId: agent.id, displayName: agent.displayName, size: 22),
        const SizedBox(width: 9),
        Text(agent.displayName, style: context.skillsTypography.label),
      ],
    ),
  );
}
