/*
 * [INPUT]: Depends on Flutter, shadcn_ui, SkillsGateway, localization delegates, the App shell, and brand tokens.
 * [OUTPUT]: Provides SkillsGoApp, the localized desktop application root.
 * [POS]: Serves as the App composition boundary between platform startup and product UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'domain/skills_gateway.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_shell.dart';
import 'ui/brand.dart';

class SkillsGoApp extends StatelessWidget {
  const SkillsGoApp({super.key, required this.gateway});

  final SkillsGateway gateway;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillsGo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: ThemeMode.dark,
      theme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
        textTheme: ShadTextTheme(family: SkillsTokens.sansFamily),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
        textTheme: ShadTextTheme(family: SkillsTokens.sansFamily),
      ),
      home: AppShell(gateway: gateway),
    );
  }
}
