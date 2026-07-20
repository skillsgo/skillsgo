/*
 * [INPUT]: Depends on SkillsGateway Agent and asynchronously enriched Added Project models, localized copy, Flutter Material MenuAnchor, SkillsGo semantic typography, Portal Labs stacked toasts, shared project identities, and vendored Agent SVGs.
 * [OUTPUT]: Provides an edge-aware anchored installation menu that opens immediately, resolves its data and newly batch-added project icons without blocking interaction, asks where a Skill or Repository should be available, executes the initiating surface's preferred install scope, and publishes App-top stacked success or error feedback.
 * [POS]: Serves as the shared first step of installation from discovery cards and remote Skill detail.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'design_system/skills_component_tokens.dart';
import 'design_system/skills_typography.dart';
import 'install_location_island/install_location_island.dart';
import 'native_components.dart';
import 'project_identity_icon.dart';
import 'stacked_toast.dart';

part 'install_location/menu_contracts.dart';
part 'install_location/menu_anchor.dart';
part 'install_location/async_location_card.dart';
part 'install_location/location_card.dart';
part 'install_location/scope_selector.dart';
