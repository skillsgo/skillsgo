/*
 * [INPUT]: Depends on unified InstalledSkill entries, repository identity, selection callbacks, and update state.
 * [OUTPUT]: Provides grouping data, deterministic repository grouping, compact source identity, and installed Skill group cards.
 * [POS]: Serves as the repository grouping segment of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _InstalledSkillGroupData {
  const _InstalledSkillGroupData({
    required this.source,
    required this.label,
    required this.skills,
  });

  final String source;
  final String label;
  final List<InstalledSkill> skills;
}

List<_InstalledSkillGroupData> _groupInstalledSkills(
  BuildContext context,
  List<InstalledSkill> skills,
) {
  final managed = <String, List<InstalledSkill>>{};
  final external = <InstalledSkill>[];
  for (final skill in skills) {
    if (skill.provenance == LibraryProvenance.external) {
      external.add(skill);
      continue;
    }
    final source = _installedSourceLabel(context, skill);
    managed.putIfAbsent(source, () => <InstalledSkill>[]).add(skill);
  }
  final compactNameCounts = <String, int>{};
  for (final source in managed.keys) {
    final compact = _compactRepositorySource(source).toLowerCase();
    compactNameCounts.update(compact, (count) => count + 1, ifAbsent: () => 1);
  }
  final groups =
      managed.entries.map((entry) {
        final compact = _compactRepositorySource(entry.key);
        final hasCollision = compactNameCounts[compact.toLowerCase()]! > 1;
        return _InstalledSkillGroupData(
          source: entry.key,
          label: hasCollision ? entry.key : compact,
          skills: entry.value,
        );
      }).toList()..sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
  if (external.isNotEmpty) {
    groups.add(
      _InstalledSkillGroupData(
        source: context.l10n.externalInstallation,
        label: context.l10n.externalInstallation,
        skills: external,
      ),
    );
  }
  return groups;
}

String _compactRepositorySource(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1 && parts.first.contains('.')) {
    return parts.skip(1).join('/');
  }
  return source;
}

class _InstalledSkillGroup extends StatelessWidget {
  const _InstalledSkillGroup({
    required this.group,
    required this.projects,
    required this.agentLabel,
    required this.onOpen,
    required this.selectedSkillKeys,
    required this.onSelectionChanged,
  });

  final _InstalledSkillGroupData group;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;
  final ValueChanged<InstalledSkill> onOpen;
  final Set<String> selectedSkillKeys;
  final void Function(InstalledSkill, bool) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 11, bottom: 9),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Center(
                  child: RepositoryAvatar(
                    source: group.source,
                    imageUrl: _repositoryAvatarUrl(group.source),
                    size: 42,
                    borderRadius: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.display.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: '${group.skills.length}'),
              const Spacer(),
            ],
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < group.skills.length; index++) ...[
              if (index > 0) const SkillsSeparator.horizontal(),
              _InstalledSkillRow(
                skill: group.skills[index],
                projects: projects,
                selected: selectedSkillKeys.contains(
                  _librarySelectionKey(group.skills[index]),
                ),
                agentLabel: agentLabel,
                onOpen: () => onOpen(group.skills[index]),
                onSelectionChanged: (selected) =>
                    onSelectionChanged(group.skills[index], selected),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String? _repositoryAvatarUrl(String source) {
  final parts = source.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length < 3 || parts.first.toLowerCase() != 'github.com') {
    return null;
  }
  return 'https://github.com/${Uri.encodeComponent(parts[1])}.png?size=84';
}
