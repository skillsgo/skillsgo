/*
 * [INPUT]: Depends on the Settings journey library, SkillsGateway, appearance state, Agent and Library controllers, Hub/risk/onboarding operations, and route navigation.
 * [OUTPUT]: Provides the public SettingsScreen plus lifecycle, persistence actions, Library-refresh feedback state, route state, wallpaper animation, and root layout.
 * [POS]: Serves as the state-owning core of the Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

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
  void updateState(VoidCallback change) => setState(change);

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
  bool refreshingLibrary = false;
  bool? libraryRefreshSucceeded;
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
}
