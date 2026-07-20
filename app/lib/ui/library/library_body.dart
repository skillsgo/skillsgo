/*
 * [INPUT]: Depends on LibraryScreen state, explicit async states, project access state, localized empty/error copy, and installed Skill groups.
 * [OUTPUT]: Provides the Library content body for loading, stale/error, inaccessible project, filter-empty, and inventory states.
 * [POS]: Serves as the async content rendering implementation of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

extension _LibraryBody on _LibraryScreenState {
  Widget _body() {
    if (loading && skills == null) {
      return Semantics(
        liveRegion: true,
        label: context.l10n.loading,
        child: const _LibrarySkeleton(),
      );
    }
    if (error != null && skills == null) {
      final copy = failureCopy(context, error!);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: PrimaryCapsuleButton(
          label: context.l10n.retry,
          onPressed: load,
        ),
      );
    }
    final project = _selectedProject;
    if (project != null) {
      if (!project.isAccessible) {
        final copy = switch (project.accessState) {
          ProjectAccessState.missing => (
            title: context.l10n.projectMissingTitle,
            message: context.l10n.projectMissingMessage,
          ),
          ProjectAccessState.permissionDenied => (
            title: context.l10n.projectPermissionTitle,
            message: context.l10n.projectPermissionMessage,
          ),
          ProjectAccessState.inaccessible => (
            title: context.l10n.projectInaccessibleTitle,
            message: context.l10n.projectInaccessibleMessage,
          ),
          ProjectAccessState.accessible => throw StateError(
            'Accessible project reached inaccessible state.',
          ),
        };
        return EmptyState(
          title: copy.title,
          message: '${copy.message}\n${project.path}',
          action: PrimaryCapsuleButton(
            label: context.l10n.relocateProject,
            onPressed: () => _relocateProject(project),
          ),
        );
      }
    }
    if (_visibleSkills.isEmpty) {
      if (librarySearchController.text.trim().isNotEmpty) {
        return EmptyState(
          title: context.l10n.libraryNoMatches,
          message: context.l10n.libraryNoMatchesMessage,
        );
      }
      if (project != null) {
        return EmptyState(
          title: context.l10n.emptyProjectTitle,
          action: PrimaryCapsuleButton(
            label: context.l10n.browseSkills,
            onPressed: widget.onBrowseSkills,
          ),
        );
      }
      return EmptyState(
        title: context.l10n.libraryEmpty,
        message: context.l10n.libraryEmptyMessage,
      );
    }
    final groups = _groupInstalledSkills(context, _visibleSkills);
    return ListView.separated(
      key: const ValueKey('library-results'),
      controller: scrollController,
      padding: EdgeInsets.only(bottom: selectedSkillKeys.isEmpty ? 0 : 72),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 22),
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return _InstalledSkillGroup(
          group: group,
          projects: projects,
          agentLabel: _agentLabel,
          onOpen: _openDetail,
          selectedSkillKeys: selectedSkillKeys,
          onSelectionChanged: _toggleSkillSelection,
        );
      },
    );
  }
}
