/*
 * [INPUT]: Depends on installation scope values, selected projects and Agents, project/Agent identity, and localized radio controls.
 * [OUTPUT]: Provides the scope selector, radio rows, project avatars, and Agent avatars used by the location card.
 * [POS]: Serves as the target-selection presentation segment of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

class _InstallScopeSelector extends StatelessWidget {
  const _InstallScopeSelector({
    required this.title,
    required this.scope,
    required this.allProjectsLabel,
    required this.selectedProjectsLabel,
    required this.onChanged,
    required this.addProjectLabel,
    required this.onAddProject,
  });

  final String title;
  final InstallationScope scope;
  final String allProjectsLabel;
  final String selectedProjectsLabel;
  final ValueChanged<InstallationScope> onChanged;
  final String addProjectLabel;
  final VoidCallback? onAddProject;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      RadioGroup<InstallationScope>(
        groupValue: scope,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        child: Column(
          children: [
            _ScopeRadioRow(
              label: allProjectsLabel,
              value: InstallationScope.user,
              onChanged: onChanged,
            ),
            _ScopeRadioRow(
              label: selectedProjectsLabel,
              value: InstallationScope.project,
              onChanged: onChanged,
              trailing: TextButton(
                onPressed: onAddProject,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(addProjectLabel),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ScopeRadioRow extends StatelessWidget {
  const _ScopeRadioRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final InstallationScope value;
  final ValueChanged<InstallationScope> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => onChanged(value),
    child: Row(
      children: [
        SizedBox(
          width: 40,
          child: Center(
            child: Radio<InstallationScope>(
              value: value,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _ProjectAvatar extends StatelessWidget {
  const _ProjectAvatar({required this.project});

  final AddedProject project;

  @override
  Widget build(BuildContext context) =>
      ProjectIdentityIcon(project: project, size: 18);
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.agent});

  final AgentStatus agent;

  @override
  Widget build(BuildContext context) =>
      AgentLogo(agentId: agent.id, displayName: agent.displayName, size: 18);
}
