/*
 * [INPUT]: Depends on LibraryScreen state, explicit async states, content-level governance mode, project access state, localized distinct empty/error copy, Package updates, and installed Skill groups.
 * [OUTPUT]: Provides loading, stale/error, inaccessible-project recovery including macOS privacy-settings and retry actions, All Skills inventory, Needs Attention dashboard, unused governance with trustworthy 45-day window copy, Other Installation lists, Package updates, distinct empty states, and sticky reviewed Adoption states.
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
          action: project.accessState == ProjectAccessState.permissionDenied
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if (defaultTargetPlatform == TargetPlatform.macOS)
                          SkillsButton.outline(
                            onPressed: () =>
                                unawaited(_openLocalScanPrivacySettings()),
                            child: Text(context.l10n.openSettings),
                          ),
                        SkillsButton(
                          onPressed: () => unawaited(load()),
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                    if (privacySettingsOpenFailed) ...[
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.privacySettingsOpenFailed,
                        textAlign: TextAlign.center,
                        style: context.skillsTypography.bodySecondary.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                )
              : null,
        );
      }
    }
    if (contentMode == _LibraryContentMode.needsAttention) {
      return _LibraryNeedsAttentionBody(
        unusedCount: _unusedAttentionSkills.length,
        externalCount: _externalAttentionCount,
        updateCount: _availableUpdatePackageCount,
        updateSkills: _availableUpdateSkills,
        checkingUpdates: checking,
        onUnused: _openUnusedAttention,
        onExternal: _openOtherInstallationAttention,
        onUpdates: _openUpdatesAttention,
      );
    }
    if (contentMode == _LibraryContentMode.updates) {
      final packages = _packageUpdateCards;
      if (packages.isEmpty) {
        if (updateCheckError != null) {
          final copy = failureCopy(context, updateCheckError!);
          return EmptyState(
            title: copy.title,
            message: copy.message,
            action: PrimaryCapsuleButton(
              label: context.l10n.retry,
              onPressed: _openUpdatesAttention,
            ),
          );
        }
        return EmptyState(
          title: checking ? context.l10n.loading : context.l10n.upToDate,
          message: checking ? null : context.l10n.libraryUpdatesEmptyMessage,
        );
      }
      return ListView.separated(
        key: const ValueKey('library-package-updates'),
        controller: scrollController,
        itemCount: packages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _PackageUpdateCard(
          package: packages[index],
          operating: operatingSkills.contains(packages[index].packagePath),
          onUpdate: () => _updatePackageCard(packages[index]),
        ),
      );
    }
    if (contentMode == _LibraryContentMode.unused45Days) {
      if (_unusedAttentionSkills.isEmpty) {
        return EmptyState(
          title: context.l10n.libraryUnusedEmptyTitle,
          message: context.l10n.libraryUnusedEmptyMessage,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            key: const Key('library-unused-window-copy'),
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.libraryUnused45Days,
                  style: context.skillsTypography.sectionTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.libraryFilterUnused45DaysTooltip,
                  style: context.skillsTypography.bodySecondary.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _installedInventory(
              _unusedAttentionSkills,
              key: const ValueKey('library-unused-results'),
              sortable: true,
            ),
          ),
        ],
      );
    }
    if (contentMode == _LibraryContentMode.otherInstallation) {
      final external = _locationAndAgentProjectedSkills
          .where((skill) => skill.provenance == LibraryProvenance.external)
          .toList(growable: false);
      if (external.isEmpty) {
        return EmptyState(
          title: context.l10n.libraryOtherEmptyTitle,
          message: context.l10n.libraryOtherEmptyMessage,
        );
      }
      return _installedInventory(
        external,
        key: const ValueKey('library-other-installation-results'),
        sortable: true,
      );
    }
    if (_visibleSkills.isEmpty) {
      if (librarySearchController.text.trim().isNotEmpty) {
        return EmptyState(
          title: context.l10n.libraryNoMatches,
          message: context.l10n.libraryNoMatchesMessage,
        );
      }
      if (managementFilter != _LibraryManagementFilter.all ||
          usageFilter != _LibraryUsageFilter.all) {
        return EmptyState(
          title: context.l10n.libraryFilterEmptyTitle,
          message: context.l10n.libraryFilterEmptyMessage,
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
    return _installedInventory(
      _visibleSkills,
      key: const ValueKey('library-results'),
      sortable: true,
    );
  }

  Widget _installedInventory(
    List<InstalledSkill> inventory, {
    required Key key,
    bool sortable = false,
  }) {
    final groups = _groupInstalledSkills(
      context,
      inventory,
      usageSort: sortable ? usageSort : _LibraryUsageSort.none,
      usageSortDescending: usageSortDescending,
    );
    return CustomScrollView(
      key: key,
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _InstalledSkillColumnHeader(
            usageSort: sortable ? usageSort : _LibraryUsageSort.none,
            usageSortDescending: usageSortDescending,
            onUsageSortChanged: sortable ? _sortByUsage : (_) {},
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          if (groupIndex > 0)
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
          if (groups[groupIndex].skills.every(
            (skill) => skill.provenance == LibraryProvenance.external,
          ))
            _AdoptionReviewShell(
              skills: groups[groupIndex].skills,
              gateway: widget.gateway,
              expanded: adoptionReviewVisible,
              projects: projects,
              agentLabel: _agentLabel,
              onOpen: _openDetail,
              selectedSkillKeys: selectedSkillKeys,
              onSelectionChanged: _toggleSkillSelection,
              onEnter: _enterAdoptionReview,
              onExit: _exitAdoptionReview,
              onConfirm: _openAdoptionAdoptionConsole,
            )
          else
            SliverToBoxAdapter(
              child: _InstalledSkillGroup(
                group: groups[groupIndex],
                selectionVisible: !adoptionReviewVisible,
                projects: projects,
                agentLabel: _agentLabel,
                onOpen: _openDetail,
                selectedSkillKeys: selectedSkillKeys,
                onSelectionChanged: _toggleSkillSelection,
                onAdoptionReview: null,
              ),
            ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(height: selectedSkillKeys.isEmpty ? 0 : 72),
        ),
      ],
    );
  }
}
