/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, HugeIcons, appearance callbacks, gateway settings operations, localization, and shared components.
 * [OUTPUT]: Provides the Settings destination, nested routes, appearance controls, Agent inspection, Hub origin, storage, risk policy, and About views.
 * [POS]: Serves as the complete Settings feature view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

enum _SettingsRoute {
  general,
  agents,
  hub,
  installationPolicy,
  storage,
  colorScheme,
  about,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.gateway,
    required this.folderTheme,
    required this.onFolderThemeChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.wallpaper,
    required this.onWallpaperChanged,
  });
  final SkillsGateway gateway;
  final String folderTheme;
  final ValueChanged<Color> onFolderThemeChanged;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final AppWallpaper wallpaper;
  final ValueChanged<AppWallpaper> onWallpaperChanged;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
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
  StorageStatus? storageStatus;
  String? appVersion;
  bool detecting = true;
  bool loadingSettings = true;
  bool testingHub = false;
  String? notice;
  AgentCatalog? agentCatalog;
  Object? agentInspectionError;

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
      widget.gateway.loadAppVersion(),
    ]);
    if (!mounted) return;
    hubController.text = values[0] as String;
    riskPolicy = values[1] as PersonalRiskPolicy;
    appVersion = values[2] as String;
    await detect();
    if (!mounted) return;
    final inspectedStorage = await widget.gateway.inspectStorage();
    if (!mounted) return;
    setState(() {
      storageStatus = inspectedStorage;
      loadingSettings = false;
    });
  }

  Future<void> detect() async {
    if (!mounted) return;
    setState(() => detecting = true);
    final detected = await widget.gateway.detectCli(
      customPath: controller.text,
    );
    AgentCatalog? inspected;
    Object? inspectionError;
    if (detected.isReady) {
      try {
        inspected = await widget.gateway.inspectAgents();
      } on Object catch (caught) {
        inspectionError = caught;
      }
    }
    if (!mounted) return;
    setState(() {
      status = detected;
      agentCatalog = inspected;
      agentInspectionError = inspectionError;
      detecting = false;
    });
  }

  Future<void> save() async {
    await widget.gateway.saveCustomCliPath(controller.text);
    await detect();
  }

  Future<void> clear() async {
    controller.clear();
    await widget.gateway.saveCustomCliPath(null);
    await detect();
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

  Future<void> refreshStorage() async {
    final inspected = await widget.gateway.inspectStorage();
    if (mounted) setState(() => storageStatus = inspected);
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
          value: _SettingsRoute.agents,
          label: context.l10n.agents,
          icon: HugeIcons.strokeRoundedRobot01,
        ),
        SkillsRailItem(
          value: _SettingsRoute.hub,
          label: context.l10n.hub,
          icon: HugeIcons.strokeRoundedPackageProcess,
        ),
        SkillsRailItem(
          value: _SettingsRoute.installationPolicy,
          label: context.l10n.installationPolicy,
          icon: HugeIcons.strokeRoundedShield01,
        ),
        SkillsRailItem(
          value: _SettingsRoute.storage,
          label: context.l10n.storage,
          icon: HugeIcons.strokeRoundedDatabase02,
        ),
        SkillsRailItem(
          value: _SettingsRoute.colorScheme,
          label: context.l10n.colorScheme,
          icon: HugeIcons.strokeRoundedColorPicker,
        ),
        SkillsRailItem(
          value: _SettingsRoute.about,
          label: context.l10n.about,
          icon: HugeIcons.strokeRoundedInformationCircle,
        ),
      ],
    ),
    child: loadingSettings
        ? const Center(child: CircularProgressIndicator())
        : _settingsPage(),
  );

  Widget _settingsPage() => ListView(
    controller: scrollController,
    children: [
      Text(
        _routeTitle(),
        style: const TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 36,
          fontWeight: FontWeight.w200,
        ),
      ),
      const SizedBox(height: 22),
      if (notice != null) ...[
        Text(
          notice!,
          style: TextStyle(color: context.skillsComponents.statusSuccess),
        ),
        const SizedBox(height: 12),
      ],
      switch (selectedRoute) {
        _SettingsRoute.general => _generalSettings(),
        _SettingsRoute.agents => _agentSettings(),
        _SettingsRoute.hub => _hubSettings(),
        _SettingsRoute.installationPolicy => _policySettings(),
        _SettingsRoute.storage => _storageSettings(),
        _SettingsRoute.colorScheme => ColorSchemeInspector(
          seed: _AppShellState._folderThemeColor(widget.folderTheme),
        ),
        _SettingsRoute.about => _aboutSettings(),
      },
    ],
  );

  String _routeTitle() => switch (selectedRoute) {
    _SettingsRoute.general => context.l10n.general,
    _SettingsRoute.agents => context.l10n.agents,
    _SettingsRoute.hub => context.l10n.hub,
    _SettingsRoute.installationPolicy => context.l10n.installationPolicy,
    _SettingsRoute.storage => context.l10n.storage,
    _SettingsRoute.colorScheme => context.l10n.colorScheme,
    _SettingsRoute.about => context.l10n.about,
  };

  Widget _generalSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.personalizationTheme,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              hapticFeedback: false,
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
      fontWeight: FontWeight.w500,
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
                                  style: const TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w300,
                                  ),
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
                      border: Border.all(color: scheme.primary, width: 2),
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
        backgroundColor: scheme.surfaceContainerHigh,
        activeBackgroundColor: scheme.primaryContainer,
        inactiveIconColor: scheme.onSurfaceVariant,
        shadowColor: Colors.transparent,
      ),
    );
  }

  Widget _agentSettings() {
    final cliCard = SkillsCard(
      width: double.infinity,
      title: Row(
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
      description: Text(
        status?.isReady == true
            ? '${status!.path} · v${status!.version}'
            : status == null
            ? context.l10n.detecting
            : _cliStatusMessage(context, status!),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
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
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cliCard,
        if (agentInspectionError != null) ...[
          const SizedBox(height: 14),
          SkillsCard(
            width: double.infinity,
            description: Text(context.l10n.agentInspectionFailed),
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
    final agents = [...catalog.agents]
      ..sort((left, right) {
        if (left.installed != right.installed) return left.installed ? -1 : 1;
        return left.displayName.compareTo(right.displayName);
      });
    return SkillsCard(
      width: double.infinity,
      title: Text(
        context.l10n.agentCatalogSummary(
          catalog.installed.length,
          catalog.agents.length,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (var index = 0; index < agents.length; index++) ...[
              _AgentStatusRow(status: agents[index]),
              if (index != agents.length - 1)
                SkillsSeparator.horizontal(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hubSettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.hubSettingsTitle),
    description: Text(context.l10n.hubSettingsDescription),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
      ),
    ),
  );

  Widget _policySettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.riskPolicyTitle),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
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
      ),
    ),
  );

  Widget _storageSettings() {
    final storage = storageStatus!;
    final label = switch (storage.state) {
      HealthState.ready => context.l10n.storageHealthy,
      HealthState.notInitialized => context.l10n.storageNotInitialized,
      _ => context.l10n.storageUnavailable,
    };
    return SkillsCard(
      width: double.infinity,
      title: Text(context.l10n.storageSettingsTitle),
      description: Text(
        storage.path.isEmpty
            ? context.l10n.storagePathUnavailable
            : storage.path,
      ),
      footer: SkillsButton.outline(
        onPressed: refreshStorage,
        child: Text(context.l10n.refresh),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            StatusChip(
              label: label,
              color: storage.state == HealthState.ready
                  ? context.skillsComponents.statusSuccess
                  : context.skillsComponents.statusAttention,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_storageStatusMessage(context, storage))),
          ],
        ),
      ),
    );
  }

  Widget _aboutSettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.aboutSettingsTitle),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          _versionRow(context.l10n.appVersion, appVersion ?? '—'),
          const SizedBox(height: 12),
          _versionRow(context.l10n.cliVersion, status?.version ?? '—'),
          const SizedBox(height: 12),
          StatusChip(
            label: status == null
                ? context.l10n.detecting
                : status!.isReady
                ? context.l10n.compatible
                : _cliAvailabilityLabel(context, status!.availability),
            color: status?.isReady == true
                ? context.skillsComponents.statusSuccess
                : context.skillsComponents.statusAttention,
          ),
          if (status != null && !status!.isReady) ...[
            const SizedBox(height: 12),
            Text(
              _cliStatusMessage(context, status!),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _versionRow(String label, String version) => Row(
    children: [
      Expanded(child: Text(label)),
      SelectableText(
        version,
        style: const TextStyle(fontFamily: SkillsTokens.monoFamily),
      ),
    ],
  );
}

class _AgentStatusRow extends StatelessWidget {
  const _AgentStatusRow({required this.status});

  final AgentStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            StatusChip(
              label: status.installed
                  ? context.l10n.agentInstalled
                  : context.l10n.agentSupported,
              color: status.installed
                  ? context.skillsComponents.statusSuccess
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: status.supportedScopes
              .map(
                (scope) => StatusChip(
                  label: switch (scope) {
                    InstallationScope.user => context.l10n.userScope,
                    InstallationScope.project => context.l10n.projectScope,
                  },
                  color: context.skillsComponents.statusAccent,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        Text(
          status.installed
              ? context.l10n.agentDetectedDescription
              : context.l10n.agentSupportedDescription,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (status.userTarget != null) ...[
          const SizedBox(height: 5),
          SelectableText(
            context.l10n.agentUserTarget(status.userTarget!.path),
            style: TextStyle(
              fontFamily: SkillsTokens.monoFamily,
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
            ),
          ),
        ],
      ],
    ),
  );
}
