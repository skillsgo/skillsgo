/*
 * [INPUT]: Depends on InstalledSkill targets, project/Agent identity, update state, selection callbacks, clipboard feedback, and scope popovers.
 * [OUTPUT]: Provides installed Skill rows plus user/project scope summaries, Agent rows, popovers, and copyable project paths.
 * [POS]: Serves as the installed target presentation segment of the unified Library journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

class _InstalledSkillRow extends StatelessWidget {
  const _InstalledSkillRow({
    required this.skill,
    required this.projects,
    required this.selected,
    required this.agentLabel,
    required this.onOpen,
    required this.onSelectionChanged,
  });

  final InstalledSkill skill;
  final List<AddedProject> projects;
  final bool selected;
  final String Function(String) agentLabel;
  final VoidCallback onOpen;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainer : Colors.transparent,
          border: BorderDirectional(
            start: BorderSide(
              color: selected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 10, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: SkillsCheckbox(
                    key: ValueKey('library-select-${skill.inventoryKey}'),
                    value: selected,
                    onChanged: onSelectionChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        textDirection: contentTextDirection(skill.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skill.description.trim().isEmpty
                            ? _installationCoverageLabel(
                                context,
                                skill,
                                projects,
                              )
                            : skill.description.trim(),
                        textDirection: contentTextDirection(
                          skill.description.trim().isEmpty
                              ? _installationCoverageLabel(
                                  context,
                                  skill,
                                  projects,
                                )
                              : skill.description.trim(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LibraryInstallationScopeSummary(
                    skill: skill,
                    projects: projects,
                    agentLabel: agentLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryInstallationScopeSummary extends StatelessWidget {
  const _LibraryInstallationScopeSummary({
    required this.skill,
    required this.projects,
    required this.agentLabel,
  });

  final InstalledSkill skill;
  final List<AddedProject> projects;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    final groups = _installationScopeGroups(skill, projects);
    if (groups.isEmpty) return const SizedBox.shrink();
    final user = groups.where((group) => group.project == null).firstOrNull;
    final projectGroups = groups
        .where((group) => group.project != null)
        .toList(growable: false);
    return Semantics(
      label: groups.map((group) => group.semanticLabel(agentLabel)).join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: 39,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 18,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: user == null
                    ? const SizedBox.shrink()
                    : _ScopeAgentRow(
                        agents: user.agents,
                        agentLabel: agentLabel,
                      ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 18,
              child: _ProjectScopeLine(
                groups: projectGroups,
                agentLabel: agentLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectScopeLine extends StatelessWidget {
  const _ProjectScopeLine({required this.groups, required this.agentLabel});

  final List<_InstallationScopeGroup> groups;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (groups.isEmpty) return const SizedBox.shrink();
    final visible = groups.take(2).toList(growable: false);
    final hidden = groups.length - visible.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant,
              ),
            ),
          Flexible(
            child: _ProjectScopeSegment(
              group: visible[index],
              agentLabel: agentLabel,
            ),
          ),
        ],
        if (hidden > 0) ...[
          const SizedBox(width: 7),
          Text(
            '+$hidden',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _ProjectScopeSegment extends StatelessWidget {
  const _ProjectScopeSegment({required this.group, required this.agentLabel});

  final _InstallationScopeGroup group;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    final project = group.project!;
    return _ProjectScopePopover(
      project: project,
      agents: group.agents,
      agentLabel: agentLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProjectIdentityIcon(project: project, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              project.name,
              textDirection: contentTextDirection(project.name),
              key: ValueKey('library-scope-project-${project.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeAgentRow extends StatelessWidget {
  const _ScopeAgentRow({required this.agents, required this.agentLabel});

  final List<String> agents;
  final String Function(String) agentLabel;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    const gap = 5.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleCount = constraints.maxWidth.isFinite
            ? math.max(
                1,
                math.min(
                  agents.length,
                  ((constraints.maxWidth - 30 + gap) / (size + gap)).floor(),
                ),
              )
            : agents.length;
        final hiddenCount = agents.length - visibleCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visibleCount; index++) ...[
              if (index > 0) const SizedBox(width: gap),
              Tooltip(
                message: agentLabel(agents[index]),
                child: AgentLogo(
                  agentId: agents[index],
                  displayName: agentLabel(agents[index]),
                  size: size,
                ),
              ),
            ],
            if (hiddenCount > 0) ...[
              const SizedBox(width: 7),
              Text(
                '+$hiddenCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProjectScopePopover extends StatelessWidget {
  const _ProjectScopePopover({
    required this.project,
    required this.agents,
    required this.agentLabel,
    required this.child,
  });

  final AddedProject project;
  final List<String> agents;
  final String Function(String) agentLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return JustTooltip(
      direction: TooltipDirection.bottom,
      alignment: TooltipAlignment.endTargetCenter,
      offset: 6,
      screenMargin: 16,
      enableTap: false,
      enableHover: true,
      interactive: true,
      waitDuration: const Duration(milliseconds: 80),
      animation: MediaQuery.disableAnimationsOf(context)
          ? TooltipAnimation.none
          : TooltipAnimation.fade,
      animationDuration: const Duration(milliseconds: 100),
      theme: JustTooltipTheme(
        backgroundColor: context.skillsComponents.controlRest,
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderColor: context.skillsComponents.controlBorder,
        borderWidth: 1,
        textStyle: TextStyle(color: scheme.onSurface),
        elevation: 0,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        showArrow: true,
        arrowBaseWidth: 12,
        arrowLength: 6,
      ),
      tooltipBuilder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(380, MediaQuery.sizeOf(context).width - 52),
          maxHeight: 280,
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.pathLabel,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              _CopyableProjectPath(project: project),
              const SizedBox(height: 8),
              Text(
                context.l10n.agents,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              for (final agent in agents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AgentLogo(
                        agentId: agent,
                        displayName: agentLabel(agent),
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        agentLabel(agent),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}

class _CopyableProjectPath extends StatefulWidget {
  const _CopyableProjectPath({required this.project});

  final AddedProject project;

  @override
  State<_CopyableProjectPath> createState() => _CopyableProjectPathState();
}

class _CopyableProjectPathState extends State<_CopyableProjectPath> {
  Timer? _feedbackTimer;
  bool _copied = false;

  Future<void> _copy() async {
    _feedbackTimer?.cancel();
    setState(() => _copied = true);
    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
    await Clipboard.setData(ClipboardData(text: widget.project.path));
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.project.path,
            textDirection: TextDirection.ltr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 5),
        IconButton(
          key: ValueKey(
            _copied
                ? 'copy-project-path-copied-${widget.project.id}'
                : 'copy-project-path-${widget.project.id}',
          ),
          tooltip: _copied
              ? context.l10n.projectPathCopied
              : context.l10n.copyProjectPath,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 26, height: 26),
          padding: EdgeInsets.zero,
          onPressed: _copy,
          icon: AnimatedSwitcher(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 140),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: HugeIcon(
              key: ValueKey(_copied),
              icon: _copied
                  ? HugeIcons.strokeRoundedCopyCheck
                  : HugeIcons.strokeRoundedCopy01,
              size: 15,
              strokeWidth: 1.7,
              color: _copied ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
