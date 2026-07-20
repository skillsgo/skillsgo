/*
 * [INPUT]: Depends on Flutter Material primitives plus SkillsGo semantic component and typography tokens.
 * [OUTPUT]: Provides reusable native desktop buttons including the primary capsule action, cards, dialogs, fields, alerts, skeleton placeholders, progress, toggles, dividers, and tooltips.
 * [POS]: Serves as the Material-only component layer between product screens and Flutter widgets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import 'design_system/skills_component_tokens.dart';
import 'design_system/skills_typography.dart';

part 'native/buttons_and_loading.dart';
part 'native/cards_and_selection.dart';
part 'native/feedback_and_inputs.dart';
