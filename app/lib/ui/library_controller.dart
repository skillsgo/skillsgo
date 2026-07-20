/*
 * [INPUT]: Depends on Dart async support, Riverpod, SkillsGateway Library contracts, the App-scoped Gateway provider, and shared AgentCatalog state.
 * [OUTPUT]: Provides immutable Library content, stable Entry queries, targeted post-mutation reconciliation, initial loading, stale-content refresh, lifecycle-safe project-icon enrichment, independent Batch Takeover planning, and stable load failures without implicit retries.
 * [POS]: Serves as the deep Library Inventory module while widgets retain only short-lived filtering, selection, and navigation state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

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
    this.takeoverPlan,
    this.takeoverPlanning = false,
    this.takeoverPlanError,
  });

  final List<InstalledSkill> skills;
  final AgentCatalog agentCatalog;
  final List<AddedProject> projects;
  final bool refreshing;
  final Object? refreshError;
  final BatchTakeoverPlan? takeoverPlan;
  final bool takeoverPlanning;
  final Object? takeoverPlanError;

  LibraryContentState copyWith({
    List<InstalledSkill>? skills,
    AgentCatalog? agentCatalog,
    List<AddedProject>? projects,
    bool? refreshing,
    Object? refreshError,
    bool clearRefreshError = false,
    BatchTakeoverPlan? takeoverPlan,
    bool clearTakeoverPlan = false,
    bool? takeoverPlanning,
    Object? takeoverPlanError,
    bool clearTakeoverPlanError = false,
  }) => LibraryContentState(
    skills: skills ?? this.skills,
    agentCatalog: agentCatalog ?? this.agentCatalog,
    projects: projects ?? this.projects,
    refreshing: refreshing ?? this.refreshing,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
    takeoverPlan: clearTakeoverPlan ? null : takeoverPlan ?? this.takeoverPlan,
    takeoverPlanning: takeoverPlanning ?? this.takeoverPlanning,
    takeoverPlanError: clearTakeoverPlanError
        ? null
        : takeoverPlanError ?? this.takeoverPlanError,
  );
}

class LibraryEntryQuery {
  const LibraryEntryQuery._(
    this._inventoryKey,
    this._skillId,
    this._targetPath,
    this._agent,
  );

  factory LibraryEntryQuery.byInventoryKey(String inventoryKey) =>
      LibraryEntryQuery._(inventoryKey, '', null, null);

  factory LibraryEntryQuery.bySkill({
    required String skillId,
    String? targetPath,
    String? agent,
  }) => LibraryEntryQuery._('', skillId, targetPath, agent);

  final String _inventoryKey;
  final String _skillId;
  final String? _targetPath;
  final String? _agent;

  bool matches(InstalledSkill entry) {
    if (_inventoryKey.isNotEmpty) return entry.inventoryKey == _inventoryKey;
    final skillMatches = _skillId.isNotEmpty && entry.skillId == _skillId;
    final path = _targetPath;
    if (path == null) return skillMatches;
    final targetMatches = entry.targets.any(
      (target) =>
          target.path == path && (_agent == null || target.agent == _agent),
    );
    return skillMatches || targetMatches;
  }
}

class LibraryEntryRefresh {
  const LibraryEntryRefresh({required this.projects, required this.entry});

  final List<AddedProject> projects;
  final InstalledSkill? entry;
}

final libraryProvider =
    AsyncNotifierProvider<LibraryController, LibraryContentState>(
      LibraryController.new,
      retry: (_, _) => null,
    );

class LibraryController extends AsyncNotifier<LibraryContentState> {
  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);
  int _takeoverPlanGeneration = 0;
  final _scheduledTasks = <Timer>{};

  @override
  Future<LibraryContentState> build() async {
    ref.onDispose(() {
      _takeoverPlanGeneration++;
      for (final task in _scheduledTasks) {
        task.cancel();
      }
      _scheduledTasks.clear();
    });
    final content = await _load();
    if (!ref.mounted) return content;
    _scheduleAfterBuild(() => _resolveProjectIcons(content.projects));
    _scheduleAfterBuild(() => refreshTakeoverPlan(content.projects));
    return content;
  }

  void _scheduleAfterBuild(Future<void> Function() action) {
    if (!ref.mounted) return;
    late final Timer task;
    task = Timer(Duration.zero, () {
      _scheduledTasks.remove(task);
      if (ref.mounted) unawaited(action());
    });
    _scheduledTasks.add(task);
  }

  Future<void> _resolveProjectIcons(List<AddedProject> projects) async {
    final gateway = _gateway;
    for (var start = 0; start < projects.length; start += 2) {
      if (!ref.mounted) return;
      final batch = projects.skip(start).take(2).toList(growable: false);
      final resolved = await Future.wait(batch.map(gateway.resolveProjectIcon));
      if (!ref.mounted) return;
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
    final gateway = _gateway;
    final agentController = ref.read(agentCatalogProvider.notifier);
    final projects = await gateway.loadAddedProjects();
    final values = await Future.wait<Object>([
      gateway.listInstalled(projects: projects),
      agentController.ensureLoaded(),
    ]);
    return LibraryContentState(
      skills: values[0] as List<InstalledSkill>,
      agentCatalog: values[1] as AgentCatalog,
      projects: projects,
    );
  }

  Future<void> refreshTakeoverPlan([List<AddedProject>? source]) async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final projects = source ?? current.projects;
    final projectRoots = projects
        .where((project) => project.isAccessible)
        .map((project) => project.path)
        .toList(growable: false);
    final generation = ++_takeoverPlanGeneration;
    state = AsyncData(
      current.copyWith(
        clearTakeoverPlan: true,
        takeoverPlanning: true,
        clearTakeoverPlanError: true,
      ),
    );
    try {
      final plan = await _gateway.planBatchTakeover(projectRoots: projectRoots);
      if (!ref.mounted || generation != _takeoverPlanGeneration) return;
      final latest = state.value;
      if (latest == null || !_sameProjectRoots(latest.projects, projectRoots)) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          takeoverPlan: plan,
          takeoverPlanning: false,
          clearTakeoverPlanError: true,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted || generation != _takeoverPlanGeneration) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(takeoverPlanning: false, takeoverPlanError: error),
      );
    }
  }

  bool _sameProjectRoots(List<AddedProject> projects, List<String> expected) {
    final current = projects
        .where((project) => project.isAccessible)
        .map((project) => project.path)
        .toList(growable: false);
    if (current.length != expected.length) return false;
    for (var index = 0; index < current.length; index++) {
      if (current[index] != expected[index]) return false;
    }
    return true;
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
      if (!ref.mounted) return;
      final content = await _load();
      if (!ref.mounted) return;
      state = AsyncData(content);
      _scheduleAfterBuild(() => _resolveProjectIcons(content.projects));
      _scheduleAfterBuild(() => refreshTakeoverPlan(content.projects));
    } catch (error, stackTrace) {
      if (!ref.mounted) return;
      if (previous == null) {
        state = AsyncError(error, stackTrace);
      } else {
        state = AsyncData(
          previous.copyWith(refreshing: false, refreshError: error),
        );
      }
    }
  }

  Future<LibraryEntryRefresh> refreshEntry(
    LibraryEntryQuery query, {
    bool refreshAgents = true,
  }) async {
    final gateway = _gateway;
    if (refreshAgents) {
      unawaited(ref.read(agentCatalogProvider.notifier).refreshSilently());
    }
    final projects = await gateway.loadAddedProjects();
    final skills = await gateway.listInstalled(projects: projects);
    if (!ref.mounted) {
      return LibraryEntryRefresh(projects: projects, entry: null);
    }
    final current = state.value;
    if (current != null) {
      final content = current.copyWith(
        skills: skills,
        projects: projects,
        refreshing: false,
        clearRefreshError: true,
      );
      state = AsyncData(content);
      _scheduleAfterBuild(() => _resolveProjectIcons(projects));
      _scheduleAfterBuild(() => refreshTakeoverPlan(projects));
    }
    InstalledSkill? entry;
    for (final candidate in skills) {
      if (query.matches(candidate)) {
        entry = candidate;
        break;
      }
    }
    return LibraryEntryRefresh(projects: projects, entry: entry);
  }
}
