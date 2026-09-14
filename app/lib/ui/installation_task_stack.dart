/*
 * [INPUT]: Depends on App-scoped installation task state, SkillsGo semantic tokens, Package avatars, HugeIcons, and localized installation status copy.
 * [OUTPUT]: Renders a bottom-right, non-blocking stack of compact Skill installation task cards with running, success, and failure indicators.
 * [POS]: Serves as the App-shell presentation for in-flight and recently completed installation work.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import 'brand.dart';
import 'installation_task_controller.dart';

class InstallationTaskStack extends StatelessWidget {
  const InstallationTaskStack({super.key});

  static const maxVisibleTasks = 3;

  @override
  Widget build(BuildContext context) {
    final controller = InstallationTaskScope.of(context);
    final tasks = controller.tasks.take(maxVisibleTasks).toList();
    if (tasks.isEmpty) return const SizedBox.shrink();

    return PositionedDirectional(
      key: const Key('installation-task-stack'),
      end: 36,
      bottom: 34,
      width: 380,
      child: SafeArea(
        minimum: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final task in tasks)
              Padding(
                key: ValueKey('installation-task-slot-${task.id}'),
                padding: const EdgeInsets.only(top: 10),
                child: _InstallationTaskCard(
                  task: task,
                  onDismiss: task.status == InstallationTaskStatus.running
                      ? null
                      : () => controller.dismiss(task.id),
                ),
              ),
            if (controller.tasks.length > maxVisibleTasks)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '+${controller.tasks.length - maxVisibleTasks}',
                    style: context.skillsTypography.caption.copyWith(
                      color: context.skillsColors.foregroundMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InstallationTaskCard extends StatelessWidget {
  const _InstallationTaskCard({required this.task, required this.onDismiss});

  final InstallationTask task;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final colors = context.skillsColors;
    final l10n = AppLocalizations.of(context);
    final statusLabel = switch (task.status) {
      InstallationTaskStatus.running => l10n.loading,
      InstallationTaskStatus.succeeded => l10n.installationSucceeded,
      InstallationTaskStatus.failed => l10n.installationFailed,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${task.skill.name}, $statusLabel',
      child: AnimatedContainer(
        key: ValueKey('installation-task-${task.id}'),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: components.overlay,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: components.overlayBorder),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: .16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            PackageAvatar(
              source: task.skill.packagePath,
              imageUrl: task.skill.imageUrl,
              size: 48,
              borderRadius: 14,
              backgroundColor: colors.surfaceInset,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.skill.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.skillsTypography.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    task.status == InstallationTaskStatus.failed &&
                            task.failureMessage?.trim().isNotEmpty == true
                        ? task.failureMessage!
                        : task.skill.description.trim().isEmpty
                        ? statusLabel
                        : task.skill.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.skillsTypography.caption.copyWith(
                      color: colors.foregroundMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _TaskStatusButton(task: task, onDismiss: onDismiss),
          ],
        ),
      ),
    );
  }
}

class _TaskStatusButton extends StatelessWidget {
  const _TaskStatusButton({required this.task, required this.onDismiss});

  final InstallationTask task;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    final (background, foreground, icon) = switch (task.status) {
      InstallationTaskStatus.running => (
        components.statusAccentContainer,
        components.statusAccent,
        null,
      ),
      InstallationTaskStatus.succeeded => (
        components.statusSuccessContainer,
        components.statusSuccess,
        HugeIcons.strokeRoundedCheckmarkCircle02,
      ),
      InstallationTaskStatus.failed => (
        components.statusDangerContainer,
        components.statusDanger,
        HugeIcons.strokeRoundedAlertCircle,
      ),
    };

    final child = AnimatedContainer(
      key: ValueKey('installation-task-status-${task.id}'),
      duration: const Duration(milliseconds: 260),
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        child: icon == null
            ? SizedBox.square(
                key: ValueKey('installation-task-progress-${task.id}'),
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: foreground,
                ),
              )
            : HugeIcon(
                key: ValueKey('${task.status.name}-${task.id}'),
                icon: icon,
                size: 21,
                color: foreground,
                strokeWidth: 2,
              ),
      ),
    );

    if (onDismiss == null) return child;
    return Tooltip(
      message: MaterialLocalizations.of(context).closeButtonLabel,
      child: InkResponse(
        onTap: onDismiss,
        radius: 25,
        customBorder: const CircleBorder(),
        child: child,
      ),
    );
  }
}
