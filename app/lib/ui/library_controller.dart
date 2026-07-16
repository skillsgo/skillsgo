/*
 * [INPUT]: Depends on Riverpod, SkillsGateway library contracts, and the App-scoped Gateway provider.
 * [OUTPUT]: Provides immutable Library content and an AsyncNotifier that owns initial loading, stale-content refresh, and load failures.
 * [POS]: Serves as the Library journey's business-state boundary while widgets retain only short-lived interaction state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
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
    bool? refreshing,
    Object? refreshError,
    bool clearRefreshError = false,
  }) => LibraryContentState(
    skills: skills,
    agentCatalog: agentCatalog,
    projects: projects,
    refreshing: refreshing ?? this.refreshing,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );
}

final libraryProvider =
    AsyncNotifierProvider<LibraryController, LibraryContentState>(
      LibraryController.new,
    );

class LibraryController extends AsyncNotifier<LibraryContentState> {
  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  Future<LibraryContentState> build() => _load();

  Future<LibraryContentState> _load() async {
    final projects = await _gateway.loadAddedProjects();
    final values = await Future.wait<Object>([
      _gateway.listInstalled(projects: projects),
      _gateway.inspectAgents(),
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
      state = AsyncData(await _load());
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
