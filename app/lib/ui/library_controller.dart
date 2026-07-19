/*
 * [INPUT]: Depends on Riverpod, SkillsGateway library contracts, the App-scoped Gateway provider, and shared AgentCatalog state.
 * [OUTPUT]: Provides immutable Library content and a user-retry-controlled AsyncNotifier that owns initial loading, stale-content refresh, non-blocking project-icon enrichment, and stable load failures without implicit provider retries.
 * [POS]: Serves as the Library journey's business-state boundary while widgets retain only short-lived interaction state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'app_providers.dart';

class LibraryContentState {
  const LibraryContentState({
    required this.skills,
    required this.agentCatalog,
    required this.projects,
    this.refreshing = false,
    this.refreshError,
  });

  final List<InstalledSkill> skills;
  final AgentCatalog agentCatalog;
  final List<AddedProject> projects;
  final bool refreshing;
  final Object? refreshError;

  LibraryContentState copyWith({
    List<AddedProject>? projects,
    bool? refreshing,
    Object? refreshError,
    bool clearRefreshError = false,
  }) => LibraryContentState(
    skills: skills,
    agentCatalog: agentCatalog,
    projects: projects ?? this.projects,
    refreshing: refreshing ?? this.refreshing,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );
}

final libraryProvider =
    AsyncNotifierProvider<LibraryController, LibraryContentState>(
      LibraryController.new,
      retry: (_, _) => null,
    );

class LibraryController extends AsyncNotifier<LibraryContentState> {
  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  Future<LibraryContentState> build() async {
    final content = await _load();
    Future<void>.delayed(
      Duration.zero,
      () => _resolveProjectIcons(content.projects),
    );
    return content;
  }

  Future<void> _resolveProjectIcons(List<AddedProject> projects) async {
    for (var start = 0; start < projects.length; start += 2) {
      final batch = projects.skip(start).take(2).toList(growable: false);
      final resolved = await Future.wait(
        batch.map(_gateway.resolveProjectIcon),
      );
      for (final project in resolved) {
        final current = state.value;
        if (current == null) return;
        final index = current.projects.indexWhere(
          (candidate) => candidate.id == project.id,
        );
        if (index < 0 || current.projects[index].path != project.path) continue;
        final updated = List<AddedProject>.of(current.projects);
        updated[index] = project;
        state = AsyncData(current.copyWith(projects: updated));
      }
    }
  }

  Future<LibraryContentState> _load() async {
    final projects = await _gateway.loadAddedProjects();
    final values = await Future.wait<Object>([
      _gateway.listInstalled(projects: projects),
      ref.read(agentCatalogProvider.notifier).ensureLoaded(),
    ]);
    return LibraryContentState(
      skills: values[0] as List<InstalledSkill>,
      agentCatalog: values[1] as AgentCatalog,
      projects: projects,
    );
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData(
        previous.copyWith(refreshing: true, clearRefreshError: true),
      );
    }
    try {
      await ref.read(agentCatalogProvider.notifier).refresh();
      final content = await _load();
      state = AsyncData(content);
      Future<void>.delayed(
        Duration.zero,
        () => _resolveProjectIcons(content.projects),
      );
    } catch (error, stackTrace) {
      if (previous == null) {
        state = AsyncError(error, stackTrace);
      } else {
        state = AsyncData(
          previous.copyWith(refreshing: false, refreshError: error),
        );
      }
    }
  }
}
