/*
 * [INPUT]: Depends on the app_shell library for gateway contracts, HugeIcons, Riverpod installation operations, localized UI components, and shared navigation callbacks.
 * [OUTPUT]: Provides remote Skill detail plus direct confirmed Installation, Update, managed member removal, risk, progress, result, and retry flows without a second target matrix.
 * [POS]: Serves as the complete mutation-flow view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'agent_logo.dart';
import 'bidirectional_content.dart';
import 'brand.dart';
import 'install_location_popover.dart';
import 'install_operation_controller.dart';
import 'library_controller.dart';
import 'native_components.dart';
import 'project_identity_icon.dart';
import 'skill_markdown_view.dart';
import 'target_management_controller.dart';
import 'ui_support.dart';
import 'update_operation_controller.dart';

part 'installation/detail_primitives.dart';
part 'installation/installation_scope_panel.dart';
part 'installation/installation_target_detail.dart';
part 'installation/remote_detail_core.dart';
part 'installation/remote_detail_rendering.dart';
part 'installation/target_management_dialog.dart';
part 'installation/update_plan_dialog.dart';
