/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, Riverpod Discover state, installation flows, localization, and shared components.
 * [OUTPUT]: Provides the Discover destination, route-local desktop pull-to-refresh and automatic pagination behavior, catalog search, Repository source headers, detail transitions, and installation entry points.
 * [POS]: Serves as the Discover feature view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/skills_gateway.dart';
import 'agent_catalog_controller.dart';
import 'brand.dart';
import 'discover_controller.dart';
import 'install_location_popover.dart';
import 'install_operation_controller.dart';
import 'installation_flows.dart';
import 'library_controller.dart';
import 'native_components.dart';
import 'ui_support.dart';

part 'discover/discover_screen_core.dart';
part 'discover/discover_rendering.dart';
part 'discover/repository_source_header.dart';
part 'discover/discover_navigation.dart';
part 'discover/desktop_discover_scroller.dart';
