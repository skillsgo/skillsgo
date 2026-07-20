/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives and top-level navigation, collection natural ordering, HugeIcons, multi_dropdown, the shared destination rail, ProjectIdentityIcon, the vendored Archive Folder and collision field, Riverpod Library state, gateway mutations, localization, and shared operation dialogs.
 * [OUTPUT]: Provides the unified Library destination with fixed All and Global navigation, fixed header/footer section dividers, an independently scrollable compact Added Project rail, a pinned multi-directory Add Project action, a concise project-empty path to Discover, location-scoped one-confirmation Batch Takeover with a localized Before/After story, next-frame progress and aggregate results, reminder-aware update and safety summaries, cold/stale loading UI, composable update, multi-Agent filtering, compact target-derived installation scope with hover details, animated Local detail with a sticky compact toolbar, exact External removal, export, and installation-target views.
 * [POS]: Serves as the complete Library feature view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:multi_dropdown/multi_dropdown.dart';
import 'package:path/path.dart' as p;

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'agent_logo.dart';
import 'brand.dart';
import 'install_location_popover.dart';
import 'install_operation_controller.dart';
import 'archive_folder/archive_folder.dart';
import 'archive_folder/archive_folder_style.dart';
import 'archive_folder/archive_item.dart';
import 'installation_flows.dart';
import 'library_controller.dart';
import 'native_components.dart';
import 'nested_navigation.dart';
import 'physics_collision_field.dart';
import 'project_identity_icon.dart';
import 'skill_markdown_view.dart';
import 'subscription_segmented_switch.dart';
import 'ui_support.dart';

part 'library/library_screen_core.dart';
part 'library/library_actions.dart';
part 'library/batch_takeover_presentation.dart';
part 'library/library_body.dart';
part 'library/installed_skill_groups.dart';
part 'library/installed_skill_rows.dart';
part 'library/library_selection.dart';
part 'library/library_filters.dart';
part 'library/local_detail_core.dart';
part 'library/local_detail_rendering.dart';
