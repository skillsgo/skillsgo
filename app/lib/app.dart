/*
 * [INPUT]: Depends on Flutter Material, SkillsGateway, localization delegates, the App shell, and brand tokens.
 * [OUTPUT]: Provides SkillsGoApp, the localized desktop application root.
 * [POS]: Serves as the App composition boundary between platform startup and product UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import 'domain/skills_gateway.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_shell.dart';
import 'ui/brand.dart';

class SkillsGoApp extends StatelessWidget {
  const SkillsGoApp({super.key, required this.gateway});

  final SkillsGateway gateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillsGo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: ThemeMode.system,
      theme: buildSkillsTheme(
        const Color(0xFF514532),
        brightness: Brightness.light,
      ),
      darkTheme: buildSkillsTheme(const Color(0xFF514532)),
      home: AppShell(gateway: gateway),
    );
  }
}
