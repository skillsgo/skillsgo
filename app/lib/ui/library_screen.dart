/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives and top-level navigation, collection natural ordering, HugeIcons, multi_dropdown, ShimmerText, URL launching, shared destination and semantic primitives, ProjectIdentityIcon, Riverpod Library/update state, gateway mutations, localization, and shared operation dialogs.
 * [OUTPUT]: Provides the unified local-first Library destination with Global/Project navigation, composable query filters, one stable inventory header, Package grouping and usage ranking, All Skills / Needs Attention governance, reviewed Other Installation adoption, Package updates, multi-Agent context, bulk removal, and installed-detail management.
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
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:multi_dropdown/multi_dropdown.dart';
import 'package:path/path.dart' as p;
import 'package:portal_labs/portal_labs.dart' as portal;
import 'package:url_launcher/url_launcher.dart';

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'agent_logo.dart';
import 'bidirectional_content.dart';
import 'brand.dart';
import 'discrete_tabs/shimmer_text.dart';
import 'install_location_popover.dart';
import 'install_operation_controller.dart';
import 'installation_flows.dart';
import 'library_controller.dart';
import 'native_components.dart';
import 'nested_navigation.dart';
import 'project_identity_icon.dart';
import 'skill_markdown_view.dart';
import 'ui_support.dart';
import 'update_check_controller.dart';

part 'library/library_screen_core.dart';
part 'library/library_actions.dart';
part 'library/batch_adoption_presentation.dart';
part 'library/adoption_review.dart';
part 'library/portal_split_button.dart';
part 'library/library_body.dart';
part 'library/installed_skill_groups.dart';
part 'library/installed_skill_rows.dart';
part 'library/library_selection.dart';
part 'library/library_composable_filters.dart';
part 'library/library_governance.dart';
part 'library/library_filters.dart';
part 'library/local_detail_core.dart';
part 'library/local_detail_rendering.dart';
