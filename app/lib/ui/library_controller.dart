/*
 * [INPUT]: Depends on Dart async support, Riverpod, SkillsGateway Library contracts and its optional analytics progress/invalidation capabilities, the App-scoped Gateway provider, and shared AgentCatalog state.
 * [OUTPUT]: Provides immutable Library content with live analytics progress, stable Entry queries, targeted post-mutation reconciliation, single-flight loading, background usage enrichment driven by CLI analytics invalidations, bounded compatibility polling, stale-content refresh, lifecycle-safe project-icon enrichment, and stable load failures.
 * [POS]: Serves as the deep Library Inventory module while widgets retain only short-lived filtering, selection, and navigation state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'app_providers.dart';

class LibraryContentState {
  const LibraryContentState({
    required this.skills,
    required this.agentCatalog,
    required this.projects,
    this.analyticsProgress,
    this.refreshing = false,
    this.refreshError,
  });

  final List<InstalledSkill> skills;
  final AgentCatalog agentCatalog;
  final List<AddedProject> projects;
  final AnalyticsSyncProgress? analyticsProgress;
  final bool refreshing;
  final Object? refreshError;

  LibraryContentState copyWith({
    List<InstalledSkill>? skills,
    AgentCatalog? agentCatalog,
    List<AddedProject>? projects,
    AnalyticsSyncProgress? analyticsProgress,
    bool? refreshing,
    Object? refreshError,
    bool clearRefreshError = false,
  }) => LibraryContentState(
    skills: skills ?? this.skills,
    agentCatalog: agentCatalog ?? this.agentCatalog,
    projects: projects ?? this.projects,
    analyticsProgress: analyticsProgress ?? this.analyticsProgress,
    refreshing: refreshing ?? this.refreshing,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );
}

class LibraryEntryQuery {
  const LibraryEntryQuery._(
    this._inventoryKey,
    this._packagePath,
    this._skillName,
    this._targetPath,
    this._agent,
  );

  factory LibraryEntryQuery.byInventoryKey(String inventoryKey) =>
      LibraryEntryQuery._(inventoryKey, '', '', null, null);

  factory LibraryEntryQuery.byCoordinate({
    required String packagePath,
    required String skillName,
    String? targetPath,
    String? agent,
  }) => LibraryEntryQuery._('', packagePath, skillName, targetPath, agent);

  final String _inventoryKey;
  final String _packagePath;
  final String _skillName;
  final String? _targetPath;
  final String? _agent;

  bool matches(InstalledSkill entry) {
    if (_inventoryKey.isNotEmpty) return entry.inventoryKey == _inventoryKey;
    final skillMatches =
        _packagePath.isNotEmpty &&
        _skillName.isNotEmpty &&
        entry.packagePath == _packagePath &&
        entry.name == _skillName;
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
  final _scheduledTasks = <Timer>{};
  StreamSubscription<int>? _analyticsInvalidations;
  StreamSubscription<AnalyticsSyncProgress>? _analyticsProgress;
  AnalyticsSyncProgress? _latestAnalyticsProgress;
  Timer? _usageDebounce;
  Timer? _usagePendingPoll;
  Future<LibraryContentState>? _initialLoad;
  bool _resolvingUsage = false;
  bool _usageRefreshPending = false;

  @override
  Future<LibraryContentState> build() async {
    ref.onDispose(() {
      for (final task in _scheduledTasks) {
        task.cancel();
      }
      _scheduledTasks.clear();
      unawaited(_analyticsInvalidations?.cancel());
      unawaited(_analyticsProgress?.cancel());
      _usageDebounce?.cancel();
      _usagePendingPoll?.cancel();
    });
    final request = _load();
    _initialLoad = request;
    late final LibraryContentState content;
    try {
      content = await request;
    } finally {
      if (identical(_initialLoad, request)) _initialLoad = null;
    }
    if (!ref.mounted) return content;
    _scheduleAfterBuild(() => _resolveProjectIcons(content.projects));
    _scheduleAfterBuild(() => _resolveUsage(content.projects));
    _watchAnalyticsEvents();
    return content.copyWith(analyticsProgress: _latestAnalyticsProgress);
  }

  void _watchAnalyticsEvents() {
    final gateway = _gateway;
    if (_analyticsInvalidations == null &&
        gateway is AnalyticsInvalidationSource) {
      final source = gateway as AnalyticsInvalidationSource;
      _analyticsInvalidations = source.watchAnalyticsInvalidations().listen((
        _,
      ) {
        _usageDebounce?.cancel();
        _usageDebounce = Timer(const Duration(milliseconds: 250), () {
          final current = state.value;
          if (ref.mounted && current != null) {
            unawaited(_resolveUsage(current.projects));
          }
        });
      });
    }
    if (_analyticsProgress == null && gateway is AnalyticsProgressSource) {
      final source = gateway as AnalyticsProgressSource;
      _analyticsProgress = source.watchAnalyticsProgress().listen((progress) {
        _latestAnalyticsProgress = progress;
        final current = state.value;
        if (current != null &&
            (current.analyticsProgress?.revision ?? 0) < progress.revision) {
          state = AsyncData(current.copyWith(analyticsProgress: progress));
        }
      });
    }
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

  Future<void> _resolveUsage(List<AddedProject> projects) async {
    if (_resolvingUsage) {
      _usageRefreshPending = true;
      return;
    }
    _resolvingUsage = true;
    try {
      do {
        _usageRefreshPending = false;
        final before = state.value;
        final inventoryKeys = before?.skills
            .map((skill) => skill.inventoryKey)
            .toList(growable: false);
        final enriched = await _gateway.listInstalled(
          projects: projects,
          includeUsage: true,
        );
        if (!ref.mounted) return;
        final current = state.value;
        if (current == null ||
            !listEquals<String>(
              current.projects.map((project) => project.path).toList(),
              projects.map((project) => project.path).toList(),
            ) ||
            !listEquals<String>(
              current.skills.map((skill) => skill.inventoryKey).toList(),
              inventoryKeys,
            )) {
          return;
        }
        state = AsyncData(current.copyWith(skills: enriched));
        _usagePendingPoll?.cancel();
        if (enriched.any(
          (skill) => skill.usageState == SkillUsageState.loading,
        )) {
          _usagePendingPoll = Timer(const Duration(seconds: 2), () {
            final latest = state.value;
            if (ref.mounted && latest != null) {
              unawaited(_resolveUsage(latest.projects));
            }
          });
        }
      } while (_usageRefreshPending && ref.mounted);
    } catch (error) {
      // Usage is optional enrichment; local Library inventory remains valid.
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            skills: current.skills
                .map(
                  (skill) => skill.usageState == SkillUsageState.loading
                      ? skill.withUsageState(
                          SkillUsageState.unavailable,
                          error: error.toString(),
                        )
                      : skill,
                )
                .toList(growable: false),
          ),
        );
      }
    } finally {
      _resolvingUsage = false;
      if (_usageRefreshPending && ref.mounted) {
        _usageRefreshPending = false;
        final current = state.value;
        if (current != null) {
          _scheduleAfterBuild(() => _resolveUsage(current.projects));
        }
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

  Future<void> refresh() async {
    final initialLoad = _initialLoad;
    if (initialLoad != null) {
      try {
        final content = await initialLoad;
        final catalog = await ref.read(agentCatalogProvider.notifier).refresh();
        if (ref.mounted) {
          state = AsyncData(content.copyWith(agentCatalog: catalog));
        }
      } catch (error, stackTrace) {
        if (ref.mounted) {
          final content = state.value;
          state = content == null
              ? AsyncError(error, stackTrace)
              : AsyncData(content.copyWith(refreshError: error));
        }
      }
      return;
    }
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
      _scheduleAfterBuild(() => _resolveUsage(content.projects));
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
