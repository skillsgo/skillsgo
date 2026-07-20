/*
 * [INPUT]: Depends on SkillsGateway discovery models, localized copy, the SkillsGo design-system interface, Flutter Material rendering, HugeIcons, Loading Animation Widget indicators, Portal Labs Loading Shapes, the bundled solar-starfield background asset, native components, and the shared installation MenuAnchor.
 * [OUTPUT]: Exports SkillsGo theme and semantic color interfaces and provides the full-window photographic background behind Folder, typography/status tokens, context-aware search controls, theme-aware refresh, pagination, and Repository-parsing loading adapters, placeholder-safe Hub-image-backed discovery cards, anchored installation actions, status elements, and viewport-safe empty states with optional supporting copy.
 * [POS]: Serves as the thin branded presentation layer over the SkillsGo design system and native Flutter Material behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:portal_labs/portal_labs.dart' as portal;

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'design_system/skills_color_tokens.dart';
import 'design_system/skills_component_tokens.dart';
import 'design_system/skills_typography.dart';
import 'install_location_popover.dart';
import 'native_components.dart';

export 'design_system/skills_color_tokens.dart';
export 'design_system/skills_component_tokens.dart';
export 'design_system/skills_theme.dart';
export 'design_system/skills_typography.dart';

part 'brand/brand_foundations.dart';
part 'brand/skill_search_field.dart';
part 'brand/skill_cards.dart';
part 'brand/skill_feedback.dart';
