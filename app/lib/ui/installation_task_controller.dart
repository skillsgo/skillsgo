/*
 * [INPUT]: Depends on Flutter foundation primitives and immutable Skill discovery summaries.
 * [OUTPUT]: Provides App-scoped, presentation-only installation task state for the floating task stack.
 * [POS]: Serves as the temporary UI task boundary until the CLI exposes durable asynchronous operation identifiers and progress events.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/skills_gateway.dart';

enum InstallationTaskStatus { running, succeeded, failed }

@immutable
class InstallationTask {
  const InstallationTask({
    required this.id,
    required this.skill,
    required this.status,
    required this.startedAt,
    this.failureMessage,
  });

  final String id;
  final SkillSummary skill;
  final InstallationTaskStatus status;
  final DateTime startedAt;
  final String? failureMessage;

  InstallationTask copyWith({
    InstallationTaskStatus? status,
    String? failureMessage,
  }) => InstallationTask(
    id: id,
    skill: skill,
    status: status ?? this.status,
    startedAt: startedAt,
    failureMessage: failureMessage ?? this.failureMessage,
  );
}

class InstallationTaskController extends ChangeNotifier {
  InstallationTaskController({List<InstallationTask> initialTasks = const []})
    : _tasks = List.of(initialTasks);

  final List<InstallationTask> _tasks;
  final Map<String, Timer> _dismissTimers = {};
  bool _disposed = false;

  List<InstallationTask> get tasks => List.unmodifiable(_tasks);

  String start(SkillSummary skill) {
    if (_disposed) return '';
    final id =
        '${skill.versionedCoordinateKey}-${DateTime.now().microsecondsSinceEpoch}';
    _tasks.insert(
      0,
      InstallationTask(
        id: id,
        skill: skill,
        status: InstallationTaskStatus.running,
        startedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return id;
  }

  void succeed(String id) {
    if (_disposed || id.isEmpty) return;
    _replace(
      id,
      (task) => task.copyWith(status: InstallationTaskStatus.succeeded),
    );
    _dismissTimers[id]?.cancel();
    _dismissTimers[id] = Timer(const Duration(seconds: 5), () => dismiss(id));
  }

  void fail(String id, String message) {
    if (_disposed || id.isEmpty) return;
    _replace(
      id,
      (task) => task.copyWith(
        status: InstallationTaskStatus.failed,
        failureMessage: message,
      ),
    );
  }

  void dismiss(String id) {
    if (_disposed || id.isEmpty) return;
    _dismissTimers.remove(id)?.cancel();
    final previousLength = _tasks.length;
    _tasks.removeWhere((task) => task.id == id);
    if (_tasks.length != previousLength) notifyListeners();
  }

  void _replace(
    String id,
    InstallationTask Function(InstallationTask task) update,
  ) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    _tasks[index] = update(_tasks[index]);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

class InstallationTaskScope extends StatefulWidget {
  const InstallationTaskScope({
    super.key,
    required this.child,
    this.initialTasks = const [],
  });

  final Widget child;
  final List<InstallationTask> initialTasks;

  static InstallationTaskController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_InstallationTaskInherited>()!
      .controller;

  @override
  State<InstallationTaskScope> createState() => _InstallationTaskScopeState();
}

class _InstallationTaskScopeState extends State<InstallationTaskScope> {
  late final InstallationTaskController controller;

  @override
  void initState() {
    super.initState();
    controller = InstallationTaskController(initialTasks: widget.initialTasks);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _InstallationTaskInherited(controller: controller, child: widget.child);
}

class _InstallationTaskInherited
    extends InheritedNotifier<InstallationTaskController> {
  const _InstallationTaskInherited({
    required InstallationTaskController controller,
    required super.child,
  }) : super(notifier: controller);

  InstallationTaskController get controller => notifier!;
}
