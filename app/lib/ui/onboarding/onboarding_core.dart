/*
 * [INPUT]: Depends on the Onboarding journey library, SkillsGateway state, Portal Labs PremiumProgressStepper, project persistence, and completion routing.
 * [OUTPUT]: Provides the public OnboardingScreen plus CLI/Agent/project loading, resumable step state, add/remove actions, completion, and root two-step rendering.
 * [POS]: Serves as the state-owning core of Mandatory Onboarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../onboarding_screen.dart';

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
    final backKey = Directionality.of(context) == TextDirection.rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    if (event.logicalKey == backKey &&
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
