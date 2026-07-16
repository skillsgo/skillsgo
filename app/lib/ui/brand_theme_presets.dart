/*
 * [INPUT]: Depends on Flutter Material colors and the vendored Bloom preset contract.
 * [OUTPUT]: Provides the curated, source-traceable Simple Icons brand theme presets used by SkillsGo.
 * [POS]: Serves as the static theme-preset catalog in the App UI module, separate from picker rendering and Settings state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import 'bloom_color_picker/bloom_color_picker.dart';

const simpleIconsRevision = '0f9fa549da00e9aa6e3ef8d3d2171f481360e638';

@immutable
class BrandThemePreset extends BloomColorPreset {
  const BrandThemePreset({
    required this.id,
    required super.name,
    required super.color,
    required this.source,
  });

  final String id;
  final String source;
}

/// Fixed in color-wheel order so upgrades do not disturb spatial memory.
///
/// Every color is the unmodified HEX value shown by Simple Icons at
/// [simpleIconsRevision]. The catalog favors perceptual variety and useful
/// desktop themes over collecting several famous brands with similar colors.
const brandThemePresets = <BrandThemePreset>[
  BrandThemePreset(
    id: 'github',
    name: 'GitHub',
    color: Color(0xFF181717),
    source: 'https://github.com/logos',
  ),
  BrandThemePreset(
    id: 'levels-fyi',
    name: 'levels.fyi',
    color: Color(0xFF788B95),
    source: 'https://www.levels.fyi/press/',
  ),
  BrandThemePreset(
    id: 'composer',
    name: 'Composer',
    color: Color(0xFF885630),
    source: 'https://getcomposer.org',
  ),
  BrandThemePreset(
    id: 'netease-cloud-music',
    name: 'NetEase Cloud Music',
    color: Color(0xFFD43C33),
    source: 'https://y.music.163.com/m',
  ),
  BrandThemePreset(
    id: 'raspberry-pi',
    name: 'Raspberry Pi',
    color: Color(0xFFA22846),
    source: 'https://www.raspberrypi.org/trademark-rules',
  ),
  BrandThemePreset(
    id: 'dribbble',
    name: 'Dribbble',
    color: Color(0xFFEA4C89),
    source: 'https://dribbble.com/branding',
  ),
  BrandThemePreset(
    id: 'china-eastern-airlines',
    name: 'China Eastern Airlines',
    color: Color(0xFF1A2477),
    source:
        'https://uk.ceair.com/newCMS/uk/en/content/en_Footer/Support/201904/t20190404_5763.html',
  ),
  BrandThemePreset(
    id: 'twitch',
    name: 'Twitch',
    color: Color(0xFF9146FF),
    source: 'https://brand.twitch.tv',
  ),
  BrandThemePreset(
    id: 'discord',
    name: 'Discord',
    color: Color(0xFF5865F2),
    source: 'https://discord.com/branding',
  ),
  BrandThemePreset(
    id: 'tailwind-css',
    name: 'Tailwind CSS',
    color: Color(0xFF06B6D4),
    source: 'https://tailwindcss.com/brand',
  ),
  BrandThemePreset(
    id: 'supabase',
    name: 'Supabase',
    color: Color(0xFF3FCF8E),
    source:
        'https://github.com/supabase/supabase/blob/4031a7549f5d46da7bc79c01d56be4177dc7c114/packages/common/assets/images/supabase-logo-wordmark--light.svg',
  ),
  BrandThemePreset(
    id: 'oppo',
    name: 'OPPO',
    color: Color(0xFF2D683D),
    source:
        'https://www.figma.com/community/file/832815970641696814/OPPO-Media-Kit',
  ),
  BrandThemePreset(
    id: 'nvidia',
    name: 'NVIDIA',
    color: Color(0xFF76B900),
    source: 'https://www.nvidia.com/en-us',
  ),
  BrandThemePreset(
    id: 'taobao',
    name: 'Taobao',
    color: Color(0xFFE94F20),
    source: 'https://www.alibabagroup.com/en/ir/reports',
  ),
  BrandThemePreset(
    id: 'bitcoin',
    name: 'Bitcoin',
    color: Color(0xFFF7931A),
    source: 'https://bitcoin.org',
  ),
  BrandThemePreset(
    id: 'gitlab',
    name: 'GitLab',
    color: Color(0xFFFC6D26),
    source: 'https://about.gitlab.com/press/press-kit/',
  ),
  BrandThemePreset(
    id: 'claude',
    name: 'Claude',
    color: Color(0xFFD97757),
    source: 'https://claude.ai',
  ),
  BrandThemePreset(
    id: 'figma',
    name: 'Figma',
    color: Color(0xFFF24E1E),
    source: 'https://www.figma.com/using-the-figma-brand/',
  ),
];
