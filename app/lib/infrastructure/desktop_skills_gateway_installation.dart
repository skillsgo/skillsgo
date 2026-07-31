/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, Installation Request codecs, file save picker, and discovery/Library models.
 * [OUTPUT]: Provides single-Skill and atomic multi-Skill exact-path Package Store installation using minimal CLI success receipts, reviewed External adoption through the CLI, and explicit protocol-decode failure telemetry.
 * [POS]: Serves as the Installation Request capability inside the DesktopSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'desktop_skills_gateway.dart';

mixin _DesktopSkillsGatewayInstallation on _DesktopSkillsGatewayCore {
  @override
  Future<BatchAdoptionResult> adopt(List<AdoptionRequestItem> items) async {
    if (items.isEmpty) {
      throw const SkillsException(
        'Select at least one External Skill to adopt.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final request = jsonEncode({
      'schemaVersion': 1,
      'items': [
        for (final item in items)
          {
            'inventoryKey': item.inventoryKey,
            'name': item.name,
            'packagePath': item.packagePath,
            'version': item.version,
            'skillPath': item.skillPath,
            'targets': [
              for (final target in item.targets)
                {
                  'agent': target.agent,
                  'scope': target.scope.name,
                  if (target.projectRoot.isNotEmpty)
                    'projectRoot': target.projectRoot,
                  'path': target.path,
                },
            ],
          },
      ],
    });
    final appVersion = await loadAppVersion();
    final command = await _runCli([
      'adopt',
      '--input',
      '-',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
      if (appVersion.trim().isNotEmpty) ...['--app-version', appVersion.trim()],
    ], stdin: request);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final raw = jsonDecode(command.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 1 ||
          raw['results'] is! List) {
        throw const FormatException();
      }
      final byInventoryKey = {
        for (final item in items) item.inventoryKey: item,
      };
      if (byInventoryKey.length != items.length) throw const FormatException();
      final seenInventoryKeys = <String>{};
      final results = <BatchAdoptionItemResult>[];
      for (final value in raw['results'] as List) {
        if (value is! Map<String, dynamic> ||
            value['inventoryKey'] is! String ||
            value['status'] is! String) {
          throw const FormatException();
        }
        final inventoryKey = value['inventoryKey'] as String;
        final status = value['status'] as String;
        final reason = value['reason'];
        final item = byInventoryKey[inventoryKey];
        if (item == null ||
            !seenInventoryKeys.add(inventoryKey) ||
            (status != 'adopted' && status != 'failed') ||
            (reason != null && reason is! String)) {
          throw const FormatException();
        }
        results.add(
          BatchAdoptionItemResult(
            name: item.name,
            skillId: '${item.packagePath}:${item.skillPath}',
            status: status == 'adopted'
                ? BatchAdoptionItemStatus.adopted
                : BatchAdoptionItemStatus.failed,
            reason: reason as String? ?? '',
          ),
        );
      }
      if (results.length != items.length) throw const FormatException();
      final adopted = results
          .where((result) => result.status == BatchAdoptionItemStatus.adopted)
          .length;
      return BatchAdoptionResult(
        adopted: adopted,
        failed: results.length - adopted,
        items: List.unmodifiable(results),
      );
    } on Object catch (error, stackTrace) {
      if (error is! FormatException && error is! TypeError) rethrow;
      throw _invalidCliResponse(
        'adopt',
        'The SkillsGo CLI returned invalid Adoption JSON.',
        command,
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    final executions = await _installPackageMembers(
      [skill],
      immutableVersion,
      selections,
    );
    return executions.single;
  }

  @override
  Future<List<InstallationExecution>> installPackageTargets(
    List<SkillSummary> skills,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    if (skills.isEmpty) {
      throw const SkillsException(
        'Select at least one Package Skill.',
        kind: SkillsFailureKind.validation,
      );
    }
    final packagePath = skills.first.packagePath;
    final immutableVersion = skills.first.latestVersion;
    if (skills.any(
      (skill) =>
          skill.packagePath != packagePath ||
          skill.latestVersion != immutableVersion,
    )) {
      throw const SkillsException(
        'Package installation requires one Package version.',
        kind: SkillsFailureKind.validation,
      );
    }
    return _installPackageMembers(skills, immutableVersion, selections);
  }

  Future<List<InstallationExecution>> _installPackageMembers(
    List<SkillSummary> skills,
    String immutableVersion,
    List<InstallationTargetSelection> selections,
  ) async {
    if (immutableVersion.isEmpty || selections.isEmpty) {
      throw const SkillsException(
        'Select at least one Installation Target.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final groups = _installationSelectionGroups(selections);
    final appVersion = await loadAppVersion();
    var succeededTargets = 0;
    for (final group in groups.values) {
      final arguments = _packageAddArguments(
        skills,
        immutableVersion,
        group,
        appVersion,
      );
      final command = await _runCli(arguments);
      if (!command.succeeded) throw _commandFailure(command);
      try {
        final payload = jsonDecode(command.output.stdout);
        _validatePackageInstallationReceipt(
          payload,
          skills.first.packagePath,
          immutableVersion,
        );
        succeededTargets += group.length;
      } on Object catch (error, stackTrace) {
        if (error is! FormatException && error is! TypeError) rethrow;
        throw _invalidCliResponse(
          'install_package_members',
          'The SkillsGo CLI returned invalid Package Installation JSON.',
          command,
          error,
          stackTrace,
        );
      }
    }
    return List.unmodifiable([
      for (var index = 0; index < skills.length; index++)
        InstallationExecution(
          packagePath: skills[index].packagePath,
          skillName: skills[index].name,
          version: immutableVersion,
          name: skills[index].installName,
          results: const [],
          summary: InstallationExecutionSummary(
            succeeded: succeededTargets,
            skipped: 0,
            conflict: 0,
            failed: 0,
          ),
        ),
    ]);
  }

  Map<String, List<InstallationTargetSelection>> _installationSelectionGroups(
    List<InstallationTargetSelection> selections,
  ) {
    final groups = <String, List<InstallationTargetSelection>>{};
    for (final selection in selections) {
      final key = '${selection.scope.name}\u0000${selection.projectRoot}';
      groups.putIfAbsent(key, () => []).add(selection);
    }
    return groups;
  }

  List<String> _packageAddArguments(
    List<SkillSummary> skills,
    String immutableVersion,
    List<InstallationTargetSelection> group,
    String appVersion,
  ) {
    final first = group.first;
    return [
      'add',
      '${skills.first.packagePath}@$immutableVersion',
      for (final skill in skills) ...[
        '--skill-path',
        skill.installationSelector,
      ],
      for (final selection in group) ...['--agent', selection.agent],
      if (first.scope == InstallationScope.global) '--global',
      if (first.scope == InstallationScope.project) ...[
        '--project',
        first.projectRoot,
      ],
      '--yes',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
      if (appVersion.trim().isNotEmpty) ...['--app-version', appVersion.trim()],
    ];
  }
}
