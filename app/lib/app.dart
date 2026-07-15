import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'domain/skills_gateway.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_shell.dart';
import 'ui/brand.dart';

class SkillsPlayApp extends StatelessWidget {
  const SkillsPlayApp({super.key, required this.gateway});

  final SkillsGateway gateway;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillsPlay',
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
