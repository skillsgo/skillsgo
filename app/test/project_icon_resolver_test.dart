/*
 * [INPUT]: Depends on temporary local directories, SharedPreferences test storage, AddedProject models, and ProjectIconResolver.
 * [OUTPUT]: Verifies bounded high-confidence discovery, unsafe candidate rejection, stable caching, and monogram text generation.
 * [POS]: Serves as the behavioral contract for non-blocking Added Project identity enrichment.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/project_icon_resolver.dart';
import 'package:skillsgo/ui/project_identity_icon.dart';

void main() {
  const resolver = ProjectIconResolver();
  late Directory root;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('skillsgo-project-icon-');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  AddedProject project() => AddedProject(
    id: 'project-1',
    name: 'skill-manager',
    path: root.path,
    accessState: ProjectAccessState.accessible,
  );

  test('selects a high-confidence icon within three directory levels', () async {
    final nested = Directory('${root.path}/src/assets')
      ..createSync(recursive: true);
    final icon = File('${nested.path}/app-icon.png');
    await icon.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

    final resolved = await resolver.resolve(project());

    expect(resolved?.path, icon.path);
    expect((await resolver.cached('project-1'))?.path, icon.path);
  });

  test('prefers a project-name logo over unrelated branded assets', () async {
    final assets = Directory('${root.path}/assets')..createSync();
    final projectLogo = File('${assets.path}/skill_manager_logo.svg');
    await projectLogo.writeAsString('<svg viewBox="0 0 32 32"></svg>');
    final vendorAssets = Directory('${assets.path}/harness-logos')
      ..createSync();
    await File(
      '${vendorAssets.path}/codex-logo.svg',
    ).writeAsString('<svg viewBox="0 0 32 32"></svg>');

    final resolved = await resolver.resolve(project());

    expect(resolved?.path, projectLogo.path);
  });

  test('prefers a browser tab favicon over the project logo', () async {
    final assets = Directory('${root.path}/assets')..createSync();
    await File(
      '${assets.path}/skill_manager_logo.svg',
    ).writeAsString('<svg viewBox="0 0 32 32"></svg>');
    final public = Directory('${root.path}/frontend/public')
      ..createSync(recursive: true);
    final favicon = File('${public.path}/favicon.svg');
    await favicon.writeAsString('<svg viewBox="0 0 32 32"></svg>');

    final resolved = await resolver.resolve(project());

    expect(resolved?.path, favicon.path);
  });

  test('rejects candidates below trusted directories and unsafe SVG', () async {
    final tooDeep = Directory('${root.path}/one/two/three/four')
      ..createSync(recursive: true);
    await File(
      '${tooDeep.path}/icon.png',
    ).writeAsBytes(const [137, 80, 78, 71]);
    await File(
      '${root.path}/icon.svg',
    ).writeAsString('<svg><script>alert(1)</script></svg>');

    expect(await resolver.resolve(project()), isNull);
  });

  test('project initials remain deterministic', () {
    expect(projectInitials('skill-manager'), 'SM');
    expect(projectInitials('stockholm'), 'ST');
    expect(projectInitials('工具箱'), '工具');
  });
}
