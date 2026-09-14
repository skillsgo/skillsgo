/*
 * [INPUT]: Depends on the current SkillsGo seed, HugeIcons, the SkillsGo semantic token module, Material 3 mapping, localization, and clipboard services.
 * [OUTPUT]: Renders a read-only Light/Dark inspector for SkillsGo product tokens, every non-deprecated Material 3 mapped role, semantic pairs, and component previews.
 * [POS]: Serves as the Settings developer surface for validating the design-system interface and its Flutter adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import 'brand.dart';

part 'color_inspector/inspector_screen.dart';
part 'color_inspector/token_grid.dart';
part 'color_inspector/color_role_card.dart';
part 'color_inspector/component_preview.dart';
part 'color_inspector/color_models.dart';
