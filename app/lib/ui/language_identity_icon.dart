/*
 * [INPUT]: Depends on AppLanguage, Flutter SVG asset rendering, HugeIcons, and locally vendored Circle Flags assets.
 * [OUTPUT]: Provides the shared language identity icon used by language selection controls.
 * [POS]: Centralizes presentation-language-to-visual mapping so adding a supported language has one discoverable asset seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/presentation_language.dart';

/// Flag assets come from HatScripts Circle Flags (MIT):
/// https://github.com/HatScripts/circle-flags
///
/// To add another flag, download its ISO 3166-1 alpha-2 SVG from:
/// https://raw.githubusercontent.com/HatScripts/circle-flags/gh-pages/flags/{code}.svg
/// into `assets/language-flags/`, then add its AppLanguage mapping below.
String? languageFlagAsset(AppLanguage language) => switch (language) {
  AppLanguage.system => null,
  AppLanguage.english => 'assets/language-flags/gb.svg',
  AppLanguage.simplifiedChinese => 'assets/language-flags/cn.svg',
};

class LanguageIdentityIcon extends StatelessWidget {
  const LanguageIdentityIcon({
    super.key,
    required this.language,
    this.size = 20,
  });

  final AppLanguage language;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = languageFlagAsset(language);
    if (asset == null) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedComputer,
        size: size,
        strokeWidth: 1.8,
      );
    }
    return ClipOval(
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: size,
        child: Transform.scale(
          scale: 1.03,
          filterQuality: FilterQuality.high,
          child: SvgPicture.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
