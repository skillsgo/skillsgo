/*
 * [INPUT]: Depends on SkillsGateway Mandatory Onboarding contracts, App localization, the SkillsGo branding asset and semantic UI components, AgentLogo, ProjectIdentityIcon, HugeIcons, and Portal Labs PremiumProgressStepper.
 * [OUTPUT]: Provides the blocking two-step first-launch welcome and explicit multi-directory project-addition journey.
 * [POS]: Serves as the clean-install entry surface before the primary App shell initializes its feature controllers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:portal_labs/portal_labs.dart' as portal;

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'brand.dart';
import 'native_components.dart';
import 'project_identity_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.gateway,
    required this.initialState,
    required this.onCompleted,
  });

  final SkillsGateway gateway;
  final OnboardingState initialState;
  final ValueChanged<bool> onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int _currentStep;
  AgentCatalog? _agents;
  Object? _agentError;
  List<AddedProject> _projects = const [];
  Object? _projectsError;
  bool _projectsLoaded = false;
  bool _busy = false;
  String? _notice;
  String? _flowError;
  bool _noticeIsError = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialState.step.index;
    if (_currentStep == OnboardingStep.welcome.index) {
      unawaited(_loadAgents());
    } else {
      unawaited(_loadProjects());
    }
  }

  Future<void> _loadAgents() async {
    if (mounted) {
      setState(() {
        _agents = null;
        _agentError = null;
      });
    }
    try {
      final agents = await widget.gateway.inspectOnboardingAgents();
      if (mounted) setState(() => _agents = agents);
    } catch (error) {
      if (mounted) setState(() => _agentError = error);
    }
  }

  Future<bool> _loadProjects() async {
    if (!_projectsLoaded && mounted) {
      setState(() => _projectsError = null);
    }
    try {
      final projects = await widget.gateway.loadAddedProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _projectsLoaded = true;
          _projectsError = null;
        });
        unawaited(_resolveProjectIcons(projects));
      }
      return true;
    } catch (error) {
      if (mounted) {
        if (_projectsLoaded) {
          _showProjectError();
        } else {
          setState(() => _projectsError = error);
        }
      }
      return false;
    }
  }

  Future<void> _resolveProjectIcons(List<AddedProject> projects) async {
    for (final project in projects.where((project) => project.icon == null)) {
      try {
        final resolved = await widget.gateway.resolveProjectIcon(project);
        if (!mounted || resolved.icon == null) continue;
        final index = _projects.indexWhere((item) => item.id == project.id);
        if (index < 0) continue;
        setState(() {
          _projects = [..._projects]..[index] = resolved;
        });
      } catch (_) {
        // The deterministic monogram remains available when icon discovery fails.
      }
    }
  }

  Future<void> _changeStep(int step) async {
    if (_busy || step == _currentStep) return;
    final onboardingStep = OnboardingStep.values[step];
    setState(() {
      _busy = true;
      _flowError = null;
      _notice = null;
      _noticeIsError = false;
    });
    try {
      await widget.gateway.saveOnboardingStep(onboardingStep);
      if (!mounted) return;
      setState(() => _currentStep = step);
      if (step == OnboardingStep.welcome.index && _agents == null) {
        await _loadAgents();
      } else if (step == OnboardingStep.projects.index && !_projectsLoaded) {
        await _loadProjects();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _flowError = AppLocalizations.of(context).onboardingStateError;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canContinue =>
      !_busy &&
      (_currentStep == OnboardingStep.projects.index || _agents != null) &&
      (_currentStep != OnboardingStep.projects.index ||
          (_projectsLoaded && _projectsError == null));

  KeyEventResult _handleStepperKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        !_busy &&
        _currentStep == OnboardingStep.projects.index) {
      unawaited(_changeStep(OnboardingStep.welcome.index));
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (!_canContinue) return KeyEventResult.handled;
    if (_currentStep == OnboardingStep.projects.index) {
      unawaited(_finish());
    } else {
      unawaited(_changeStep(_currentStep + 1));
    }
    return KeyEventResult.handled;
  }

  Future<void> _addProject() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final projects = await widget.gateway.addProjects();
      if (projects.isEmpty) return;
      final loaded = await _loadProjects();
      if (mounted && loaded) {
        setState(() {
          _notice = null;
          _noticeIsError = false;
        });
      }
    } catch (_) {
      if (mounted) _showProjectError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeProject(AddedProject project) async {
    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index < 0) return;
    setState(() {
      _projects = [..._projects]..removeAt(index);
      _notice = null;
      _noticeIsError = false;
    });
    try {
      await widget.gateway.removeProject(project.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final restored = [..._projects];
        restored.insert(index.clamp(0, restored.length), project);
        _projects = restored;
      });
      _showProjectError();
    }
  }

  void _showProjectError() {
    setState(() {
      _notice = AppLocalizations.of(context).onboardingProjectError;
      _noticeIsError = true;
    });
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.gateway.completeOnboarding();
      if (mounted) {
        widget.onCompleted(_projects.isNotEmpty);
      }
    } catch (_) {
      if (mounted) _showProjectError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.skillsColors.accent;
    return Theme(
      data: buildSkillsTheme(accent, brightness: Brightness.dark),
      child: Builder(builder: _buildSurface),
    );
  }

  Widget _buildSurface(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.skillsColors;
    final components = context.skillsComponents;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: SingleChildScrollView(
                        key: ValueKey(_currentStep),
                        padding: const EdgeInsets.fromLTRB(32, 84, 32, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_flowError != null) ...[
                              SkillsAlert.destructive(
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedAlertCircle,
                                  size: 18,
                                  strokeWidth: 1.8,
                                ),
                                title: Text(_flowError!),
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (_currentStep == OnboardingStep.welcome.index)
                              _WelcomeStep(
                                agents: _agents,
                                error: _agentError,
                                onRetry: _busy ? null : _loadAgents,
                              )
                            else
                              _ProjectsStep(
                                projects: _projects,
                                loaded: _projectsLoaded,
                                loadError: _projectsError,
                                notice: _notice,
                                noticeIsError: _noticeIsError,
                                busy: _busy,
                                onRetry: _loadProjects,
                                onAddProject: _addProject,
                                onRemoveProject: _removeProject,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: _busy,
                    child: AnimatedOpacity(
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 120),
                      opacity: _busy ? .55 : 1,
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: _handleStepperKey,
                        child: portal.PremiumProgressStepper(
                          totalSteps: OnboardingStep.values.length,
                          currentStep: _currentStep,
                          onStepChanged: (step) => unawaited(_changeStep(step)),
                          onFinish: () => unawaited(_finish()),
                          nextText: l10n.onboardingNext,
                          finishText: l10n.onboardingStartUsing,
                          backText: l10n.onboardingBack,
                          canContinue: _canContinue,
                          style: portal.PremiumProgressStepperStyle(
                            activeColor: colors.accent,
                            inactiveColor: colors.borderMuted,
                            dotColor: colors.onAccent,
                            primaryButtonColor: components.primaryRest,
                            primaryButtonTextColor:
                                components.primaryForeground,
                            finishButtonColor: components.primaryRest,
                            secondaryButtonColor: components.controlRest,
                            secondaryButtonTextColor:
                                components.controlForeground,
                            disabledButtonColor: components.controlDisabled,
                            disabledButtonTextColor:
                                components.controlForegroundDisabled,
                            buttonHeight: 44,
                            buttonBorderRadius: 12,
                            indicatorHeight: 24,
                            dotSize: 6,
                            stepSpacing: 20,
                            buttonTextStyle: context.skillsTypography.label
                                .copyWith(fontWeight: FontWeight.w600),
                            enableHaptics: !reducedMotion,
                            padding: const EdgeInsets.fromLTRB(32, 18, 32, 24),
                            springMass: reducedMotion ? .1 : 1,
                            springStiffness: reducedMotion ? 1000 : 150,
                            springDamping: reducedMotion ? 100 : 15,
                            showFinishIcon: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.agents,
    required this.error,
    required this.onRetry,
  });

  final AgentCatalog? agents;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final installed = agents?.installed ?? const <AgentStatus>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/branding/skillsgo-logo.png',
                key: const Key('onboarding-skillsgo-logo'),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.onboardingWelcomeTitle,
                    style: context.skillsTypography.display,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingWelcomeDescription,
                    style: context.skillsTypography.bodySecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Text(
          l10n.onboardingDetectedAgents,
          style: context.skillsTypography.sectionTitle,
        ),
        const SizedBox(height: 16),
        if (error != null)
          SkillsAlert.destructive(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 18,
              strokeWidth: 1.8,
            ),
            title: Text(l10n.onboardingCliErrorTitle),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.onboardingCliErrorDescription),
                const SizedBox(height: 10),
                SkillsButton.ghost(
                  onPressed: onRetry,
                  size: SkillsButtonSize.sm,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          )
        else if (agents == null)
          Semantics(
            liveRegion: true,
            label: l10n.loading,
            child: const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SkillsSkeletonBox(width: 128, height: 44, borderRadius: 12),
                SkillsSkeletonBox(width: 146, height: 44, borderRadius: 12),
              ],
            ),
          )
        else if (installed.isEmpty)
          Text(
            l10n.onboardingNoAgents,
            style: context.skillsTypography.bodySecondary,
          )
        else
          _AgentGrid(agents: installed),
      ],
    );
  }
}

class _AgentGrid extends StatelessWidget {
  const _AgentGrid({required this.agents});

  final List<AgentStatus> agents;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final columnCount = constraints.maxWidth >= 520 ? 3 : 2;
      final itemWidth =
          (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
      return Wrap(
        spacing: spacing,
        runSpacing: 6,
        children: [
          for (final agent in agents)
            SizedBox(
              width: itemWidth,
              child: _AgentChip(agent: agent),
            ),
        ],
      );
    },
  );
}

class _AgentChip extends StatelessWidget {
  const _AgentChip({required this.agent});

  final AgentStatus agent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AgentLogo(agentId: agent.id, displayName: agent.displayName, size: 22),
        const SizedBox(width: 9),
        Text(agent.displayName, style: context.skillsTypography.label),
      ],
    ),
  );
}

class _ProjectsStep extends StatelessWidget {
  const _ProjectsStep({
    required this.projects,
    required this.loaded,
    required this.loadError,
    required this.notice,
    required this.noticeIsError,
    required this.busy,
    required this.onRetry,
    required this.onAddProject,
    required this.onRemoveProject,
  });

  final List<AddedProject> projects;
  final bool loaded;
  final Object? loadError;
  final String? notice;
  final bool noticeIsError;
  final bool busy;
  final Future<bool> Function() onRetry;
  final VoidCallback onAddProject;
  final ValueChanged<AddedProject> onRemoveProject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.onboardingProjectsTitle,
          style: context.skillsTypography.display,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingProjectsDescription,
          style: context.skillsTypography.bodySecondary,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            SkillsButton.ghost(
              height: 40,
              backgroundColor: context.skillsComponents.controlRest,
              enabled: loaded && loadError == null && !busy,
              onPressed: onAddProject,
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedFolderOpen,
                size: 18,
                strokeWidth: 1.8,
              ),
              child: Text(l10n.onboardingAddProject),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.onboardingAddProjectLater,
                    style: context.skillsTypography.bodySecondary,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(child: _InstalledAddProjectPreview()),
                ],
              ),
            ),
          ],
        ),
        if (projects.isNotEmpty) ...[
          const SizedBox(height: 18),
          _OnboardingProjectStrip(
            projects: projects,
            onRemoveProject: onRemoveProject,
          ),
        ],
        if (!loaded && loadError == null) ...[
          const SizedBox(height: 18),
          Semantics(
            liveRegion: true,
            label: l10n.loading,
            child: const SkillsSkeletonBox(height: 16, borderRadius: 8),
          ),
        ],
        if (!loaded && loadError != null) ...[
          const SizedBox(height: 18),
          SkillsAlert.destructive(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 18,
              strokeWidth: 1.8,
            ),
            title: Text(l10n.onboardingProjectsLoadError),
            description: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SkillsButton.ghost(
                onPressed: () => unawaited(onRetry()),
                size: SkillsButtonSize.sm,
                child: Text(l10n.retry),
              ),
            ),
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: 18),
          Text(
            notice!,
            style: context.skillsTypography.bodySecondary.copyWith(
              color: noticeIsError
                  ? context.skillsComponents.statusDanger
                  : context.skillsComponents.statusSuccess,
            ),
          ),
        ],
      ],
    );
  }
}

class _InstalledAddProjectPreview extends StatelessWidget {
  const _InstalledAddProjectPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.skillsColors;
    return Semantics(
      label: '${l10n.library}, ${l10n.addProject}',
      child: ExcludeSemantics(
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.skillsComponents.controlRest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.library, style: context.skillsTypography.label),
              const SizedBox(width: 7),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 13,
                strokeWidth: 1.6,
                color: colors.foregroundMuted,
              ),
              const SizedBox(width: 7),
              HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 15,
                strokeWidth: 1.8,
                color: colors.foregroundDefault,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.addProject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingProjectStrip extends StatelessWidget {
  const _OnboardingProjectStrip({
    required this.projects,
    required this.onRemoveProject,
  });

  final List<AddedProject> projects;
  final ValueChanged<AddedProject> onRemoveProject;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160),
    alignment: Alignment.centerLeft,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const columns = 5;
        final itemWidth = constraints.maxWidth / columns;
        return Wrap(
          runSpacing: 8,
          children: [
            for (var index = 0; index < projects.length; index++)
              Container(
                width: itemWidth,
                padding: EdgeInsets.only(
                  left: index % columns == 0 ? 0 : 10,
                  right: 10,
                ),
                child: _OnboardingProjectItem(
                  key: ValueKey('onboarding-project-${projects[index].id}'),
                  project: projects[index],
                  onRemove: () => onRemoveProject(projects[index]),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _OnboardingProjectItem extends StatefulWidget {
  const _OnboardingProjectItem({
    super.key,
    required this.project,
    required this.onRemove,
  });

  final AddedProject project;
  final VoidCallback onRemove;

  @override
  State<_OnboardingProjectItem> createState() => _OnboardingProjectItemState();
}

class _OnboardingProjectItemState extends State<_OnboardingProjectItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showRemove = _hovered || _focused;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Row(
          children: [
            ProjectIdentityIcon(project: widget.project, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Tooltip(
                message: '${widget.project.name}\n${widget.project.path}',
                child: Text(
                  widget.project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.label,
                ),
              ),
            ),
            const SizedBox(width: 3),
            AnimatedOpacity(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              opacity: showRemove ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showRemove,
                child: SkillsTooltip(
                  builder: (_) => Text(l10n.removeFromList),
                  child: Semantics(
                    label: l10n.removeProjectTitle(widget.project.name),
                    button: true,
                    child: ExcludeSemantics(
                      child: IconButton(
                        key: ValueKey(
                          'onboarding-remove-project-${widget.project.id}',
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        style: const ButtonStyle(
                          shape: WidgetStatePropertyAll(CircleBorder()),
                        ),
                        onPressed: widget.onRemove,
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 13,
                          strokeWidth: 1.8,
                          color: context.skillsColors.foregroundMuted,
                        ),
                      ),
                    ),
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
