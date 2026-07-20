/*
 * [INPUT]: Depends on SkillsGateway Mandatory Onboarding contracts, App localization, the SkillsGo branding asset and semantic UI components, AgentLogo, ProjectIdentityIcon, HugeIcons, and Portal Labs PremiumProgressStepper.
 * [OUTPUT]: Provides the blocking two-step first-launch welcome and explicit multi-directory project-addition journey.
 * [POS]: Serves as the clean-install entry surface before the primary App shell initializes its feature controllers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:portal_labs/portal_labs.dart' as portal;

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'brand.dart';
import 'native_components.dart';
import 'project_identity_icon.dart';

part 'onboarding/onboarding_core.dart';
part 'onboarding/welcome_step.dart';
part 'onboarding/projects_step.dart';
part 'onboarding/project_item.dart';
