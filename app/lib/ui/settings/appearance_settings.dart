/*
 * [INPUT]: Depends on SettingsScreen appearance state, theme presets, Bloom picker, wallpaper assets, language identity, and discrete tabs.
 * [OUTPUT]: Provides General settings, appearance controls, personalization fields, wallpaper selection, and theme-mode controls.
 * [POS]: Serves as the appearance and Presentation Locale segment of the Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

extension _AppearanceSettings on _SettingsScreenState {
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
            initialColor: folderThemeColor(widget.folderTheme),
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
}
