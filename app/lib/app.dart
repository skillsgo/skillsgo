/*
 * [INPUT]: Depends on Flutter Material, Riverpod, SkillsGateway, localization delegates, the App shell, and brand tokens.
 * [OUTPUT]: Provides SkillsGoApp, the localized desktop application root with the App-scoped Gateway override.
 * [POS]: Serves as the App composition boundary between platform startup and product UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/skills_gateway.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_shell.dart';
import 'ui/app_providers.dart';
import 'ui/brand.dart';

class SkillsGoApp extends StatelessWidget {
  const SkillsGoApp({super.key, required this.gateway});

  final SkillsGateway gateway;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [skillsGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
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
      ),
    );
  }
}
