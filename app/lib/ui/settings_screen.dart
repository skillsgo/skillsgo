/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, HugeIcons, appearance callbacks, gateway settings operations, localization, shared components, and secondary-body entrance motion.
 * [OUTPUT]: Provides a focused, flat Settings destination with short depth entrances between secondary routes, personalization, reminder preferences, Agent detection and recovery, plus infrequent Hub, risk, and Onboarding re-entry controls.
 * [POS]: Serves as the user-facing Settings feature, keeping diagnostics conditional and developer inspection out of ordinary navigation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

enum _SettingsRoute { general, reminders, agents, advanced }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.gateway,
    required this.folderTheme,
    required this.onFolderThemeChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.language,
    required this.onLanguageChanged,
    required this.wallpaper,
    required this.onWallpaperChanged,
    required this.onRestartOnboarding,
  });
  final SkillsGateway gateway;
  final String folderTheme;
  final ValueChanged<Color> onFolderThemeChanged;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final AppWallpaper wallpaper;
  final ValueChanged<AppWallpaper> onWallpaperChanged;
  final Future<void> Function() onRestartOnboarding;
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  final hubController = TextEditingController();
  final scrollController = ScrollController();
  late final AnimationController _wallpaperIndicator;
  int _wallpaperColumns = 0;
  Offset? _wallpaperIndicatorFrom;
  Offset? _wallpaperIndicatorTo;
  _SettingsRoute selectedRoute = _SettingsRoute.general;
  CliStatus? status;
  HubStatus? hubStatus;
  PersonalRiskPolicy? riskPolicy;
  ReminderSettings reminderSettings = const ReminderSettings();
  bool detecting = true;
  bool loadingSettings = true;
  bool testingHub = false;
  bool restartingOnboarding = false;
  String? notice;
  AgentCatalog? get agentCatalog => ref.watch(agentCatalogProvider).catalog;
  Object? get agentInspectionError => ref.watch(agentCatalogProvider).error;

  @override
  void initState() {
    super.initState();
    _wallpaperIndicator = AnimationController.unbounded(vsync: this, value: 1)
      ..addListener(_rebuildWallpaperIndicator);
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallpaper != widget.wallpaper && _wallpaperColumns > 0) {
      _moveWallpaperIndicatorTo(widget.wallpaper);
    }
  }

  void _rebuildWallpaperIndicator() {
    if (mounted) setState(() {});
  }

  Offset _wallpaperCoordinate(AppWallpaper wallpaper, int columns) {
    final index = AppWallpaper.values.indexOf(wallpaper);
    return Offset((index % columns).toDouble(), (index ~/ columns).toDouble());
  }

  void _moveWallpaperIndicatorTo(AppWallpaper wallpaper) {
    final target = _wallpaperCoordinate(wallpaper, _wallpaperColumns);
    if (MediaQuery.disableAnimationsOf(context)) {
      _wallpaperIndicator.stop();
      _wallpaperIndicatorFrom = target;
      _wallpaperIndicatorTo = target;
      return;
    }
    final from = _wallpaperIndicatorFrom ?? target;
    final to = _wallpaperIndicatorTo ?? target;
    final current = Offset.lerp(from, to, _wallpaperIndicator.value) ?? target;
    final velocity = _wallpaperIndicator.isAnimating
        ? _wallpaperIndicator.velocity
        : 0.0;
    _wallpaperIndicatorFrom = current;
    _wallpaperIndicatorTo = target;
    _wallpaperIndicator.value = 0;
    _wallpaperIndicator.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 32),
        0,
        1,
        velocity,
      ),
    );
  }

  Future<void> _initialize() async {
    final customCliPath = await widget.gateway.loadCustomCliPath() ?? '';
    if (!mounted) return;
    controller.text = customCliPath;
    final values = await Future.wait([
      widget.gateway.loadHubOrigin(),
      widget.gateway.loadRiskPolicy(),
      widget.gateway.loadReminderSettings(),
    ]);
    if (!mounted) return;
    hubController.text = values[0] as String;
    riskPolicy = values[1] as PersonalRiskPolicy;
    reminderSettings = values[2] as ReminderSettings;
    await detect();
    if (!mounted) return;
    setState(() => loadingSettings = false);
  }

  Future<void> detect({bool refreshCatalog = false}) async {
    if (!mounted) return;
    setState(() => detecting = true);
    final detected = await widget.gateway.detectCli(
      customPath: controller.text,
    );
    if (detected.isReady) {
      try {
        final controller = ref.read(agentCatalogProvider.notifier);
        if (refreshCatalog) {
          await controller.refresh();
        } else {
          await controller.ensureLoaded();
        }
      } on Object {
        // Shared state preserves the last valid catalog and exposes the error.
      }
    }
    if (!mounted) return;
    setState(() {
      status = detected;
      detecting = false;
    });
  }

  Future<void> save() async {
    await widget.gateway.saveCustomCliPath(controller.text);
    await detect(refreshCatalog: true);
  }

  Future<void> clear() async {
    controller.clear();
    await widget.gateway.saveCustomCliPath(null);
    await detect(refreshCatalog: true);
  }

  Future<HubStatus?> testHub() async {
    if (!mounted) return null;
    final origin = hubController.text;
    setState(() {
      testingHub = true;
      notice = null;
    });
    HubStatus tested;
    try {
      tested = await widget.gateway.testHubOrigin(origin);
    } on Object catch (error) {
      tested = HubStatus(
        origin: origin,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
        diagnostic: error.toString(),
      );
    } finally {
      if (mounted) setState(() => testingHub = false);
    }
    if (!mounted) return null;
    setState(() => hubStatus = tested);
    return tested;
  }

  Future<void> saveHub() async {
    try {
      final tested = await testHub();
      if (!mounted || tested?.isReady != true) return;
      await widget.gateway.saveHubOrigin(hubController.text);
      final savedOrigin = await widget.gateway.loadHubOrigin();
      if (!mounted) return;
      hubController.text = savedOrigin;
      setState(() => notice = context.l10n.hubOriginSaved);
    } on FormatException catch (error) {
      if (mounted) {
        setState(
          () => hubStatus = HubStatus(
            origin: hubController.text,
            state: HealthState.invalid,
            issue: HubIssue.invalidOrigin,
            diagnostic: error.message,
          ),
        );
      }
    }
  }

  Future<void> resetHub() async {
    await widget.gateway.resetHubOrigin();
    if (!mounted) return;
    final defaultOrigin = await widget.gateway.loadHubOrigin();
    if (!mounted) return;
    hubController.text = defaultOrigin;
    await testHub();
  }

  Future<void> setCriticalOverride(bool value) async {
    final policy = PersonalRiskPolicy(allowCriticalOverride: value);
    await widget.gateway.saveRiskPolicy(policy);
    if (mounted) {
      setState(() {
        riskPolicy = policy;
        notice = context.l10n.policySaved;
      });
    }
  }

  Future<void> _setUpdateReminder(bool value) async {
    final updated = reminderSettings.copyWith(updateAvailable: value);
    await widget.gateway.saveReminderSettings(updated);
    if (mounted) setState(() => reminderSettings = updated);
  }

  Future<void> _setSecurityReminder(bool value) async {
    final updated = reminderSettings.copyWith(securityAdvisory: value);
    await widget.gateway.saveReminderSettings(updated);
    if (mounted) setState(() => reminderSettings = updated);
  }

  void _selectRoute(_SettingsRoute route) {
    setState(() => selectedRoute = route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    hubController.dispose();
    scrollController.dispose();
    _wallpaperIndicator
      ..removeListener(_rebuildWallpaperIndicator)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SkillsDestinationLayout(
    bodyTransitionKey: selectedRoute,
    rail: SkillsSideRail<_SettingsRoute>(
      semanticLabel: context.l10n.settingsNavigation,
      selected: selectedRoute,
      onSelected: _selectRoute,
      items: [
        SkillsRailItem(
          value: _SettingsRoute.general,
          label: context.l10n.general,
          icon: HugeIcons.strokeRoundedCustomize,
        ),
        SkillsRailItem(
          value: _SettingsRoute.reminders,
          label: context.l10n.remindersSettings,
          icon: HugeIcons.strokeRoundedNotification02,
        ),
        SkillsRailItem(
          value: _SettingsRoute.agents,
          label: context.l10n.agents,
          icon: HugeIcons.strokeRoundedRobot01,
        ),
        SkillsRailItem(
          value: _SettingsRoute.advanced,
          label: context.l10n.advancedSettings,
          icon: HugeIcons.strokeRoundedSettings02,
        ),
      ],
    ),
    child: loadingSettings
        ? const Center(child: CircularProgressIndicator())
        : _settingsPage(),
  );

  Widget _settingsPage() => ListView(
    controller: scrollController,
    padding: const EdgeInsets.only(top: 12),
    children: [
      if (notice != null) ...[
        Text(
          notice!,
          style: TextStyle(color: context.skillsComponents.statusSuccess),
        ),
        const SizedBox(height: 12),
      ],
      switch (selectedRoute) {
        _SettingsRoute.general => _generalSettings(),
        _SettingsRoute.reminders => _reminderSettings(),
        _SettingsRoute.agents => _agentSettings(),
        _SettingsRoute.advanced => _advancedSettings(),
      },
    ],
  );

  Widget _reminderSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SkillsSwitch(
        key: const Key('update-reminder'),
        value: reminderSettings.updateAvailable,
        onChanged: _setUpdateReminder,
        label: _inlineReminderLabel(
          key: const Key('update-reminder-label'),
          title: context.l10n.updateReminderTitle,
          description: context.l10n.updateReminderDescription,
        ),
      ),
      const SizedBox(height: 18),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 18),
      SkillsSwitch(
        key: const Key('security-reminder'),
        value: reminderSettings.securityAdvisory,
        onChanged: _setSecurityReminder,
        label: _inlineReminderLabel(
          key: const Key('security-reminder-label'),
          title: context.l10n.securityReminderTitle,
          description: context.l10n.securityReminderDescription,
        ),
      ),
    ],
  );

  Widget _inlineReminderLabel({
    required Key key,
    required String title,
    required String description,
  }) => Text.rich(
    key: key,
    TextSpan(
      children: [
        TextSpan(
          text: title,
          style: context.skillsTypography.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: '  $description',
          style: context.skillsTypography.bodySecondary,
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  Widget _settingsHeading(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    ],
  );

  Widget _advancedSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _hubSettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _policySettings(),
      const SizedBox(height: 28),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 24),
      _onboardingSettings(),
    ],
  );

  Widget _onboardingSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _settingsHeading(
        context.l10n.restartOnboardingTitle,
        context.l10n.restartOnboardingDescription,
      ),
      const SizedBox(height: 18),
      SkillsButton.outline(
        key: const Key('restart-onboarding'),
        enabled: !restartingOnboarding,
        onPressed: () => unawaited(_restartOnboarding()),
        child: Text(
          restartingOnboarding
              ? context.l10n.loading
              : context.l10n.restartOnboardingAction,
        ),
      ),
    ],
  );

  Future<void> _restartOnboarding() async {
    setState(() => restartingOnboarding = true);
    try {
      await widget.onRestartOnboarding();
    } on Object {
      if (!mounted) return;
      setState(() {
        restartingOnboarding = false;
        notice = context.l10n.restartOnboardingFailed;
      });
    }
  }

  Widget _generalSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.language,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _LanguageSingleSelect(
        key: const Key('language-picker'),
        selected: widget.language,
        onChanged: widget.onLanguageChanged,
      ),
      const SizedBox(height: 24),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 20),
      Text(
        context.l10n.personalizationTheme,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 18),
      _themeControls(),
      const SizedBox(height: 24),
      SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      const SizedBox(height: 20),
      Text(
        context.l10n.wallpaper,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _wallpaperPicker(),
    ],
  );

  Widget _themeControls() => LayoutBuilder(
    builder: (context, constraints) {
      final mode = _personalizationField(
        context.l10n.appearanceMode,
        _themeModeTabs(),
      );
      final color = _personalizationField(
        context.l10n.folderColorTheme,
        KeyedSubtree(
          key: const Key('folder-theme-picker'),
          child: BloomColorPicker(
            initialColor: _AppShellState._folderThemeColor(widget.folderTheme),
            onColorChanged: widget.onFolderThemeChanged,
            presets: localizedBrandThemePresets(context.l10n),
            style: BloomColorPickerStyle(
              alignment: BloomColorPickerAlignment.circleLeft,
              closedRadius: 18,
              closedBorderWidth: 2,
              hapticFeedback: false,
              iconStrokeWidth: 1.5,
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: .3,
              ),
              pillBackgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              pillTextColor: Theme.of(context).colorScheme.onSurface,
              iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [mode, const SizedBox(height: 18), color],
        );
      }
      return SizedBox(
        height: 80,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 210, child: mode),
            VerticalDivider(
              width: 48,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: color),
          ],
        ),
      );
    },
  );

  Widget _personalizationField(String label, Widget control) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _personalizationFieldLabel(label),
      const SizedBox(height: 12),
      SizedBox(
        height: 48,
        child: Align(alignment: Alignment.centerLeft, child: control),
      ),
    ],
  );

  Widget _personalizationFieldLabel(String label) => Text(
    label,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _wallpaperPicker() {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = (constraints.maxWidth / 150).floor().clamp(2, 8);
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final tileHeight = tileWidth / 1.62;
        final rows = (AppWallpaper.values.length / columns).ceil();
        final gridHeight = tileHeight * rows + spacing * (rows - 1);
        if (_wallpaperColumns != columns) {
          _wallpaperIndicator.stop();
          _wallpaperColumns = columns;
          final target = _wallpaperCoordinate(widget.wallpaper, columns);
          _wallpaperIndicatorFrom = target;
          _wallpaperIndicatorTo = target;
        }
        final from = _wallpaperIndicatorFrom!;
        final to = _wallpaperIndicatorTo!;
        final coordinate = Offset.lerp(from, to, _wallpaperIndicator.value)!;
        return SizedBox(
          key: const Key('wallpaper-picker'),
          height: gridHeight,
          child: Stack(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppWallpaper.values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1.62,
                ),
                itemBuilder: (context, index) {
                  final wallpaper = AppWallpaper.values[index];
                  final selected = wallpaper == widget.wallpaper;
                  return Semantics(
                    selected: selected,
                    button: true,
                    label: _wallpaperLabel(wallpaper),
                    child: InkWell(
                      key: ValueKey('wallpaper-${wallpaper.name}'),
                      onTap: () => widget.onWallpaperChanged(wallpaper),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                wallpaper.assetPath,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                left: 6,
                                child: Text(
                                  _wallpaperLabel(wallpaper),
                                  maxLines: 1,
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.skillsTypography.caption
                                      .copyWith(color: Color(0xFFFFFFFF)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                key: const Key('wallpaper-selection-indicator'),
                left: coordinate.dx * (tileWidth + spacing),
                top: coordinate.dy * (tileHeight + spacing),
                width: tileWidth,
                height: tileHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _wallpaperLabel(AppWallpaper wallpaper) => switch (wallpaper) {
    AppWallpaper.sun => context.l10n.wallpaperSun,
    AppWallpaper.mercury => context.l10n.wallpaperMercury,
    AppWallpaper.venus => context.l10n.wallpaperVenus,
    AppWallpaper.earth => context.l10n.wallpaperEarth,
    AppWallpaper.mars => context.l10n.wallpaperMars,
    AppWallpaper.jupiter => context.l10n.wallpaperJupiter,
    AppWallpaper.saturn => context.l10n.wallpaperSaturn,
    AppWallpaper.uranus => context.l10n.wallpaperUranus,
    AppWallpaper.neptune => context.l10n.wallpaperNeptune,
    AppWallpaper.pluto => context.l10n.wallpaperPluto,
    AppWallpaper.moon => context.l10n.wallpaperMoon,
  };

  Widget _themeModeTabs() {
    final scheme = Theme.of(context).colorScheme;
    return DiscreteTabs(
      key: const Key('appearance-mode-tabs'),
      currentIndex: widget.themeMode.index,
      onSelect: (index) =>
          widget.onThemeModeChanged(AppThemeMode.values[index]),
      tabs: [
        DiscreteTab(
          label: context.l10n.followSystem,
          icon: HugeIcons.strokeRoundedComputer,
          activeColor: scheme.onPrimaryContainer,
        ),
        DiscreteTab(
          label: context.l10n.lightMode,
          icon: HugeIcons.strokeRoundedSun01,
          activeColor: scheme.onPrimaryContainer,
        ),
        DiscreteTab(
          label: context.l10n.darkMode,
          icon: HugeIcons.strokeRoundedMoon02,
          activeColor: scheme.onPrimaryContainer,
        ),
      ],
      style: DiscreteTabsStyle(
        height: 36,
        horizontalPadding: 8,
        iconStrokeWidth: 1.5,
        selectedLabelWeight: FontWeight.w500,
        selectedScale: 1,
        backgroundColor: scheme.surfaceContainerHigh,
        activeBackgroundColor: scheme.primaryContainer,
        inactiveIconColor: scheme.onSurfaceVariant,
        shadowColor: Colors.transparent,
      ),
    );
  }

  Widget _agentSettings() {
    final cliSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.l10n.agentsSettingsTitle)),
            if (detecting)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              StatusChip(
                label: status?.isReady == true
                    ? context.l10n.ready
                    : _cliAvailabilityLabel(context, status?.availability),
                color: status?.isReady == true
                    ? context.skillsComponents.statusSuccess
                    : context.skillsComponents.statusAttention,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          status?.isReady == true
              ? '${status!.path} · v${status!.version}'
              : status == null
              ? context.l10n.detecting
              : _cliStatusMessage(context, status!),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kReleaseMode) ...[
              SkillsInput(
                key: const Key('cli-path'),
                controller: controller,
                placeholder: const Text('/path/to/development/skillsgo'),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!kReleaseMode)
                  SkillsButton(
                    enabled: !detecting,
                    onPressed: save,
                    child: Text(context.l10n.saveAndDetect),
                  ),
                SkillsButton.outline(
                  enabled: !detecting,
                  onPressed: detect,
                  child: Text(context.l10n.detectAgain),
                ),
                if (!kReleaseMode)
                  SkillsButton.outline(
                    enabled: !detecting,
                    onPressed: clear,
                    child: Text(context.l10n.clearCustomPath),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cliSection,
        if (agentInspectionError != null) ...[
          const SizedBox(height: 14),
          Text(
            context.l10n.agentInspectionFailed,
            style: TextStyle(color: context.skillsComponents.statusAttention),
          ),
        ],
        if (agentCatalog != null) ...[
          const SizedBox(height: 14),
          _agentCatalogCard(agentCatalog!),
        ],
      ],
    );
  }

  Widget _agentCatalogCard(AgentCatalog catalog) {
    final installed = catalog.agents.where((agent) => agent.installed).toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
    final notInstalled =
        catalog.agents.where((agent) => !agent.installed).toList()..sort(
          (left, right) => left.displayName.compareTo(right.displayName),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        SkillsSeparator.horizontal(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 22),
        _agentGroup(
          key: const Key('installed-agents-group'),
          title: context.l10n.installedAgentsTitle(installed.length),
          agents: installed,
        ),
        const SizedBox(height: 28),
        SkillsSeparator.horizontal(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 22),
        _agentGroup(
          key: const Key('not-installed-agents-group'),
          title: context.l10n.notInstalledAgentsTitle(notInstalled.length),
          description: context.l10n.notInstalledAgentsDescription,
          agents: notInstalled,
        ),
      ],
    );
  }

  Widget _agentGroup({
    required Key key,
    required String title,
    String? description,
    required List<AgentStatus> agents,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      if (description != null) ...[
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 10),
      for (var index = 0; index < agents.length; index++) ...[
        _AgentStatusRow(status: agents[index]),
        if (index != agents.length - 1)
          SkillsSeparator.horizontal(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    ],
  );

  Widget _hubSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _settingsHeading(
        context.l10n.hubSettingsTitle,
        context.l10n.hubSettingsDescription,
      ),
      const SizedBox(height: 18),
      SkillsInput(
        key: const Key('hub-origin'),
        controller: hubController,
        placeholder: const Text('https://hub.example.com'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SkillsButton(
            enabled: !testingHub,
            onPressed: saveHub,
            child: Text(context.l10n.saveOrigin),
          ),
          SkillsButton.outline(
            enabled: !testingHub,
            onPressed: testHub,
            child: Text(context.l10n.testConnection),
          ),
          SkillsButton.outline(
            enabled: !testingHub,
            onPressed: resetHub,
            child: Text(context.l10n.resetDefault),
          ),
        ],
      ),
      if (hubStatus != null) ...[
        const SizedBox(height: 14),
        Text(
          hubStatus!.isReady
              ? context.l10n.connectionReady
              : '${context.l10n.connectionFailed}: ${_hubStatusMessage(context, hubStatus!)}',
          style: TextStyle(
            color: hubStatus!.isReady
                ? context.skillsComponents.statusSuccess
                : context.skillsComponents.statusAttention,
          ),
        ),
      ],
    ],
  );

  Widget _policySettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _settingsHeading(
        context.l10n.riskPolicyTitle,
        context.l10n.riskPolicyDescription,
      ),
      const SizedBox(height: 18),
      SkillsSwitch(
        value: true,
        enabled: false,
        label: Text(context.l10n.confirmHighRisk),
        sublabel: Text(context.l10n.confirmHighRiskDescription),
      ),
      const SizedBox(height: 14),
      SkillsSwitch(
        key: const Key('critical-risk-override'),
        value: riskPolicy?.allowCriticalOverride ?? false,
        onChanged: setCriticalOverride,
        label: Text(context.l10n.allowCriticalOverride),
        sublabel: Text(context.l10n.allowCriticalOverrideDescription),
      ),
    ],
  );
}

class _LanguageSingleSelect extends StatefulWidget {
  const _LanguageSingleSelect({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  @override
  State<_LanguageSingleSelect> createState() => _LanguageSingleSelectState();
}

class _LanguageSingleSelectState extends State<_LanguageSingleSelect> {
  final controller = MultiSelectController<AppLanguage>();
  bool syncing = false;

  String _label(AppLanguage language) => language == AppLanguage.system
      ? context.l10n.followSystem
      : language.nativeName!;

  List<DropdownItem<AppLanguage>> get items => [
    for (final language in AppLanguage.values)
      DropdownItem(
        label: _label(language),
        value: language,
        selected: language == widget.selected,
      ),
  ];

  @override
  void didUpdateWidget(covariant _LanguageSingleSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.isDisposed) return;
        syncing = true;
        controller.setItems(items);
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    return Semantics(
      label: '${context.l10n.language}: ${_label(widget.selected)}',
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 184,
        height: 36,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MultiDropdown<AppLanguage>(
              controller: controller,
              items: items,
              singleSelect: true,
              fieldDecoration: FieldDecoration(
                hintText: '',
                showClearIcon: false,
                animateSuffixIcon: false,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixIcon: null,
              ),
              dropdownDecoration: DropdownDecoration(
                backgroundColor: colors.surfaceMuted,
                elevation: 5,
                maxHeight: 240,
                marginTop: 6,
                borderRadius: BorderRadius.circular(14),
                listPadding: const EdgeInsets.symmetric(vertical: 6),
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                animationCurve: Curves.easeOutCubic,
              ),
              itemBuilder: (item, index, onTap) => Semantics(
                label: item.label,
                button: true,
                selected: item.selected,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          LanguageIdentityIcon(language: item.value, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item.label)),
                          AnimatedOpacity(
                            opacity: item.selected ? 1 : 0,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedTick01,
                              size: 18,
                              strokeWidth: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              selectedItemBuilder: (_) => const SizedBox.shrink(),
              onSelectionChange: (values) {
                if (syncing || values.isEmpty) return;
                widget.onChanged(values.first);
              },
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderMuted),
                ),
              ),
            ),
            Positioned.fill(
              right: 24,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      LanguageIdentityIcon(language: widget.selected, size: 20),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _label(widget.selected),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 10,
              top: 11.5,
              child: IgnorePointer(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  size: 13,
                  strokeWidth: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentStatusRow extends StatelessWidget {
  const _AgentStatusRow({required this.status});

  final AgentStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AgentLogo(
            agentId: status.id,
            displayName: status.displayName,
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status.discoveryRoots.isNotEmpty) ...[
                const SizedBox(height: 5),
                SelectableText(
                  context.l10n.agentDiscoveryRoots(
                    status.discoveryRoots.join('  '),
                  ),
                  style: context.skillsTypography.caption.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
