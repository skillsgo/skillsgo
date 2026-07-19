/*
 * [INPUT]: Depends on Riverpod, typed appearance settings from SkillsGateway, and the App-scoped Gateway provider.
 * [OUTPUT]: Provides immutable appearance state plus optimistic theme, mode, language, and wallpaper persistence actions.
 * [POS]: Serves as the application appearance business-state boundary shared by the shell and Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

class AppearanceState {
  const AppearanceState({
    this.folderTheme = '#FFFFFF',
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.system,
    this.wallpaper = AppWallpaper.sun,
  });

  final String folderTheme;
  final AppThemeMode themeMode;
  final AppLanguage language;
  final AppWallpaper wallpaper;

  AppearanceState copyWith({
    String? folderTheme,
    AppThemeMode? themeMode,
    AppLanguage? language,
    AppWallpaper? wallpaper,
  }) => AppearanceState(
    folderTheme: folderTheme ?? this.folderTheme,
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    wallpaper: wallpaper ?? this.wallpaper,
  );
}

final appearanceProvider =
    AsyncNotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

class AppearanceController extends AsyncNotifier<AppearanceState> {
  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  Future<AppearanceState> build() async {
    final values = await Future.wait<Object>([
      _gateway.loadFolderTheme(),
      _gateway.loadThemeMode(),
      _gateway.loadWallpaper(),
      _gateway.loadLanguage(),
    ]);
    return AppearanceState(
      folderTheme: values[0] as String,
      themeMode: values[1] as AppThemeMode,
      wallpaper: values[2] as AppWallpaper,
      language: values[3] as AppLanguage,
    );
  }

  AppearanceState get _current => state.value ?? const AppearanceState();

  Future<void> setFolderTheme(String value) async {
    state = AsyncData(_current.copyWith(folderTheme: value));
    await _gateway.saveFolderTheme(value);
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    state = AsyncData(_current.copyWith(themeMode: value));
    await _gateway.saveThemeMode(value);
  }

  Future<void> setLanguage(AppLanguage value) async {
    state = AsyncData(_current.copyWith(language: value));
    await _gateway.saveLanguage(value);
  }

  Future<void> setWallpaper(AppWallpaper value) async {
    state = AsyncData(_current.copyWith(wallpaper: value));
    await _gateway.saveWallpaper(value);
  }
}
