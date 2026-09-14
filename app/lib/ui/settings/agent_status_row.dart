/*
 * [INPUT]: Depends on Agent catalog status, logos, paths, discovery roots, and localized copy.
 * [OUTPUT]: Provides the installed/not-installed Agent status row with target and discovery-root diagnostics.
 * [POS]: Serves as the Agent inventory presentation segment of the Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

class _AgentStatusRow extends StatelessWidget {
  const _AgentStatusRow({required this.status});

  final AgentStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AgentLogo(
            agentId: status.id,
            displayName: status.displayName,
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status.discoveryRoots.isNotEmpty) ...[
                const SizedBox(height: 5),
                SelectableText(
                  context.l10n.agentDiscoveryRoots(
                    status.discoveryRoots.join('  '),
                  ),
                  style: context.skillsTypography.caption.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
