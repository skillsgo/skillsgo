/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, HugeIcons, appearance callbacks, gateway settings operations, the App-scoped Library controller, localization, shared components, and secondary-body entrance motion.
 * [OUTPUT]: Provides a focused, flat Settings destination with short depth entrances between secondary routes, personalization, reminder preferences, Agent detection and recovery, plus infrequent Hub, risk, Onboarding re-entry, and local Library refresh controls.
 * [POS]: Serves as the user-facing Settings feature, keeping diagnostics conditional and developer inspection out of ordinary navigation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'agent_logo.dart';
import 'bloom_color_picker/bloom_color_picker.dart';
import 'brand.dart';
import 'brand_theme_presets.dart';
import 'discrete_tabs/discrete_tabs.dart';
import 'language_identity_icon.dart';
import 'library_controller.dart';
import 'native_components.dart';
import 'nested_navigation.dart';
import 'ui_support.dart';

part 'settings/settings_screen_core.dart';
part 'settings/settings_sections.dart';
part 'settings/appearance_settings.dart';
part 'settings/integration_settings.dart';
part 'settings/language_selector.dart';
part 'settings/agent_status_row.dart';
