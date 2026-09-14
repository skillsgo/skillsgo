/*
 * [INPUT]: Uses the SkillsGo task presentation widgets, localized Material shell, and deterministic discovery summaries.
 * [OUTPUT]: Specifies the bottom-right installation task stack's running, success, failure, dismissal, and visible-cap behavior.
 * [POS]: Serves as focused rendered regression coverage for App-scoped installation task feedback.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/l10n/app_localizations.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/installation_task_controller.dart';
import 'package:skillsgo/ui/installation_task_stack.dart';

void main() {
  testWidgets('task stack renders bounded live operation states', (
    tester,
  ) async {
    late BuildContext taskContext;
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildSkillsTheme(
          const Color(0xFF514532),
          brightness: Brightness.light,
        ),
        home: InstallationTaskScope(
          child: Builder(
            builder: (context) {
              taskContext = context;
              return const Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [InstallationTaskStack()],
                ),
              );
            },
          ),
        ),
      ),
    );

    final controller = InstallationTaskScope.of(taskContext);
    final first = controller.start(_skill('one', 'First Skill'));
    final second = controller.start(_skill('two', 'Second Skill'));
    controller.start(_skill('three', 'Third Skill'));
    controller.start(_skill('four', 'Fourth Skill'));
    controller.succeed(first);
    controller.fail(second, 'Network unavailable');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('installation-task-stack')), findsOneWidget);
    expect(find.text('Fourth Skill'), findsOneWidget);
    expect(find.text('Third Skill'), findsOneWidget);
    expect(find.text('Second Skill'), findsOneWidget);
    expect(find.text('First Skill'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(find.text('Network unavailable'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('installation-task-status-$second')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Second Skill'), findsNothing);
  });
}

SkillSummary _skill(String id, String name) => SkillSummary(
  packagePath: 'github.com/skillsgo/$id',
  installName: id,
  name: name,
  description: 'A concise description for $name.',
);
